function model_fun_v2(conn,num_frames,parameters)

% Settings
project_name = 'BPDB';
load_path = "Models/";
signal_type = "PVP";
training_percentage = 0.7;
cv_spec = 5;
sample_rate = 1000;
max_iterations = 1e8;

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
testing_type = parameters.testing_type;
t_shift = parameters.tshift;

% Set parameters
if testing_type == "patient"
    single_patient_testing = true;
elseif testing_type == "percentage"
    single_patient_testing = false;
else
    error("Unsupported testing type.")
end

% Load dataset
data = load_dataset(dataset,group_type,type_sel,group_category,null_group,hypo_group,group_value,null_val,hypo_val,signal_type,signal_sel,exclude_patients);
data_null = data.null;
data_hypo = data.hypo;

% Category setup
data_master = [data_null; data_hypo];
resu_patients = 1:length(data_null);
hypo_patients = (length(data_null)+1):length(data_master);
Yi = NaN * ones(length(data_master),1);
Yi(resu_patients) = 0;
Yi(hypo_patients) = 1;

% If using single patient testing, select test patient
if single_patient_testing
    patient_sel = randi(length(Yi));
end

% Generate t-windows for all desired signals and data types
if single_patient_testing

    % Select data
    test_index = patient_sel;
    waveforms_train = data_master([1:test_index-1, test_index+1:end]);
    waveforms_test = data_master(test_index);
    Yi_train = Yi([1:test_index-1, test_index+1:end]);
    Yi_test = Yi(test_index);

    % Create t-windows
    twindows_train = cellfun(@(x) make_twindows(x,sample_rate,window_duration,t_shift*sample_rate),waveforms_train,"UniformOutput",false);
    twindows_test = cellfun(@(x) make_twindows(x,sample_rate,window_duration,t_shift*sample_rate),waveforms_test,"UniformOutput",false);

    % Create Yi for training and testing
    Yi_train_vecs = cellfun(@(x,y) ones(size(x,1),1) * y,twindows_train,num2cell(Yi_train),"UniformOutput",false);
    Yi_test_vecs = cellfun(@(x,y) ones(size(x,1),1) * y,twindows_test,num2cell(Yi_test),"UniformOutput",false);

else

    % Find ranges for training and testing
    trange_train = cellfun(@(x) 1:floor(training_percentage*length(x)), data_master,"UniformOutput",false);
    trange_test = cellfun(@(x) ceil(training_percentage*length(x)):length(x), data_master,"UniformOutput",false);

    % Create t-windows
    twindows_train = cellfun(@(x,y) make_twindows(x(y),sample_rate,window_duration,t_shift*sample_rate),data_master,trange_train,"UniformOutput",false);
    twindows_test = cellfun(@(x,y) make_twindows(x(y),sample_rate,window_duration,t_shift*sample_rate),data_master,trange_test,"UniformOutput",false);

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
paramsJSON  = jsonencode(parameters_model);
paramHash = string(DataHash(paramsJSON,'SHA-256'));

% Load model
fprintf("Loading model...\n")
try

    % Try to load file
    load((fullfile(load_path, sprintf("model_%s.mat",paramHash))));

catch

    % Create progress bar
    fprintf("Training and testing elastic-net model...\n")

    % Find best fit for data using training data
    [beta_lasso,fit] = lassoglm(fwindows_train_block,Yi_train_vec,'binomial','NumLambda',10,'CV',cv_spec,'Alpha',alpha,'MaxIter',max_iterations);

    % Add first element of beta
    beta_0 = fit.Intercept;
    indx = fit.IndexMinDeviance;
    beta = [beta_0(indx);beta_lasso(:,indx)];

end


probability_cutoff = parameters.probability_cutoff;

% Load data from DB
sqlquery_results = sprintf("SELECT * FROM lrm_results WHERE param_hash = '%s' AND project_name = '%s'", ...
    paramHash,project_name);
sim_result = fetch(conn, sqlquery_results);

if ~isempty(sim_result)
    % Find new frame count to simulate
    if sim_result.frames_simulated < num_frames
        new_frames = num_frames - sim_result.frames_simulated;
        run_flags = true;
    else
        run_flags = false;
    end
else
    % Simulate given frame count
    new_frames = num_frames;
    run_flags = true;
