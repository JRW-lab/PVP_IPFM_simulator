%% Start
% This file loads data from the human and pig dataset to test the accuracy
% of a Elastic-net/ordinal logistical regression model, according to class 
% division set within each profile.
%
% Coded 6/9/2025, JRW
clc; clear; close all;

% Settings
level_view = "win";
data_type = "accy";
max_freq = 30;  % Used for doing cutoff frequency range sweeps
roc_res = 5;    % Higher numbers result in a finer ROC curve
use_parellelization = false;
save_data.priority = "local"; % local or mysql
save_data.save_excel = true;
save_data.save_mysql = false;
create_database_tables = false;
dbname     = 'med_database';
table_name = "lrm_results";

% Introduce, set up connection to MySQL server
addpath(fullfile(pwd, 'Common Functions'));
addpath(fullfile(pwd, 'Functions'));
javaaddpath('mysql-connector-j-8.4.0.jar');
save_data.excel_folder = 'Data';
save_data.excel_name = table_name;
save_data.excel_path = fullfile(save_data.excel_folder,save_data.excel_name + ".xlsx");

% Profile names (for profile selector)
profile_names = {
    "Human - Resuscitated/Hypovolemic (%-based)"
    };
[profile_sel,num_frames] = profile_select(profile_names,true);
data_view = input(" > Select view: ","s");

% Set number of frames per iteration
if num_frames <= 0
    % Settings
    render_figure = true;
    save_sel = true;
    skip_simulations = true;
else
    % Settings
    skip_simulations = false;
    if data_view == "table"
        render_figure = true;
        save_sel = true;
    else
        [render_figure,save_sel] = figure_settings();
    end
end

% Preliminary Setup
if ~isfolder(save_data.excel_folder)
    mkdir(save_data.excel_folder);
end
if ~isfile(save_data.excel_path)
    % Create an empty Excel file
    writematrix([], save_data.excel_path);
end

%% Configurations
switch profile_sel
    case 1
        % Simulation settings
        data_defaults = struct(...
            'dataset', "Human", ...
            'signal_sel', "raw_signal", ...
            'labels', struct("bolus_type", "BB", ...
                             "hypovolemic", "R"), ...
            'exclude_patients', [10,31]);
        data_groups = {
            struct("hypovolemic", "R")
            struct("hypovolemic", "H")
            };
        model_parameters = struct(...
            'window_duration', 1, ...
            'frequency_limit', 30, ...
            'alpha', 0.5, ...
            'probability_cutoff', 0.5, ...
            'training_type', "percentage", ...
            'tshift', 1);

        % Figure settings
        title_vars = ["dataset", "type_sel"];
        if data_view == "figure"
            line_configs = {
                struct('signal_sel', "raw_signal", 'window_duration', 5)
                struct('signal_sel', "raw_signal", 'window_duration', 10)
                struct('signal_sel', "IPFM_signal", 'window_duration', 5)
                struct('signal_sel', "IPFM_signal", 'window_duration', 10)
                struct('signal_sel', "EHR_signal", 'window_duration', 5)
                struct('signal_sel', "EHR_signal", 'window_duration', 10)
                };
            legend_vec = {
                "5s windows, Raw"
                "10s windows, Raw"
                "5s windows, Synth."
                "10s windows, Synth."
                "5s windows, EHR"
                "10s windows, EHR"
                };
            line_styles = {
                "-o"
                "--x"
                "-o"
                "--x"
                "-o"
                "--x"
                };
            line_colors = {
                "#FF0000"
                "#FF0000"
                "#0F62FE"
                "#0F62FE"
                "#24A249"
                "#24A249"
                };
        else
            line_configs = {
                struct('signal_sel', "raw_signal", 'type_sel', "BB")
                struct('signal_sel', "raw_signal", 'type_sel', "AB")
                struct('signal_sel', "IPFM_signal", 'type_sel', "BB")
                struct('signal_sel', "IPFM_signal", 'type_sel', "AB")
                struct('signal_sel', "EHR_signal", 'type_sel', "BB")
                struct('signal_sel', "EHR_signal", 'type_sel', "AB")
                };
            legend_vec = {
                "BB, Raw"
                "AB, Raw"
                "BB, Synth."
                "AB, Synth."
                "BB, EHR"
                "AB, EHR"
                };
            line_styles = {
                "-"
                "--"
                "-"
                "--"
                "-"
                "--"
                };
            line_colors = {
                "#FF0000"
                "#FF0000"
                "#0F62FE"
                "#0F62FE"
                "#24A249"
                "#24A249"
                };
        end
