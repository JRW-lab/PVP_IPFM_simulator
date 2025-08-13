function model_fun_v3(save_data,conn,table_name,parameters,paramHash,iter)

% Settings
load_path = "Models/";
training_percentage = 0.7;
cv_spec = 5;
sample_rate = 1000;
max_iterations = 1e8;

% Load data from DB and set new frame count
switch save_data.priority
    case "mysql"
        if save_data.save_mysql
            T = mysql_load(conn,table_name,"*");
        elseif save_data.save_excel
            try
                T = readtable(save_data.excel_path, 'TextType', 'string');
            catch
                T = table;
            end
        end
    case "local"
        if save_data.save_excel
            try
                T = readtable(save_data.excel_path, 'TextType', 'string');
            catch
                T = table;
            end
        elseif save_data.save_mysql
            T = mysql_load(conn,table_name,"*");
        end
end
try
    sim_result = T(string(T.param_hash) == paramHash, :);
catch
    sim_result = [];
end

if size(sim_result,1) < iter
    run_flag = true;
else
    run_flag = false;
end

% Run if new frames are needed
if run_flag

    window_duration = parameters.window_duration;
    frequency_limit = parameters.frequency_limit;
    alpha = parameters.alpha;
    probability_cutoff = parameters.probability_cutoff;
    training_type = parameters.training_type;
    tshift = parameters.tshift;

    % Load dataset
    data = load_dataset(parameters);
    data_master = vertcat(data.signals{:});

    % Set parameters
    if training_type == "patient"
        single_patient_testing = true;
        patients_tested = length(data_master);
    elseif training_type == "percentage"
        single_patient_testing = false;
        patients_tested = 1;
    else
        error("Unsupported testing type.")
    end

    % Category setup
    len_signals = cellfun(@numel, data.signals);
    Yi = zeros(sum(len_signals), 1);
    idx = 1;
    for j = 1:length(len_signals)
        Yi(idx:idx+len_signals(j)-1) = j;
        idx = idx + len_signals(j);
    end
    [~, ~, Yi] = unique(Yi, 'stable');
    classes = unique(Yi);
    Yi = Yi - 1;
    if length(unique(Yi)) > 2
        model_type = "ordinal";
    else
        model_type = "elastic";
    end

    % fprintf("Testing model...\n")
    win_spec = zeros(patients_tested,length(classes));
    win_sens = zeros(patients_tested,length(classes));
    win_accy = zeros(patients_tested,1);
    pat_spec = zeros(patients_tested,length(classes));
    pat_sens = zeros(patients_tested,length(classes));
    pat_accy = zeros(patients_tested,1);
    for patient_sel = 1:patients_tested

        % Generate t-windows for all desired signals and data types
        if single_patient_testing
            % Select data
            waveforms_train = data_master([1:patient_sel-1, patient_sel+1:end]);
            waveforms_test = data_master(patient_sel);
            Yi_train = Yi([1:patient_sel-1, patient_sel+1:end]);
            Yi_test = Yi(patient_sel);

            % Create t-windows
            twindows_train = cellfun(@(x) make_twindows(x,sample_rate,window_duration,tshift*sample_rate),waveforms_train,"UniformOutput",false);
            twindows_test = cellfun(@(x) make_twindows(x,sample_rate,window_duration,tshift*sample_rate),waveforms_test,"UniformOutput",false);

            % Create Yi for training and testing
            Yi_train_vecs = cellfun(@(x,y) ones(size(x,1),1) * y,twindows_train,num2cell(Yi_train),"UniformOutput",false);
            Yi_test_vecs = cellfun(@(x,y) ones(size(x,1),1) * y,twindows_test,num2cell(Yi_test),"UniformOutput",false);
        else
            % Find ranges for training and testing
            trange_train = cellfun(@(x) 1:floor(training_percentage*length(x)), data_master,"UniformOutput",false);
            trange_test = cellfun(@(x) ceil(training_percentage*length(x)):length(x), data_master,"UniformOutput",false);

            % Create t-windows
            twindows_train = cellfun(@(x,y) make_twindows(x(y),sample_rate,window_duration,tshift*sample_rate),data_master,trange_train,"UniformOutput",false);
            twindows_test = cellfun(@(x,y) make_twindows(x(y),sample_rate,window_duration,tshift*sample_rate),data_master,trange_test,"UniformOutput",false);

            % Create Yi for training and testing
            Yi_train_vecs = cellfun(@(x,y) ones(size(x,1),1) * y,twindows_train,num2cell(Yi),"UniformOutput",false);
            Yi_test_vecs = cellfun(@(x,y) ones(size(x,1),1) * y,twindows_test,num2cell(Yi),"UniformOutput",false);
        end

        % Create f-windows
        fwindows_train = cellfun(@(x) fft_rhys(x,sample_rate,frequency_limit,window_duration),twindows_train,'UniformOutput',false);
        fwindows_test = cellfun(@(x) fft_rhys(x,sample_rate,frequency_limit,window_duration),twindows_test,'UniformOutput',false);

        % Create locations for test patient data
        test_lengths = cellfun(@(x) size(x,1),fwindows_test,"UniformOutput",false);
        test_locations = cellfun(@(x,y) y.*ones(x,1),test_lengths,num2cell(1:length(test_lengths)).',"UniformOutput",false);

        % Compress cell arrays into workable data blocks
        test_locations_block = vertcat(test_locations{:});
        fwindows_train_block = vertcat(fwindows_train{:});
        fwindows_test_block = vertcat(fwindows_test{:});
        Yi_train_vec = vertcat(Yi_train_vecs{:});
        Yi_test_vec = vertcat(Yi_test_vecs{:});

        % Serialize to JSON for DB
        parameters_model = rmfield(parameters, 'probability_cutoff');
        if single_patient_testing
            parameters_model.patient_sel = patient_sel;
        end
        paramsJSON_model  = jsonencode_sorted(parameters_model);
        paramHash_model = string(DataHash(paramsJSON_model,'SHA-256'));

        % Load model
        try
            % Try to load file
            models = load((fullfile(load_path, sprintf("model_%s.mat",paramHash_model))));
            beta = models.beta;
            theta = models.theta;

            if size(models.beta,2) < iter
                switch model_type
                    case "elastic"
                        % Find best fit for data using training data
                        [beta_lasso,fit] = lassoglm(fwindows_train_block,Yi_train_vec,'binomial','NumLambda',10,'CV',cv_spec,'Alpha',alpha,'MaxIter',max_iterations);

                        % Add first element of beta
                        beta_0 = fit.Intercept;
                        indx = fit.IndexMinDeviance;
                        beta(:,iter) = [beta_0(indx);beta_lasso(:,indx)];
                        theta(1,iter) = NaN;
                    case "ordinal"
                        % Train model
                        model = fitOrdinalRegression(fwindows_train_block,Yi_train_vec+1,length(unique(Yi)));
                        beta(:,iter) = model.beta;
                        theta(:,iter) = model.theta;
                end

                % Save data file
                save((fullfile(load_path, sprintf("model_%s.mat",paramHash_model))),"beta","theta");
                beta = beta(:,iter);
            else
                beta = models.beta(:,iter);
                theta = theta(:,iter);
            end

        catch
            switch model_type
                case "elastic"
                    % Find best fit for data using training data
                    [beta_lasso,fit] = lassoglm(fwindows_train_block,Yi_train_vec,'binomial','NumLambda',10,'CV',cv_spec,'Alpha',alpha,'MaxIter',max_iterations);

                    % Add first element of beta
                    beta_0 = fit.Intercept;
                    indx = fit.IndexMinDeviance;
                    beta = [beta_0(indx);beta_lasso(:,indx)];
                    theta = NaN;
                case "ordinal"
                    % Train model
                    model = ordinalglm(fwindows_train_block,Yi_train_vec+1,length(unique(Yi)));
                    beta = model.beta;
                    theta = model.theta;
            end

            % Save data file
            save((fullfile(load_path, sprintf("model_%s.mat",paramHash_model))),"beta","theta");
        end

        % Get window-level probabilities
        test_probs = regression_test(model_type,fwindows_test_block,beta,theta);
        switch model_type
            case "elastic"
                Yhat_test_vec = (test_probs > probability_cutoff) * 1;

            case "ordinal"
                [~,Yhat_test_vec] = max(test_probs,[],2);
                Yhat_test_vec = Yhat_test_vec - 1;
        end

        % Get accuracy measurements
        win_conmat = confusionmat(Yi_test_vec,Yhat_test_vec, 'Order', classes-1);
        win_accy(patient_sel) = sum(diag(win_conmat)) ./ sum(win_conmat(:));
        win_sens(patient_sel,:) = diag(win_conmat).' ./ (sum(win_conmat, 2) + eps).';
        for j = 1:length(classes)
            TP = win_conmat(j,j);
            FN = sum(win_conmat(j,:)) - TP;
            FP = sum(win_conmat(:,j)) - TP;
            TN = sum(win_conmat(:)) - TP - FN - FP;
            win_spec(patient_sel,j) = TN / (TN + FP);
        end

        % Get patient-level probabilities
        if single_patient_testing
            % Patient-based testing
            pat_spec(patient_sel,:) = win_spec(patient_sel,:) >= 0.5;
            pat_sens(patient_sel,:) = win_sens(patient_sel,:) >= 0.5;
            pat_accy(patient_sel,:) = win_accy(patient_sel,:) >= 0.5;
        else
            % Percentage-based testing
            Yi_hat = zeros(length(data_master),1);
            for k = 1:length(data_master)
                patient_indices = test_locations_block == k;
                switch model_type
                    case "elastic"
                        patient_yhat = mean(Yhat_test_vec(patient_indices));
                        Yi_hat(k) = patient_yhat > probability_cutoff;
                    case "ordinal"
                        Yi_hat(k) = mode(Yhat_test_vec(patient_indices));
                end
            end

            % Get accuracy measurements
            pat_conmat = confusionmat(Yi,Yi_hat, 'Order', classes-1);
            pat_accy(patient_sel) = sum(diag(pat_conmat)) ./ sum(pat_conmat(:));
            pat_sens(patient_sel,:) = diag(pat_conmat).' ./ (sum(pat_conmat, 2) + eps).';
            for j = 1:length(classes)
                TP = pat_conmat(j,j);
                FN = sum(pat_conmat(j,:)) - TP;
                FP = sum(pat_conmat(:,j)) - TP;
                TN = sum(pat_conmat(:)) - TP - FN - FP;
                pat_spec(patient_sel,j) = TN / (TN + FP);
            end
        end

    end

    % Respecify variables
    metrics_add.win.conmat = win_conmat;
    metrics_add.win.spec = win_spec;
    metrics_add.win.sens = win_sens;
    metrics_add.win.accy = win_accy;
    metrics_add.pat.conmat = pat_conmat;
    metrics_add.pat.spec = pat_spec;
    metrics_add.pat.sens = pat_sens;
    metrics_add.pat.accy = pat_accy;

    % Write to database
    switch save_data.priority
        case "mysql"
            if save_data.save_mysql
                mysql_write(conn,table_name,parameters,0,metrics_add);
            end
            if save_data.save_excel
                T = mysql_load(conn,table_name,"*");
                excel_path = save_data.excel_path;
                writetable(T, excel_path);
            end
        case "local"
            if save_data.save_excel
                excel_path = save_data.excel_path;
                local_write(excel_path,parameters,0,metrics_add);
            end
            if save_data.save_mysql
                mysql_write(conn,table_name,parameters,0,metrics_add);
            end
    end

end
