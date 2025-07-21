function time_windows = make_twindows(signal,f_s,T_window,shift)

% Define sampling interval and index of frequency cutoff
ts = T_window*f_s;

% Set number of windows
num_windows_set = floor((length(signal) - ts) / shift);

% Loop through training and testing windows
time_windows = zeros(ts,num_windows_set);

% Loop through number of windows
for i = 1:num_windows_set
    range = (i-1)*shift+1:(i-1)*shift+ts;
    time_windows(:,i) = signal(range);
end

% Make correct shape
time_windows = time_windows.';
