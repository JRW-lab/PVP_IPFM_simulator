function data = load_dataset(parameters)

% Import parameters
signal_type = "PVP";
parameters = rmfield(parameters,"probability_cutoff");
data_groups = parameters.data_groups;
dataset = parameters.dataset;
signal_sel = parameters.signal_sel;
labels = parameters.labels;
exclude_patients = parameters.exclude_patients;

% Load lookup table and set parameters
load_path = "Data/" + dataset + "/";

% Serialize to JSON for DB
dataset_parameters = parameters;
dataset_parameters.data_groups = data_groups;
paramsJSON  = jsonencode_sorted(dataset_parameters);
paramHash = string(DataHash(paramsJSON,'SHA-256'));

try

    % Try to load file
    load((fullfile(load_path, sprintf("dataset_%s.mat",paramHash))));

catch

    % Loop through each entry in the lookup table
    load(fullfile(load_path, 'lookup_table.mat'), 'lookup_table');

    data_signals = cell(length(data_groups), 1);
    [data_signals{:}] = deal(cell(0));
    data_labels = cell(length(data_groups), 1);
    data_T = cell(length(data_groups), 1);
    data_rho = cell(length(data_groups), 1);
    data_names = cell(length(data_groups), 1);
    for i = 1:height(lookup_table)

        for j = 1:length(data_groups)

            % Select current group and get fields
            group_sel = data_groups{j};
            fields_sel = fields(group_sel);
            label_fields = fields(labels);

            % Create labels instance
            labels_sel = labels;
            for k = 1:length(fields_sel)
                labels_sel.(fields_sel{k}) = group_sel.(fields_sel{k});
            end

            flag = true;
            for k = 1:length(label_fields)

                label_inst = lookup_table.(label_fields{k})(i);
                if iscell(label_inst)
                    label_inst = label_inst{1};
                end

                % If data does not match requirement, do not load
                if ~ismember(label_inst,labels_sel.(label_fields{k})) || ismember(lookup_table.subject_number(i),exclude_patients) || ~isequal(lookup_table.signal_type{i}, signal_type)
                    flag = false;
                end

            end

            if flag
                % Load the file
                filename = lookup_table.filename{i};
                file_path = fullfile(load_path, filename);
                S = load(file_path);

                % Store data
                data_signals{j}{end+1,1} = S.data.(signal_sel);
                data_labels{j}(end+1,1) = S.labels;
                data_T{j}(end+1,1) = S.data.T;
                data_rho{j}(end+1,1) = S.data.rho;
                data_names{j}(end+1,1) = S.data.name;

            end

        end

    end

    % Create data structure for exporting
    data.signals = data_signals;
    data.labels = data_labels;
    data.T = data_T;
    data.rho = data_rho;
    data.names = data_names;

    % Save data file
    save((fullfile(load_path, sprintf("dataset_%s.mat",paramHash))),"data");

end