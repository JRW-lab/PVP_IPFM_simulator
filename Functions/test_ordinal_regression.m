%% Test original function
% Add functions
addpath(fullfile(pwd, 'Functions'));

% Define sample length
N = 10;

% Define data (w/ and w/out intercept) and number of categories
X = [1 * ones(1,N); ...
     2 * ones(1,N);...
     3 * ones(1,N);...
     4 * ones(1,N)...
    ];
X_new = [ones(4,1) X];
K = size(X,1);

% Get list of categories per sample
y = (1:K)';

% Train model
model = ordinalglm(X,y,K);
theta = model.theta;
beta = model.beta;

% Perform test on original data for probabilities of each category
regression_test("ordinal",X,beta,theta)

%% TBV Loss Test
