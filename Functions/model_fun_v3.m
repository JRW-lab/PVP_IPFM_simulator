function model_fun_v3(save_data,conn,table_name,parameters,iter)

% Function setup
[~,paramHash] = jsonencode_sorted(parameters);

% Settings
load_path = "Models/";
signal_type = "PVP";
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

    % Import parameters
    dataset = parameters.dataset;
    signal_sel = parameters.signal_sel;
    group_type = parameters.group_type;
    type_sel = parameters.type_sel;
    group_category = parameters.group_category;
    null_group = parameters.null_group;
    hypo_group = parameters.hypo_group;
    group_value = parameters.group_value;
    null_val = parameters.null_val;
    hypo_val = parameters.hypo_val;
    exclude_patients = parameters.exclude_patients;
    window_duration = parameters.window_duration;
    frequency_limit = parameters.frequency_limit;
    alpha = parameters.alpha;
    probability_cutoff = parameters.probability_cutoff;
    testing_type = parameters.testing_type;
    tshift = parameters.tshift;

    % Load dataset
    data = load_dataset(dataset,group_type,type_sel,group_category,null_group,hypo_group,group_value,null_val,hypo_val,signal_type,signal_sel,exclude_patients);
    data_null = data.null;
    data_hypo = data.hypo;
    data_master = [data_null; data_hypo];

    % Set parameters
    if testing_type == "patient"
        single_patient_testing = true;
        patients_tested = length(data_master);
    elseif testing_type == "percentage"
        single_patient_testing = false;
        patients_tested = 1;
    else
        error("Unsupported testing type.")
    end

    % Category setup
    resu_patients = 1:length(data_null);
    hypo_patients = (length(data_null)+1):length(data_master);
    Yi = NaN * ones(length(data_master),1);
    Yi(resu_patients) = 0;
    Yi(hypo_patients) = 1;

    % fprintf("Testing model...\n")
    win_spec = zeros(patients_tested,1);
    win_sens = zeros(patients_tested,1);
    win_accy = zeros(patients_tested,1);
    pat_spec = zeros(patients_tested,1);
    pat_sens = zeros(patients_tested,1);
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
            fit = models.fit;
            beta = models.beta;

            if length(models.fit) < iter
                % Find best fit for data using training data
                [beta_lasso,fit(iter)] = lassoglm(fwindows_train_block,Yi_train_vec,'binomial','NumLambda',10,'CV',cv_spec,'Alpha',alpha,'MaxIter',max_iterations);

                % Add first element of beta
                beta_0 = fit.Intercept;
                indx = fit.IndexMinDeviance;
                beta(:,iter) = [beta_0(indx);beta_lasso(:,indx)];

                % Save data file
                save((fullfile(load_path, sprintf("model_%s.mat",paramHash_model))),"beta","fit");
                beta = beta(:,iter);
            else
                beta = models.beta(:,iter);
            end

        catch
            % Find best fit for data using training data
            [beta_lasso,fit] = lassoglm(fwindows_train_block,Yi_train_vec,'binomial','NumLambda',10,'CV',cv_spec,'Alpha',alpha,'MaxIter',max_iterations);

            % Add first element of beta
            beta_0 = fit.Intercept;
            indx = fit.IndexMinDeviance;
            beta = [beta_0(indx);beta_lasso(:,indx)];

            % Save data file
            save((fullfile(load_path, sprintf("model_%s.mat",paramHash_model))),"beta","fit");
        end

        % Get probability Y=1
        test_probs = pvp_regression(fwindows_test_block,beta);
        Yhat_test_vec = (test_probs > probability_cutoff) * 1;

        % Count all/true positives/negatives (window level)
        num_pos = sum(Yhat_test_vec);
        num_neg = length(Yhat_test_vec) - num_pos;
        true_pos = sum(Yi_test_vec & Yhat_test_vec);
        true_neg = sum(~Yi_test_vec & ~Yhat_test_vec);

        % Create sensitivity and specificity measurements (window level)
        win_spec(patient_sel) = true_pos / num_pos;
        win_sens(patient_sel) = true_neg / num_neg;
        win_accy(patient_sel) = (true_pos + true_neg) / (num_pos + num_neg);

        % Create sensitivity and specificity measurements
        if single_patient_testing
            % Patient-based testing
            pat_spec(patient_sel) = win_spec(patient_sel) >= 0.5;
            pat_sens(patient_sel) = win_sens(patient_sel) >= 0.5;
            pat_accy(patient_sel) = win_accy(patient_sel) >= 0.5;
        else
            % Percentage-based testing
            Yi_hat = zeros(length(data_master),1);
            for k = 1:length(data_master)
                patient_indices = test_locations_block == k;
                patient_yhat = mean(Yhat_test_vec(patient_indices));
                Yi_hat(k) = patient_yhat > probability_cutoff;
            end

            % Count all/true positives/negatives (patient level)
            num_pos = sum(Yi_hat);
            num_neg = length(Yi_hat) - num_pos;
            true_pos = sum(Yi & Yi_hat);
            true_neg = sum(~Yi & ~Yi_hat);

            % Create sensitivity and specificity measurements (patient level)
            pat_spec(patient_sel) = true_pos / num_pos;
            pat_sens(patient_sel) = true_neg / num_neg;
            pat_accy(patient_sel) = (true_pos + true_neg) / (num_pos + num_neg);
        end

    end

    % Respecify variables
    metrics_add.win.spec = win_spec;
    metrics_add.win.sens = win_sens;
    metrics_add.win.accy = win_accy;
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
