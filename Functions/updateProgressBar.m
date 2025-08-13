function updateProgressBar(d)

% Create variables
config_count = (d.primvar_sel - 1) * d.conf_len + d.sel;
sim_count = config_count + (d.iter - 1) * d.prvr_len * d.conf_len;
config_length = d.prvr_len * d.conf_len;
sim_length = d.num_iters * config_length;

% Set up bar
pct = (sim_count / sim_length) * 100;
bar_len = 50;
filled_len = round(bar_len * sim_count / sim_length);
bar = [repmat('=', 1, filled_len), repmat(' ', 1, bar_len - filled_len)];

% Clear screen and print formatted simulation status
clc;
fprintf("RUNNING PROFILE %d - ITERATION %d of %d\n",d.profile_sel,d.iter,d.num_iters)
fprintf("(%d/%d) Training/testing model using %s.%s waveforms\n", ...
    (d.primvar_sel-1)*length(d.configs) + d.sel, ...
    length(d.configs)*length(d.primary_vals), ...
    d.dataset, ...
    d.signal_sel)
fprintf("        Using %s-based training with a %.2f probability threshold\n",...
    d.training_type, ...
    d.probability_cutoff);
fprintf("        Elastic Net parameter alpha: %s\n",...
    string(d.alpha));
fprintf("        Time-window duration: %s seconds\n",...
    string(d.window_duration));
fprintf("        Time-shift between windows: %s seconds\n",...
    string(d.tshift));
fprintf("        Frequency limit in training: %s Hz\n",...
    string(d.frequency_limit));

fprintf("\n        Groups for model (comma separated):\n");
label_fields = fields(d.labels);
for i = 1:length(label_fields)
    fprintf("        %s: ", label_fields{i});
    for j = 1:length(d.data_groups)
        if ~ismissing(d.labels.(label_fields{i}))
            fprintf("%s", string(d.labels.(label_fields{i})));
        else
            fprintf("%s", string(d.data_groups{j}.(label_fields{i})));
        end
        if j ~= length(d.data_groups)
            fprintf(", ")
        else
            fprintf("\n")
        end
    end
end

% Print progress bar
fprintf("\nProgress: [%s] %3.0f%% (%d/%d)\n\n", ...
    bar, pct, sim_count, sim_length);
end