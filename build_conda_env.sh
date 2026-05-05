#!/usr/bin/env bash

# How to create, install, share conda environments:
# https://docs.conda.io/projects/conda/en/latest/user-guide/tasks/manage-environments.html

mamba create -n neuroBEAT -c conda-forge r-base r-reshape2 r-ggplot2 r-car r-dplyr r-data.table r-readxl r-openxlsx \
 r-multcompView r-lme4 r-emmeans r-tidyverse r-mgcv r-readxl r-tibble r-reticulate r-argparse

# How to use conda environment in RSTudio
# https://astrobiomike.github.io/R/managing-r-and-rstudio-with-conda