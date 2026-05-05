# neuroBEAT

The `neuroBEAT` package is a computational pipeline designed to analyze the Visual and Acoustic Motor Response (VAMR)
Assay, using a variety of statistical models.
The package includes tools to prepare, visualize and model data from the VAMR assay that includes a variety of
endpoints, such as light-dark transition, startle responses, habituation and inter-stimulus activities.
The NeuroBEAT tool can be used to generate concentration–response curves and return AC50 values and point of departure
estimates.

# Features

- **Data Preprocessing**
- **Visualization**
    - detailed time-series plots covering the whole assay and labeling all endpoints and applied stimuli
    - boxplots for individual endpoints
- **Concentration-response Modeling** to model time-series dependent behavior as well as startle responses or summed
  activity
    - curves based on Linear Models and GAMM
    - table with derived toxicological metrics

# Installation

## Prerequisites
Mambaforge or Miniforge with conda-forge channel

### Install Conda/Mamba (pick one):
Mambaforge (recommended): https://github.com/conda-forge/miniforge#mambaforge
Miniforge: https://github.com/conda-forge/miniforge
Conda install guide: https://docs.conda.io/projects/conda/en/latest/user-guide/install

Execute the following steps in the terminal:
## 1. Clone the Repository
```bash
    git clone https://codebase.helmholtz.cloud/ufz/tb3-cite/etox/mtox/neurobeat_package.git
    cd neurobeat_package 
  ```

## 2. Configure Conda (once)
```bash
    conda config --add channels conda-forge
    conda config --add channels bioconda
   ```

## 3. Create and activate the environment  
Use the included conda environment file to create the required environment:
```bash
   conda env create -f environment.yml 
   conda activate neuroBEAT 
  ```

## 4. Install the R package (from repo root)
```bash
   R CMD INSTALL .
  ```

## 5. Verify
```bash
   Rscript -e 'library(neuroBEAT); print(packageVersion("neuroBEAT"));sessionInfo()'
  ```
  

# Getting Started

## 1. Configure the Workflow

- Set the experiment name and the path to the experiment folder
- Set up the required folder structure using `01_folder_structure_creation_func.R`
- Place the Zebrabox files (raw assay data) in the 'raw_data_ZebraBox' folder of your experiment and make sure it is
  saved as a csv file, if not, save it as a csv file
- Load the treatment lists (experimental conditions) into the 'logsheets' folder of your experiment folder
- Place the aesthetic files in the appropriate directory and make sure it suits the assay and the experiment
- set the unit and use '\U03BC' for µ if needed (e.g. µM = '\U03BCM')

## 2. Minimal R workflow

Run the core steps from R using exported functions:

```r
library(neuroBEAT)

pathToExp <- "/path/to/experiment"
exp_name <- "my_experiment"

# 1) Preprocess raw data and logsheets
data_preprocessing(pathToExp = pathToExp, exp_name = exp_name, healthyAnimalScore = 0)

# 2) Build aesthetics/concentration table (edit colors if desired)
conc_data <- conc_data_creation(pathToExp = pathToExp, unit_var1 = "\u00B5M", review_colors = TRUE)

# 3) Timeseries plots (median with MAD) across var1
doubleVar_timeseries_plotting_median(
  control_var1 = "0", unit_var1 = "\u00B5M", pathToExp = pathToExp, exp_name = exp_name, y_max = 8
)

# 4) Prepare binned phase data for GAMM
phase_data_prep(
  endpoint_list = c("BSL1", "BSL2", "BSL3", "BSL4", "VMR1", "VMR2", "VMR3", "VMR4", "VMR5"),
  binsize = 60, phase_name = "BSL1_VMR5", exp_name = exp_name, pathToExp = pathToExp
)

# 5) Fit GAMM and create prediction plots
model_fit(
  x_axis_title = "Time (s)", y_axis_title = "Summed distance moved (px/min)",
  phase_name = "BSL1_VMR5", exp_name = exp_name, pathToExp = pathToExp, unit_var1 = "\u00B5M"
)

# 6) Derive concentration–response metrics for time-series endpoints
ts_metrics <- CRC_model_phases(
  phase_name = "BSL1_VMR5", exp_name = exp_name, pathToExp = pathToExp, unit_var1 = "\u00B5M"
)

# 7) Box/violin plots with LM statistics for single-value endpoints
boxplots_LM(pathToExp = pathToExp, unit_var1 = "\u00B5M", exp_name = exp_name)
```

## 3. Command-line usage (optional)

Run the CLI wrapper to execute stages of the pipeline:

```bash
Rscript 00_mainCLI.R \
  --mode all \
  --name my_experiment \
  --path /path/to/experiment \
  --utils /path/to/neurobeat_package/R/utils \
  --unit_var1 "\u00B5M" \
  --control_var1 0 \
  --y_max 8
```

Use `--mode` to target specific stages (e.g., `plot_timeseries`, `GAMM_model`, `CRC_phases`, `CRC_LM`).

# Aesthetic files required

Place these CSVs in `pathToExp/aesthetic_files/` (used by `read_aesthetics()`):

- assay_phases_indiv.csv: endpoint timing per individual plots
- assay_phases.csv: endpoint timing for aggregated plots
- acoustic_stimuli.csv: timing/labels for acoustic stimuli overlays
- acoustic_stimuli_indiv.csv: per-endpoint acoustic overlays for individual plots
- stimuli_classes.csv: mapping of stimulus classes to colors/styles
- stimuli_info.csv: endpoint and stimulus metadata (names, order, indices)
- VAMR_colors.csv: color palette for assays/endpoints

Optional/generated:

- conc_data.csv: generated by `conc_data_creation()`; can be edited to adjust colors per var1/chemical.

# Licence

# Citation

   
