function model = ordinalglm(X,y,K)
%
%   X - MxN matrix where each row is a different sample, totaling M samples
%       of N length vectors
%   y - Mx1 vector designating the class of each sample
%   K - Number of classes

% Variables
M = size(X,1);
N = size(X,2) + 1;

% Add buffer to X to add independence during training
X = [ones(M,1) X];

% Initialize beta and theta (cut points)
beta0 = zeros(N,1);
theta0 = linspace(-1,1,K-1).';
params0 = [theta0; beta0];

% Maximize log-likelihood
options = optimoptions('fminunc','Algorithm','quasi-newton','StepTolerance',eps,'MaxFunctionEvaluations',1e8,'Display','none');
params = fminunc(@(p) NLL(p,X,y,K), params0, options);

% Create model variable
model.theta = params(1:(K-1));
model.beta = params(K:end);
model.K = K;

end

function score = NLL(p,X,y,K)

% Import parameters from variable
theta = p(1:(K-1));
beta = p(K:end);
eta = X * beta;

% Loop through all samples
score = 0;
for i = 1:length(y)

    % Define CDF values and probability bounds
    CDF_vals = 1 ./ (1 + exp(eta(i) - theta));
    CDF_vals_adj = [0; CDF_vals; 1];

    % Find probability that this sample is put in the correct class
    p_val = CDF_vals_adj(y(i)+1) - CDF_vals_adj(y(i));

    % Add negative log likelihood to stack
    score = score - log(max(p_val,eps));

end

end