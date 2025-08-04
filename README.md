IMPORTANT: Raw data files used to generate the results seen in the corresponding PVP-IPFM paper can be found on [Dropbox](https://www.dropbox.com/scl/fo/egx7hkhad83lg6gervp3o/APNkwt5TZJsS-P4wQvEtdGE?rlkey=0fnpi931hk9844krbcobjszl8&st=d9brrxda&dl=0). Please download it, rename it 'Data', and place the folder in the main directory of where the code is run.

# PVP-IPFM Simulator (MATLAB with SQL compatibility)
A MATLAB-based simulator for generating logistic regression models for physiological process, with full IPFM-synthesis support. Results can be stored either locally in an Excel file or in an SQL database.

## Introduction
To use this code, you must run it in MATLAB 2024b or higher. The parallelization toolbox is used in the current implementation but can be turned "off" in settings. Additionally, the database toolbox and several others are required, both to simulate and to upload simulation results to MySQL. Commands are included in the code to automatially create the needed tables for MySQL, so long as the correct database is selected.

## Instructions
The code included here is lengthy and may be confusing so here is an overview of how it works:

1. MAIN_model_training.m includes the configurations and when run, the user selects from a series of options.
2. If a sufficient number of frames is not already simulated, model_fun_v3.m is run for a specific system with a set of defined parameters.
4. Step 2 is repeated until all configurations have the sufficient number of frames for figure rendering.
5. gen_figure_v2.m, gen_roc.m and gen_table.m are run for generating figures, ROC curves and tables of data, respectively.

Alternatively, MAIN_sample_data.m offers a statistical overview of the dataset being presented to the system, including a KS two-sample test, empirical pdf's and CDF's, and power spectral density plots.

## Configuration Setup
In MAIN_model_training.m, there is a large section named Configurations. There you will see several pre-configured profiles to use as reference for your own profile. Profiles work by defining the primary variable for a parametric sweep and the corresponding range. If a figure is being rendered, this is the range of the plot, and each line of the parameter 'configs' specifies a line on the plot, and each line has its own custom parameters separate from those specified in default_parameters. Once all the configs are defined, the user can be specific in defining the appearance of plots using several customizable parameters.

ROC curves are a measure of the estimator's ability to balance false positives from false negatives, and is reflected in a plot of Sensitivity vs. (1 - Specificity).

## Further Questions
For any questions please contact jrwimer@uark.edu or visit [my website](jrw-lab.github.io). 
