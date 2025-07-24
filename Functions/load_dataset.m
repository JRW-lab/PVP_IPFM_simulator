function [data,labels,T,rho] = load_dataset(dataset,group_type,type_sel,group_category,null_group,hypo_group,group_value,null_val,hypo_val,signal_type,signal_sel,exclude_patients)

% Load lookup table and set parameters
load_path = "Data/" + dataset + "/";

% Serialize to JSON for DB
parameters = struct(...
    'dataset', dataset, ...
    'signal_sel', signal_sel, ...
    'group_type', group_type, ...
    'type_sel', type_sel, ...
    'group_category', group_category, ...
    'null_group', null_group, ...
    'hypo_group', hypo_group, ...
    'group_value', group_value, ...
    'null_val', null_val, ...
    'hypo_val', hypo_val, ...
    'exclude_patients', exclude_patients);
paramsJSON  = jsonencode(parameters);
paramHash = string(DataHash(paramsJSON,'SHA-256'));

try

    % Try to load file
    load((fullfile(load_path, sprintf("dataset_%s.mat",paramHash))));

catch

    % Loop through each entry in the lookup table
    load(fullfile(load_path, 'lookup_table.mat'), 'lookup_table');
    data_null = {};
    data_hypo = {};
    count_null = 0;
    count_hypo = 0;
    labels_null = [];
    labels_hypo = [];
    T_null = [];
    T_hypo = [];
    rho_null = [];
    rho_hypo = [];
    names = [];
    names_null = [];
    names_hypo = [];
    for i = 1:height(lookup_table)

        % Select type instance
        if group_type ~= "NA"
            type_inst = lookup_table.(group_type)(i);
            if ~ismember(type_inst, type_sel)
                continue; % Skip this entry
            end
        end

        % Load the file
        filename = lookup_table.filename{i};
        file_path = fullfile(load_path, filename);
        S = load(file_path);

        % Check for missing or invalid patient
        if ismember(S.data.name,exclude_patients) || ~isequal(S.labels.signal_type, signal_type)
            continue;
        end

        % Determine group membership based on group_category
        label_name = S.labels.(group_category);
        if group_value == "NA"
            label_value = NaN;
        else
            label_value = S.labels.(group_value);
        end

        % Set data in its place
        if ismember(label_name, null_group) && (group_value == "NA" || ismember(label_value, null_val))
            count_null = count_null + 1;
            data_null{count_null,1} = S.data.(signal_sel);
            labels_null = [labels_null S.labels];
            T_null(count_null,1) = S.data.T;
            rho_null(count_null,1) = S.data.rho;
            names_null = [names_null; S.data.name];
        elseif ismember(label_name, hypo_group) && (group_value == "NA" || ismember(label_value, hypo_val))
            count_hypo = count_hypo + 1;
            data_hypo{count_hypo,1} = S.data.(signal_sel);
            labels_hypo = [labels_hypo S.labels];
            T_hypo(count_hypo,1) = S.data.T;
            rho_hypo(count_hypo,1) = S.data.rho;
            names_hypo = [names_hypo; S.data.name];
        end
        names = [names; S.data.name];

    end

    % Create data variables
    data.null = data_null;
    data.hypo = data_hypo;
    labels.null = labels_null;
    labels.hypo = labels_hypo;
    T.null = T_null;
    T.hypo = T_hypo;
    rho.null = rho_null;
    rho.hypo = rho_hypo;

    % Save data file
    save((fullfile(load_path, sprintf("dataset_%s.mat",paramHash))),"data","labels","T","rho");

end

% fprintf("\nComplete!\n\n")