end

% Set up ranges
switch data_view
    case "roc"
        primary_var = "probability_cutoff";
        roc_step = 0.1 / (2^roc_res);
        primary_vals = roc_step:roc_step:(1-roc_step);
    case "table"
        primary_var = "probability_cutoff";
        primary_vals = 0.5;
    case "figure"
        data_type = "accy";
        primary_var = "frequency_limit";
        primary_vals = 5:5:max_freq;
end

%% Simulation setup

% Set up connection to MySQL server
if save_data.save_mysql
    conn_local = mysql_login(dbname);
    if create_database_tables
        % Set up MySQL commands
        sql_table = [
            "CREATE TABLE " + table_name + " (" ...
            "param_hash CHAR(64), " ...
            "parameters JSON, " ...
            "metrics JSON, " ...
            "iteration INT NOT NULL, " ...
            "updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, " ...
            "PRIMARY KEY (param_hash, iteration)" ...
            ");"
            ];
        sql_flags = [
            "CREATE TABLE system_flags (" ...
            "id INT AUTO_INCREMENT PRIMARY KEY, " ...
            "flag_value TINYINT(1) DEFAULT 0" ...
            ");"
            ];
        sql_main_flag = "INSERT INTO system_flags (id, flag_value) VALUES (0, 0);";

        % Execute commands
        try
            execute(conn_local, join(sql_table));
        catch
        end
        try
            execute(conn_local, join(sql_flags));
        catch
        end
        try
            execute(conn_local, join(sql_main_flag));
        catch
        end
    end
else
    conn_local = [];
    if create_database_tables

    end
end

% Check already-saved results
switch save_data.priority
    case "mysql"
        if save_data.save_mysql
            T = mysql_load(conn_local,table_name,"*");
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
            T = mysql_load(conn_local,table_name,"*");
        end
end

% Find function files, get parameter list, modify sim data as needed
var_names = fieldnames(data_defaults);
prvr_len = length(primary_vals);
conf_len = length(line_configs);

% Create result hashes
result_parameters_cell = cell(prvr_len,conf_len);
result_parameters_hashes = strings(prvr_len,conf_len);
prior_frames = zeros(length(primary_vals),length(line_configs));
mergestructs = @(x,y) cell2struct([struct2cell(x);struct2cell(y)],[fieldnames(x);fieldnames(y)]);
for primvar_sel = 1:prvr_len

    % Set primary variable
    primvar_val = primary_vals(primvar_sel);

    % Go through each settings profile
    for conf_sel = 1:conf_len

        % Set configuration
        config_sel = line_configs{conf_sel};

        % Create overall parameters
        model_parameters_inst = model_parameters;
        model_parameters_inst.(primary_var) = primvar_val;
        result_parameters = mergestructs(data_defaults,model_parameters_inst);

        % Overwrite settings with config setting
        config_fields = fields(config_sel);
        for i = 1:length(config_fields)
            result_parameters.(config_fields{i}) = config_sel.(config_fields{i});
        end

        % Remove defaults that are being overwritten
        used_labels = unique(string(cellfun(@(x) fields(x), data_groups, "UniformOutput", false)));
        for i = 1:length(used_labels)
            result_parameters.labels.(used_labels(i)) = NaN;
        end

        % Generate result hash
        result_parameters.data_groups = data_groups;
        [~,result_params_hash] = jsonencode_sorted(result_parameters);

        % Save to stack
        result_parameters_cell{primvar_sel,conf_sel} = result_parameters;
        result_parameters_hashes(primvar_sel,conf_sel) = result_params_hash;

        % Check previous results
        try
            sim_result = T(string(T.param_hash) == result_params_hash, :);
        catch
            sim_result = [];
        end

        % Set prior frames
        if ~isempty(sim_result)
            prior_frames(primvar_sel,conf_sel) = size(sim_result,1);
        else
            prior_frames(primvar_sel,conf_sel) = 0;
        end

    end
