%% Start
% This file loads data from the human and pig dataset to test the accuracy
% of a Elastic-net logistical regression model, according to class division
% set within each profile.
%
% Coded 6/9/2025, JRW
clc; clear; close all;

% Settings
max_freq = 35;  % Used for doing cutoff frequency range sweeps
roc_res = 5;    % Higher numbers result in a finer ROC curve
use_parellelization = true;
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
    "Babies - Resu vs Hypo (%-based)"
    "Babies - Resu vs Hypo (Patient-based)"
    "Pigs   - PRO vs MAC (%-based)"
    "Pigs   - Stable vs Bleeding (%-based)"
    };
[profile_sel,num_frames] = profile_select(profile_names,true);
if profile_sel ~= 2
    data_view = input(" > Select view: ","s");
else
    data_view = "table";
end

% Set number of frames per iteration
frames_per_iter = 1;
if num_frames <= 0
    % Settings
    render_figure = true;
    save_sel = true;
    skip_simulations = true;
else
    % Settings
    skip_simulations = false;
    [render_figure,save_sel] = figure_settings();
end

%% Configurations
switch profile_sel
    case 1 % PROFILE 1 - Human data table accuracies - percentage training
        level_view = "win";
        title_vars = ["dataset", "type_sel"];
        default_parameters = struct(...
            'dataset', "Human", ...
            'signal_sel', "raw_signal", ...
            'group_type', "bolus_type", ...
            'type_sel', "BB", ...
            'group_category', "hypovolemic", ...
            'null_group', "R", ...
            'hypo_group', "H", ...
            'group_value', "NA", ...
            'null_val', [], ...
            'hypo_val', [], ...
            'exclude_patients', ["P10","P31"], ...
            'window_duration', 5, ...
            'frequency_limit', 15, ...
            'alpha', 0.5, ...
            'probability_cutoff', 0.5, ...
            'testing_type', "percentage", ...
            'tshift', 1);
        if data_view == "figure"
            configs = {
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
            configs = {
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

    case 2 % PROFILE 2 - Human data table accuracies - patient-based training
        level_view = "win";
        title_vars = ["dataset", "type_sel"];
        default_parameters = struct(...
            'dataset', "Human", ...
            'signal_sel', "raw_signal", ...
            'group_type', "bolus_type", ...
            'type_sel', "BB", ...
            'group_category', "hypovolemic", ...
            'null_group', "R", ...
            'hypo_group', "H", ...
            'group_value', "NA", ...
            'null_val', [], ...
            'hypo_val', [], ...
            'exclude_patients', ["P10","P31"], ...
            'window_duration', 10, ...
            'frequency_limit', 30, ...
            'alpha', 0.5, ...
            'probability_cutoff', 0.5, ...
            'testing_type', "patient", ...
            'tshift', 1);
        configs = {
            struct('signal_sel', "raw_signal", 'type_sel', "BB")...
            struct('signal_sel', "IPFM_signal", 'type_sel', "BB")...
            struct('signal_sel', "EHR_signal", 'type_sel', "BB")...
            struct('signal_sel', "raw_signal", 'type_sel', "AB")...
            struct('signal_sel', "IPFM_signal", 'type_sel', "AB")...
            struct('signal_sel', "EHR_signal", 'type_sel', "AB")...
            };
        legend_vec = {
            };
        line_styles = {
            };
        line_colors = {
            };

    case 3 % PROFILE 3 - Pig data MAC v PRO table accuracies
        level_view = "win";
        title_vars = ["dataset", "type_sel"];
        default_parameters = struct(...
            'dataset', "Pig", ...
            'signal_sel', "raw_signal", ...
            'group_type', "bleeding", ...
            'type_sel', "S", ...
            'group_category', "anesthetic_type", ...
            'null_group', "MAC", ...
            'hypo_group', "PRO", ...
            'group_value', "anesthetic_level", ...
            'null_val', [1,2,3], ...
            'hypo_val', [1,2,3], ...
            'exclude_patients', "NA", ...
            'window_duration', 10, ...
            'frequency_limit', 30, ...
            'alpha', 0.5, ...
            'probability_cutoff', 0.5, ...
            'testing_type', "percentage", ...
            'tshift', 1);
        if data_view == "figure"
            configs = {
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
            configs = {
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

    case 4 % PROFILE 4 - Pig data S vs B table accuracies
        level_view = "win";
        title_vars = ["dataset", "type_sel"];
        default_parameters = struct(...
            'dataset', "Pig", ...
            'signal_sel', "raw_signal", ...
            'group_type', "anesthetic_type", ...
            'type_sel', "PRO", ...
            'group_category', "bleeding", ...
            'null_group', "S", ...
            'hypo_group', "B", ...
            'group_value', "anesthetic_level", ...
            'null_val', 4, ...
            'hypo_val', 4, ...
            'exclude_patients', "NA", ...
            'window_duration', 10, ...
            'frequency_limit', 35, ...
            'alpha', 0.5, ...
            'probability_cutoff', 0.5, ...
            'testing_type', "percentage", ...
            'tshift', 1);
        if data_view == "figure"
            configs = {
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
            configs = {
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
data_type = "accy";
switch data_view
    case "roc"
        primary_var = "probability_cutoff";
        roc_step = 0.1 / (2^roc_res);
        primary_vals = roc_step:roc_step:(1-roc_step);
    case "table"
        primary_var = "probability_cutoff";
        primary_vals = 0.5;
    case "figure"
        primary_var = "frequency_limit";
        primary_vals = 5:5:max_freq;
end

%% Simulation setup

% Find function files, get parameter list, modify sim data as needed
var_names = fieldnames(default_parameters);
prvr_len = length(primary_vals);
conf_len = length(configs);

% Progress tracking setup
num_iters = ceil(num_frames / frames_per_iter);
dq = parallel.pool.DataQueue;
completed_tasks = 0;
total_tasks = prvr_len*conf_len*num_frames;

% Callback to update progress
afterEach(dq, @updateProgressBar);

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
end

% Ensure the folder exists
if ~isfolder(save_data.excel_folder)
    mkdir(save_data.excel_folder);
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

% Make parameters
params_cell = cell(prvr_len,conf_len);
prior_frames = zeros(length(primary_vals),length(configs));
for primvar_sel = 1:prvr_len

    % Set primary variable
    primvar_val = primary_vals(primvar_sel);

    % Go through each settings profile
    for sel = 1:conf_len

        % set all other variables
        var_vals = cell(length(var_names),1);
        for var_sel = 1:length(var_names)
            if isfield(configs{sel}, var_names{var_sel}) % Set secondary variables
                var_vals{var_sel} = configs{sel}.(cell2mat(var_names(var_sel)));
            elseif string(var_names{var_sel}) ~= primary_var % Set generic variables
                var_vals{var_sel} = default_parameters.(cell2mat(var_names(var_sel)));
            elseif string(var_names{var_sel}) == primary_var % Set primary variable variables
                var_vals{var_sel} = primvar_val;
            end
        end

        % Make parameters
        fields = fieldnames(default_parameters);
        parameters = cell2struct(var_vals, fields);

        % Add parameters to stack
        params_cell{primvar_sel,sel} = parameters;

        % Load data from DB
        [~,paramHash] = jsonencode_sorted(parameters);
        try
            sim_result = T(string(T.param_hash) == paramHash, :);
        catch
            sim_result = [];
        end

        % Set prior frames
        if ~isempty(sim_result)
            prior_frames(primvar_sel,sel) = size(sim_result,1);
        else
            prior_frames(primvar_sel,sel) = 0;
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
else
    conn_thrall = conn_local;
end

for iter = 1:num_iters

    % Set current frame goal
    if iter < num_iters
        current_frames = iter*frames_per_iter;
    else
        current_frames = num_frames;
    end

    if use_parellelization

        % Go through each settings profile
        parfor primvar_sel = 1:prvr_len
            for sel = 1:conf_len

                % Select parameters
                parameters = params_cell{primvar_sel,sel};

                % Continue to simulate if need more frames
                if current_frames > prior_frames(primvar_sel,sel)

                    % Set up connection to MySQL server
                    conn_thrall = mysql_login(dbname);

                    % Print message
                    progress_bar_data = parameters;
                    progress_bar_data.profile_sel = profile_sel;
                    progress_bar_data.configs = configs;
                    progress_bar_data.primary_vals = primary_vals;
                    progress_bar_data.sel = sel;
                    progress_bar_data.num_iters = num_iters;
                    progress_bar_data.iter = iter;
                    progress_bar_data.primvar_sel = primvar_sel;
                    progress_bar_data.sel = sel;
                    progress_bar_data.prvr_len = prvr_len;
                    progress_bar_data.conf_len = conf_len;
                    progress_bar_data.current_frames = current_frames;
                    progress_bar_data.num_frames = num_frames;
                    send(dq, progress_bar_data);

                    % Simulate under current settings
                    model_fun_v3(save_data,conn_thrall,table_name,parameters,iter)

                    % Close connection instance
                    close(conn_thrall)

                end
            end
        end
    else

        % Go through each settings profile
        for primvar_sel = 1:prvr_len
            for sel = 1:conf_len

                % Select parameters
                parameters = params_cell{primvar_sel,sel};

                % Continue to simulate if need more frames
                if current_frames > prior_frames(primvar_sel,sel)

                    % Print message
                    progress_bar_data = parameters;
                    progress_bar_data.profile_sel = profile_sel;
                    progress_bar_data.configs = configs;
                    progress_bar_data.primary_vals = primary_vals;
                    progress_bar_data.sel = sel;
                    progress_bar_data.num_iters = num_iters;
                    progress_bar_data.iter = iter;
                    progress_bar_data.primvar_sel = primvar_sel;
                    progress_bar_data.sel = sel;
                    progress_bar_data.prvr_len = prvr_len;
                    progress_bar_data.conf_len = conf_len;
                    progress_bar_data.current_frames = current_frames;
                    progress_bar_data.num_frames = num_frames;
                    send(dq, progress_bar_data);

                    % Simulate under current settings
                    model_fun_v3(save_data,conn_local,table_name,parameters,iter)

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
            gen_table(save_data,conn_local,table_name,default_parameters,configs,figure_data);
        case "roc"
            clf
            % Generate ROC curve
            gen_roc(save_data,conn_local,table_name,default_parameters,configs,figure_data);
        case "figure"
            clf
            % Generate figure
            gen_figure_v2(save_data,conn_local,table_name,default_parameters,configs,figure_data)
    end
end