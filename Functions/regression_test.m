function probs = regression_test(type,X,beta,theta)
% This takes a set of horizontal vectors X and uses a vertical vector of
% regression coefficients beta. The output is the probability of Y=1 for
% each row in X
%
% 10/25/2024, Jeremiah Rhys Wimer

% Add intercept to data and create regression vector
X_new = [ones(size(X,1),1) X].';
n = (beta.' * X_new).';

% Calculate probabilities based on regression type
switch type
    case "elastic"
        probs = 1 ./ (1 + exp(-n));
    case "ordinal"
        CDF_vals = 1 ./ (1 + exp(n - theta.'));
        CDF_vals = [zeros(size(X,1),1) CDF_vals ones(size(X,1),1)];
        probs = diff(CDF_vals.').';
end