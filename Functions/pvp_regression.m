function probs = pvp_regression(X,beta)
% This takes a set of horizontal vectors X and uses a vertical vector of
% regression coefficients beta. The output is the probability of Y=1 for
% each row in X
%
% 10/25/2024, Jeremiah Rhys Wimer

X_new = [ones(size(X,1),1) X].';
n = (beta.' * X_new).';

probs = 1 ./ (1 + exp(-n));