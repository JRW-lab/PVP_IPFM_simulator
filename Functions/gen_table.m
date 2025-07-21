function gen_table(save_data,conn,table_name,default_parameters,configs,figure_data)

% Import parameters
level_view = figure_data.level_view;
data_type = figure_data.data_type;
primary_var = figure_data.primary_var;
primary_vals = figure_data.primary_vals;

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

% Set primary variable
primval_sel = primary_vals;

% Go through each settings profile
var_names = fieldnames(default_parameters);
results_vec = cell(length(configs),1);
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
    DB_data = T(string(T.param_hash) == paramHash, :);

    % Select data to extract
    results_inst = jsondecode(DB_data.metrics{1});
    switch data_type
        case "accy"
            results_val = results_inst.(level_view).accy;
        case "spec"
            results_val = results_inst.(level_view).spec;
        case "sens"
            results_val = results_inst.(level_view).sens;
    end

    if isempty(results_val)
        results_vec{sel} = NaN;
    else
        results_vec{sel} = results_val.';
    end

end

% Get results name for column
results_name = sprintf("%s.%s",level_view,data_type);

% Create results table
data_table = struct2table([configs{:}]);
data_table.(results_name) = results_vec;

% Display table
disp(data_table)