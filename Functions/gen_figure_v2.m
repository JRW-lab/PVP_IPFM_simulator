function gen_figure_v2(save_data,conn,table_name,default_parameters,configs,figure_data)

% Figure settings
render_title = false;
figures_folder = 'Figures';
line_val = 2;
mark_val = 10;
font_val = 16;

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

% Import settings
data_type = figure_data.data_type;
primary_var = figure_data.primary_var;
primary_vals = figure_data.primary_vals;
% title_vars = figure_data.title_vars;
legend_vec = figure_data.legend_vec;
line_styles = figure_data.line_styles;
line_colors = figure_data.line_colors;
save_sel = figure_data.save_sel;

% Load loop
var_names = fieldnames(default_parameters);
results_mean = zeros(length(primary_vals),length(configs));
results_min = zeros(length(primary_vals),length(configs));
results_max = zeros(length(primary_vals),length(configs));
for primvar_sel = 1:length(primary_vals)

    % Set primary variable
    primval_sel = primary_vals(primvar_sel);

    % Go through each settings profile
    for sel = 1:length(configs)

        % Populate parameters from configs or default_parameters
        params_inst = struct();
        for var_sel = 1:length(var_names)
            var_name = var_names{var_sel};
            if isfield(configs{sel}, var_name)
                value = configs{sel}.(var_name);
            elseif ~strcmp(var_name, primary_var)
                value = default_parameters.(var_name);
            else
                value = primval_sel;
            end
            params_inst.(var_name) = value;
        end

        % Load data from DB
        [~,paramHash] = jsonencode_sorted(params_inst);
        sim_result = T(string(T.param_hash) == paramHash, :);

        % Select data to extract
        result_vals = zeros(size(sim_result,1),1);
        for i = 1:size(sim_result,1)
            metrics_loaded = jsondecode(sim_result.metrics{i});
            level_view = figure_data.level_view;
            result_vals(i) = metrics_loaded.(level_view).(data_type);
        end

        % Add result to stack
        results_mean(primvar_sel,sel) = mean(result_vals);
        results_min(primvar_sel,sel) = min(result_vals);
        results_max(primvar_sel,sel) = max(result_vals);

    end
end

% Create folders if they don't exist
subfolder = fullfile(figures_folder, ['/' char(data_type)]);
subsubfolder = fullfile(subfolder, ['/' char(primary_var)]);
if ~exist(figures_folder, 'dir')
    mkdir(figures_folder);
end
if ~exist(subfolder, 'dir')
    mkdir(subfolder);
end
if ~exist(subsubfolder, 'dir')
    mkdir(subsubfolder);
end

% Change label depending on range parameter
switch primary_var
    case "frequency_limit"
        xlabel_name = "Cutoff Frequency (Hz)";
    otherwise
        xlabel_name = primary_var;
end

% Display figure
figure(1)
hold on
for i = 1:size(results_mean,2)

    x_fill = [primary_vals,fliplr(primary_vals)];
    y_fill = [results_min(:,i).', fliplr(results_max(:,i).')];

    % fill(x_fill, y_fill, line_colors{i}, 'FaceAlpha', 0.2, 'EdgeColor', 'none')

    % Convert hex color string to RGB
    baseColorHex = char(line_colors{i}); % this is a cell string, e.g., "#336699"
    baseRGB = sscanf(baseColorHex(2:end), '%2x%2x%2x', [1 3]) / 255;

    % Lighten the color by blending toward white
    lightenFactor = 0.5;                              % 0 = original, 1 = white
    lightRGB = baseRGB + (1 - baseRGB) * lightenFactor;

    % Plot the fill (lighter color)
    fill(x_fill, y_fill, lightRGB, ...
        'FaceAlpha', 0.2, 'EdgeColor', 'none');

    plot(primary_vals,results_mean(:,i), ...
        line_styles{i}, ...
        Color=line_colors{i}, ...
        LineWidth=line_val, ...
        MarkerSize=mark_val)
end
if default_parameters.dataset == "Human"
    ylim_vec = [0.9 1];
    % ylim_vec = [0.7 1];
else
    ylim_vec = [0.6 1];
end
ylabel("Model Accuracy")
% loc = "southwest";
loc = "southeast";
grid on
ylim(ylim_vec)
xlabel(xlabel_name)
xlim([min(primary_vals) max(primary_vals)])
xticks(primary_vals)
legend(legend_vec,Location=loc);
set(gca, 'FontSize', font_val);

if render_title
    % Make title combo
    title_vec = "";
    for i = 1:length(title_vars)
        if i > 1
            title_vec = sprintf("%s, ",title_vec);
        end

        switch title_vars(i)
            case "T"
                title_val = default_parameters.T / 1e-6;
                title_vec = sprintf("%s%s = %.2f",title_vec,title_vars(i),title_val);
            otherwise
                title_val = eval("default_parameters." + title_vars(i));
                title_vec = sprintf("%s%s = %d",title_vec,title_vars(i),title_val);
        end

        if title_vars(i) == "EbN0"
            title_vec = sprintf("%sdB",title_vec);
        elseif title_vars(i) == "vel"
            title_vec = sprintf("%s km/hr",title_vec);
        elseif title_vars(i) == "T"
            title_vec = sprintf("%s us",title_vec);
        end

    end
    title(title_vec)
end

% Save figure
timestamp = datetime('now', 'Format', 'yyyyMMdd_HHmmss');
timestamp_str = char(timestamp);
figure_filename = fullfile(subsubfolder, "Figure_" + timestamp_str + ".png");
if save_sel
    saveas(figure(1), figure_filename);
end