end

% Run if new frames are needed
if run_flags > 0


    


    % Average over all iterations
    win.spec = mean(win_spec_vec);
    win.sens = mean(win_sens_vec);
    win.accy = mean(win_accy_vec);
    pat.spec = mean(pat_spec_vec);
    pat.sens = mean(pat_sens_vec);
    pat.accy = mean(pat_accy_vec);

    % Set commands
    model_settings = struct(...
            'window_duration', 10, ...
            'frequency_limit', 30, ...
            'alpha', 0.5, ...
            'probability_cutoff', 0.5, ...
            'tshift', 1);
    modelJSON = jsonencode(model_settings);
    flag_sel = 0;
    sqlquery_flag = sprintf("SELECT * FROM system_flags WHERE id = '%d'", ...
        flag_sel);
    sqlquery_flagset = sprintf("UPDATE system_flags SET flag_value=%d WHERE id=%d", ...
        true, flag_sel);
    sqlquery_flagunset = sprintf("UPDATE system_flags SET flag_value=%d WHERE id=%d", ...
        false, flag_sel);

    % Write to database
    need_to_write = true;
    while need_to_write

        % Check system usage flag
        flag_row = fetch(conn, sqlquery_flag);
        flag_val = flag_row.flag_value;

        if ~flag_val

            % Set system usage flag 0
            exec(conn, sqlquery_flagset);

            % Load from DB again
            sim_result = fetch(conn, sqlquery_results);

            if ~isempty(sim_result) % Overwrite row in DB

                % Get new frame count
                N_total = sim_result.frames_simulated + new_frames;

                % Add new data to stack
                old_metrics = jsondecode(sim_result.metrics{1});
                metrics.win.spec = ...
                    (old_metrics.win.spec * sim_result.frames_simulated + win.spec * new_frames) / N_total;
                metrics.win.sens = ...
                    (old_metrics.win.sens * sim_result.frames_simulated + win.sens * new_frames) / N_total;
                metrics.win.accy = ...
                    (old_metrics.win.accy * sim_result.frames_simulated + win.accy * new_frames) / N_total;
                metrics.pat.spec = ...
                    (old_metrics.pat.spec * sim_result.frames_simulated + pat.spec * new_frames) / N_total;
                metrics.pat.sens = ...
                    (old_metrics.pat.sens * sim_result.frames_simulated + pat.sens * new_frames) / N_total;
                metrics.pat.accy = ...
                    (old_metrics.pat.accy * sim_result.frames_simulated + pat.accy * new_frames) / N_total;
                metricsJSON = jsonencode(metrics);

                % Format and execute SQL update string
                sqlupdate = sprintf("UPDATE lrm_results SET metrics = '%s', frames_simulated = %d, model_settings = '%s' WHERE project_name = '%s' AND param_hash = '%s'", ...
                    metricsJSON, ...
                    N_total, ...
                    string(modelJSON), ...
                    project_name, ...
                    paramHash);

                % Update data row
                exec(conn, sqlupdate);

            else % Make new row in DB

                % Get new frame count
                N_total = new_frames;

                % Create new metrics
                metrics.win = win;
                metrics.pat = pat;
                metricsJSON = jsonencode(metrics);

                % Create data row
                sim_result_new = table( ...
                    string(project_name), ...
                    string(paramHash), ...
                    string(modelJSON), ...
                    string(metricsJSON), ...
                    N_total, ...
                    dataset, ...
                    null_group, ...
                    hypo_group, ...
                    testing_type, ...
                    signal_type,...
                    ...
                    'VariableNames', { ...
                    'project_name', ...
                    'param_hash', ...
                    'model_settings', ...
                    'metrics', ...
                    'frames_simulated', ...
                    'dataset', ...
                    'null_group', ...
                    'hypo_group', ...
                    'testing_type', ...
                    'signal_type'} );

                % Add new data row
                sqlwrite(conn,'lrm_results',sim_result_new);

            end

            % Unset system usage flag 0
            exec(conn, sqlquery_flagunset);

            % No longer need to write to database
            need_to_write = false;

        else

            % Wait a random time between 1 and 5 seconds
            waitTime = 1 + (5 - 1) * rand();
            pause(waitTime);

        end

    end

    fprintf("\n")

end