end

%% Simulation loop

% Set up connection to MySQL server
if use_parellelization
    if isempty(gcp('nocreate'))
        poolCluster = parcluster('local');
        maxCores = poolCluster.NumWorkers;  % Get the max number of workers available
        parpool(poolCluster, maxCores);     % Start a parallel pool with all available workers
    end
    parfevalOnAll(@() javaaddpath('mysql-connector-j-8.4.0.jar'), 0);
end

% Progress tracking setup
dq = parallel.pool.DataQueue;
afterEach(dq, @updateProgressBar);

for iter = 1:num_frames

    if use_parellelization

        % Go through each settings profile
        parfor primvar_sel = 1:prvr_len
            for conf_sel = 1:conf_len

                % Select parameters
                data_defaults_inst = data_defaults_cell{primvar_sel,conf_sel};

                % Continue to simulate if need more frames
                if iter > prior_frames(primvar_sel,conf_sel)

                    % Set up connection to MySQL server
                    conn_thrall = mysql_login(dbname);

                    % Print message
                    progress_bar_data = data_defaults_inst;
                    progress_bar_data.num_iters = num_frames;
                    progress_bar_data.iter = iter;
                    progress_bar_data.primvar_sel = primvar_sel;
                    progress_bar_data.sel = conf_sel;
                    progress_bar_data.prvr_len = prvr_len;
                    progress_bar_data.conf_len = conf_len;
                    progress_bar_data.current_frames = iter;
                    progress_bar_data.num_frames = num_frames;
                    send(dq, progress_bar_data);

                    % Simulate under current settings
                    model_fun_v3(save_data,conn_thrall,table_name,data_defaults_inst,data_groups,model_parameters,iter)

                    % Close connection instance
                    close(conn_thrall)

                end
            end
        end
    else

        % Go through each settings profile
        for primvar_sel = 1:prvr_len
            for conf_sel = 1:conf_len

                % Select parameters
                result_parameters_inst = result_parameters_cell{primvar_sel,conf_sel};
                result_hash_inst = result_parameters_hashes(primvar_sel,conf_sel);

                % Continue to simulate if need more frames
                if iter > prior_frames(primvar_sel,conf_sel)

                    % Print message
                    progress_bar_data = result_parameters_inst;
                    progress_bar_data.profile_sel = profile_sel;
                    progress_bar_data.configs = line_configs;
                    progress_bar_data.primary_vals = primary_vals;
                    progress_bar_data.sel = conf_sel;
                    progress_bar_data.num_iters = num_frames;
                    progress_bar_data.iter = iter;
                    progress_bar_data.primvar_sel = primvar_sel;
                    progress_bar_data.sel = conf_sel;
                    progress_bar_data.prvr_len = prvr_len;
                    progress_bar_data.conf_len = conf_len;
                    progress_bar_data.current_frames = iter;
                    progress_bar_data.num_frames = num_frames;
                    send(dq, progress_bar_data);

                    % Simulate under current settings
                    model_fun_v3(save_data,conn_local,table_name,result_parameters_inst,result_hash_inst,iter)

                end
            end
        end
    end
end

%% Figure generation

% Set up figure data
figure_data.level_view = level_view;
figure_data.data_type = data_type;
figure_data.primary_var = primary_var;
figure_data.primary_vals = primary_vals;
figure_data.title_vars = title_vars;
figure_data.legend_vec = legend_vec;
figure_data.line_styles = line_styles;
figure_data.line_colors = line_colors;
figure_data.save_sel = false;

% Generate figure
clc;
fprintf("Displaying results for profile %d:\n",profile_sel)
if render_figure
    figure_data.save_sel = save_sel;
    switch data_view
        case "table"
            % Generate table
            gen_table(save_data,conn_local,table_name,result_parameters_hashes,line_configs,figure_data);
        case "figure"
            clf
            % Generate figure
            gen_figure_v2(save_data,conn_local,table_name,result_parameters_hashes,line_configs,figure_data);
        case "roc"
            clf
            % Generate ROC curve
            gen_roc(save_data,conn_local,table_name,result_parameters_hashes,line_configs,figure_data);
    end
end