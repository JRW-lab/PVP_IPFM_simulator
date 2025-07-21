function [y_hat_prime,x_hat,T,rho] = IPFM_algo(yr,fs)
% This code implements the IPFM algorithm to recreate data from the
% fundamental parameters. It's assumed that yr is a time-series vector, 
% and the data takes the form of heartbeat-type waveforms.
%
% JRW, 2/5/2025

% Algorithm parameters
fpass = 15;
t_win = 30;
f0 = 0.5;
dt = 1/fs;
np = fs/2;
t_wait = 0.5;
Vos = 1;
filter_steepness = 1 - 1e-10;

% Step 1
y = lowpass(yr,fpass,fs) + Vos;

% Step 2
tau = movmean(y,[t_win*fs, 0]);
tau = tau - mean(tau);

% Step 3
y_tilde = y - tau;
yHF = highpass(y_tilde,f0,fs,'Steepness',filter_steepness);
yLF = y_tilde - yHF;

% Step 4
[eu,el] = envelope(yHF,np,"peak");
eu_bar = mean(eu,1);
el_bar = mean(el,1);

% Step 5
alpha = (eu_bar - el_bar) / 2;
bpg = mean(yLF,1) ./ alpha;
r = (yLF ./ bpg) - alpha;
x_tilde = yHF ./ (alpha + r);

% Step 6
[~,tk] = findpeaks(-x_tilde, 'MinPeakDistance', t_wait * fs);
T = mean(diff(tk));

% Bias all tk values, assuming each time samples comes after the last
bias = (0:size(yr,2)-1)*size(yr,1);
tk_indices = tk + bias;

% Make a vector of s
s = zeros(size(yr,1)*size(yr,2),1);
s(tk_indices) = 1;

% Find all pulse windows
ranges = [max(tk - ceil(T/2),1), min(tk + floor(T/2),size(yr,1))];
pulses = arrayfun(@(i) x_tilde(ranges(i, 1):ranges(i, 2)).', (1:size(ranges, 1)).', 'UniformOutput', false);
pulses = pulses(2:(end-1),:);
pulses_valid = vertcat(pulses{:});

% Average all pulses for each time waveform
p_tilde = mean(pulses_valid,1).';
t_p = 0:dt:(length(p_tilde)-1)*dt;
p_norm = fs*(p_tilde(end)-p_tilde(1))/T .* t_p.';
p = p_tilde - p_norm;
gamma = trapz(dt,p);

% Step 7
x_hat = conv(p,s);
x_hat = x_hat(ceil(T/2):end);
x_hat = x_hat(1:length(y));

% Step 8
yLF_new = bpg .* (alpha + r);
yHF_new = (alpha + r) .* (x_hat - gamma);
y_hat = tau + yLF_new + yHF_new;
y_hat_prime = yLF_new + yHF_new;

% Generate rho
y_bar = mean(y,1);
y_hat_bar = mean(y_hat,1);
rho = sum((y-y_bar).*(y_hat-y_hat_bar),1) ./ (sqrt(sum((y-y_bar).^2,1)) .* sqrt(sum((y_hat-y_hat_bar).^2,1)));
