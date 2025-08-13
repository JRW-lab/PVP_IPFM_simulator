function gen_roc(save_data,conn,table_name,result_parameters_hashes,line_configs,figure_data)

% Figure settings
figures_folder = 'Figures';
line_val = 2;
mark_val = 10;
font_val = 16;
xlabel_name = "1 - Specificity";
ylabel_name = "Sensitivity";
loc = "southeast";
xlim_vec = [0 0.2];
ylim_vec = [0.8 1];

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

% Import parameters
data_type = figure_data.data_type;
primary_vals = figure_data.primary_vals;
legend_vec = figure_data.legend_vec;
line_styles = figure_data.line_styles;
line_colors = figure_data.line_colors;
save_sel = figure_data.save_sel;

% SIM LOOP
spec_mat = zeros(length(primary_vals),length(line_configs));
sens_mat = zeros(length(primary_vals),length(line_configs));
for primvar_sel = 1:length(primary_vals)
    for sel = 1:length(line_configs)

        % Load data from parameter hash
        paramHash = result_parameters_hashes(1,sel);
        sim_result = T(string(T.param_hash) == paramHash, :);

        % Select data to extract
        spec_vals = zeros(size(sim_result,1),1);
        sens_vals = zeros(size(sim_result,1),1);
        for i = 1:size(sim_result,1)
            metrics_loaded = jsondecode(sim_result.metrics{i});
            level_view = figure_data.level_view;
            try
                spec_vals(i) = metrics_loaded.(level_view).spec;
            catch
                spec_vals(i) = NaN;
            end
            try
                sens_vals(i) = metrics_loaded.(level_view).sens;
            catch
                sens_vals(i) = NaN;
            end
        end

        % Select data to extract
        spec_mat(primvar_sel,sel) = mean(spec_vals(~isnan(spec_vals)));
        sens_mat(primvar_sel,sel) = mean(sens_vals(~isnan(sens_vals)));

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
for i = 1:length(line_configs)
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