function gen_roc(conn,default_parameters,configs,figure_data)

% Figure settings
xlabel_name = "1 - Specificity";
ylabel_name = "Sensitivity";
loc = "southeast";
xlim_vec = [0 0.25];
ylim_vec = [0.75 1];

% Import parameters
level_view = figure_data.level_view;
data_type = figure_data.data_type;
primary_var = figure_data.primary_var;
primary_vals = figure_data.primary_vals;
% title_vars = figure_data.title_vars;
legend_vec = figure_data.legend_vec;
line_styles = figure_data.line_styles;
line_colors = figure_data.line_colors;
save_sel = figure_data.save_sel;

% Figure settings
figures_folder = 'Figures';
line_val = 2;
mark_val = 10;
font_val = 16;

% SIM LOOP
var_names = fieldnames(default_parameters);
spec_mat = zeros(length(primary_vals),length(configs));
sens_mat = zeros(length(primary_vals),length(configs));
for primvar_sel = 1:length(primary_vals)

    % Set primary variable
    eval(primary_var + "_inst = " + primary_vals(primvar_sel) + ";");

    for sel = 1:length(configs)

        % set all other variables
        for var_sel = 1:length(var_names)
            if isfield(configs{sel}, var_names{var_sel}) % Set secondary variables
                eval(string(var_names{var_sel})+"_inst = configs{sel}."+string(var_names{var_sel})+";")
            elseif string(var_names{var_sel}) ~= primary_var % Set generic variables
                eval(string(var_names{var_sel})+"_inst = default_parameters."+string(var_names{var_sel})+";")
            end
        end

        % Make current parameters
        params_inst = struct(...
            'dataset', dataset_inst, ...
            'signal_sel', signal_sel_inst, ...
            'group_type', group_type_inst, ...
            'type_sel', type_sel_inst, ...
            'group_category', group_category_inst, ...
            'null_group', null_group_inst, ...
            'hypo_group', hypo_group_inst, ...
            'group_value', group_value_inst, ...
            'null_val', null_val_inst, ...
            'hypo_val', hypo_val_inst, ...
            'exclude_patients', exclude_patients_inst, ...
            'window_duration', window_duration_inst, ...
            'frequency_limit', frequency_limit_inst, ...
            'alpha', alpha_inst, ...
            'probability_cutoff', probability_cutoff_inst, ...
            'testing_type', testing_type_inst, ...
            'tshift', tshift_inst);

        % Serialize to JSON for DB
        paramsJSON  = jsonencode(params_inst);
        paramHash = string(DataHash(paramsJSON,'SHA-256'));

        % Load data from DB
        sqlquery = sprintf("SELECT * FROM lrm_results_v2 WHERE param_hash = '%s' AND project_name = 'BPDB'", ...
            paramHash);
        DB_data = fetch(conn, sqlquery);

        % Select data to extract
        results_inst = jsondecode(DB_data.metrics{1});
        spec_val = results_inst.(level_view).spec;
        sens_val = results_inst.(level_view).sens;

        if isempty(spec_val)
            spec_mat(primvar_sel,sel) = NaN;
        else
            spec_mat(primvar_sel,sel) = spec_val;
        end
        if isempty(sens_val)
            sens_mat(primvar_sel,sel) = NaN;
        else
            sens_mat(primvar_sel,sel) = sens_val;
        end

    end

end

% Create folders if they don't exist
subfolder = fullfile(figures_folder, ['/' char(data_type)]);
subsubfolder = fullfile(subfolder, '/ROC');
if ~exist(figures_folder, 'dir')
    mkdir(figures_folder);
end
if ~exist(subfolder, 'dir')
    mkdir(subfolder);
end
if ~exist(subsubfolder, 'dir')
    mkdir(subsubfolder);
end

% Display figure
figure(1)
hold on
for i = 1:length(configs)
    if sum(1 - spec_mat(:,i)) == 0 && sum(sens_mat(:,i)) == 1 * length(primary_vals)
        x = [0 0 1];
        y = [0 1 1];
    else
        x = 1 - spec_mat(:,i);
        y = sens_mat(:,i);
    end

    plot(x,y, ...
        line_styles{i}, ...
        Color=line_colors{i}, ...
        LineWidth=line_val, ...
        MarkerSize=mark_val)
end

% Set figure settings
xlabel(xlabel_name)
xlim(xlim_vec)
ylabel(ylabel_name)
ylim(ylim_vec)
grid on
legend(legend_vec,Location=loc);
set(gca, 'FontSize', font_val);

% Save figure
timestamp = datetime('now', 'Format', 'yyyyMMdd_HHmmss');
timestamp_str = char(timestamp);
figure_filename = fullfile(subsubfolder, "Figure_" + timestamp_str + ".png");
if save_sel
    saveas(figure(1), figure_filename);
end