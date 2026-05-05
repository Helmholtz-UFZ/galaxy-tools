#' Main CLI Function
#'
#' This function operates as main function for the command-line interface
#' of the neuroBEAT package
#'
#' @param experiment_name \code{character}. Name of the experiment
#' @param folder_path \code{character}. Path to directory, in which input and output data are saved
#' or will be saved
#'
#' @export

library("argparse")
#library(reticulate)

#Sys.setenv(PYTHON = "C:/Users/raabj/AppData/Local/mambaforge/envs/neuroBEAT/python.exe")

# Set the correct conda environment
#Sys.setenv(RETICULATE_MINICONDA_PATH = "C:/Users/raabj/AppData/Local/mambaforge/")
#reticulate::use_condaenv("neuroBEAT", required = TRUE)

# Print python configurations
#py_config <- reticulate::py_config()
#print(py_config)

main_cli <- function() {

  # create a parser object
  parser <- ArgumentParser()

  # Ask for mode
  #parser$add_argument("--zebrabox_files", type = "character", nargs = "+",
  #                    help = "Galaxy paths to uploaded Zebrabox output files that need to be processed to analyze your experiment.")
  #parser$add_argument("--logsheets", type = "character", nargs = "+",
  #                    help = "Galaxy paths to uploaded logsheets.")
  parser$add_argument("--mode",
                      type = "character",
                      choices = c("all", "plot_timeseries", "individual_endpoints_plotting",
                                  "GAMM_model", "CRC_phases", "violin_plots_phases", "CRC_LM",
                                  "CR_modeling_all", "violins_SV", "violins_all"),
                      default = "all",
                      nargs = "+", # accepts one or more options
                      help = "Execute all functions or selected functions. \n Possible choices: all, plot_timeseries,
                      GAMM_model, CRC_phases, voilin_plots_phases, CRC_LM, CR_modeling_all, violins_SV, violins_all \n
                      Default: all")

  # Add command line argument required for every execution (no matter which mode)/ start-up functions
  parser$add_argument("--name", type = "character", required = TRUE, help = "Name of the experiment")
  #parser$add_argument("--path", type = "character", required = TRUE, help = "path to experiment folder")
  parser$add_argument("--utils", type = "character", required = TRUE,
                      help = "Path to utils folder that contains functions e.g. to build a folder structure for input and output files")


  # Add command line arguments for data prep functions
  parser$add_argument("--healthyAnimalScore", type = "numeric", nargs = "+", default = 0,
                      help = "Morphology score/ phenotype that defines which larvae you would like to keep (0 = normal, 1 = no swim bladder, 2 = abnormal, 3 = 1 + 2, 4 = dead, 5 = other). Provide one or more values, separated by spaces. Default: 0")

  # Add command line arguments for creating the conc_data file
  parser$add_argument("--unit_var1", type = "character", default = "\u00B5M",
                      help = "Unit label for var1 (free text). ASCII 'u' will be converted to Unicode 'µ' (e.g., uM → µM). Use '' or 'none' if unitless. Default: µM")
  parser$add_argument("--control_var1", type = "character", default = "0",
                      help = "Var1 value, that serves as control. Can accept numeric and string input. Default: 0")
  parser$add_argument("--control_var2", type = "character", default = NULL,
                      help = "Control value for var2. Optional, only needed if var2 varies. Default: NULL")
  parser$add_argument("--review_colors", type = "logical", default = FALSE,
                      help = "Determines whether the user is prompted to review and optionally edit the colors assigned
                      to each `var1` in `conc_data`. If 'FALSE' the pipeline skips the review step and uses the
                      automatically assigned colors. Default: FALSE")

  # Add command line arguemnts for mode = plot_timeseries
  parser$add_argument("--y_max", type = "numeric", default = 8,
                      help = "Maximum y-axis limit for plots. Set to 6 for zebraboxes with 0-600 motor activity range,
                      or 8 for 0-800 range. Adjust as needed for your specific system. Default: 8")

  # Add command line arguments for mode = gamm_fitting
  parser$add_argument("--endpoint_list", type = "character", nargs = "+", default = c("BSL1", "BSL2", "BSL3", "BSL4", "VMR1", "VMR2", "VMR3", "VMR4", "VMR5"),
                      help = "List of all endpoints that need to be included in the GAMM.
                      Default: BSL1 BSL2 BSL3 BSL4 VMR1 VMR2 VMR3 VMR4 VMR5")

  parser$add_argument("--binsize", type = "numeric", default = 60,
                      help = "the number of time steps (seconds) that should be binned,
                      e.g. binsize = 60 means calculate the summed distance moved over 1 min. Default: 60")

  parser$add_argument("--phase_name", type = "character", default = "BSL1_VMR5",
                      help = "name for the phases you want to plot to create an explanatory file name
                      e.g., for BSL1 - VMR5 it could be 'BSL1_VMR5'. Default: 'BSL1_VMR5'")

  parser$add_argument("--x_axis_title", type = "character", default = "Time (s)",
                      help = "x-axis title for plot. Default: Time (s)")

  parser$add_argument("--y_axis_title", type = "character", default = "Motor activity (px/min)",
                      help = "y_axis title for plot. Default: Motor activity (px/min)")

  parser$add_argument("--var1_def", type = "character", default = "c",
                      help = "definition of var1 that appears in the table next to the violin plot
                      e.g., if var1 is concentration, var1_def could be 'c',
                      so that it appears as column name in the table as c('unit'). Default: c")


  # Parse the arguments
  args <- parser$parse_args()
  pathToExp <- file.path(getwd(), args$name)

  source(file.path(args$utils, "normalize_unit.R"))
  args$unit_var1 <- normalize_unit(args$unit_var1)

  # print(paste("x_axis_title:", args$x_axis_title))
  # print(paste("y_axis_title:", args$y_axis_title))

  print(str(args))
  print(args)
  #stop() #oder exit

  ## Save arguments as global variables
  #exp_name <<- args$name
  #pathToExp <<- pathToExp
  utils_folder <- args$utils


  # Execute startup functions
  startup_function <- function(pathToExp, utils_folder #, aesthetic_zip = NULL
  ) {
    library(neuroBEAT)
    #pathToExp <- file.path(getwd(), exp_name)
    #utils_folder <- file.path()
    source(file.path(utils_folder, "01_folder_structure_creation_func.R"))
    folder_struct(pathToExp)

    #stage_galaxy_inputs(pathToExp = pathToExp,
    #                    zabrabox_files = zebrabox_files,
    #                    logsheets = logsheets)

    source(file.path(utils_folder, "Packages.R"))
    load_packages()
    source(file.path(utils_folder, "aesthetic_files.R"))

    ## Check if the user uploaded the aesthetic files, if so, use them, if not use the default ones from the package
    #default_dir <- system.file("aesthetic_files", package = "neuroBEAT")
    #default_files <- list.files(default_dir, full.names = TRUE)
    pathToAestheticFiles <- file.path(pathToExp, "aesthetic_files")

    #if (is.null(aesthetic_zip)) {
    #  file.copy(default_files, pathToAestheticFiles)
    #} else {
    #  unzip(aesthetic_zip, exdir = pathToAestheticFiles)

    #  required_files <- c(
    #    "assay_phases_indiv.csv",
    #    "assay_phases.csv",
    #    "acoustic_stimuli.csv",
    #    "acoustic_stimuli_indiv.csv",
    #    "stimuli_classes.csv",
    #    "stimuli_info.csv",
    #    "VAMR_colors.csv"
    #  )

    #  zip_files <- list.files(pathToAestheticFiles, pattern = "\\.csv$", full.names = FALSE)

    #  missing <- setdiff(required_files, zip_files)

    #  if (length(missing) > 0) {
    #    stop(
    #      paste0(
    #        "Aesthetic ZIP is invalid.\n",
    #        "Missing or misnamed required files:\n- ",
    #        paste(missing, collapse = "\n- ")
    #      )
    #    )
    #  }
    #  message("Files found in ZIP:\n", paste(zip_files, collapse = ", "))

    read_aesthetics(assay_data_indiv = file.path(pathToAestheticFiles, "assay_phases_indiv.csv"),
                    assay_data = file.path(pathToAestheticFiles, "assay_phases.csv"),
                    acoustic_stimuli = file.path(pathToAestheticFiles, "acoustic_stimuli.csv"),
                    acoustic_stimuli_indiv = file.path(pathToAestheticFiles, "acoustic_stimuli_indiv.csv"),
                    stimuli_classes = file.path(pathToAestheticFiles, "stimuli_classes.csv"),
                    stimuli_info = file.path(pathToAestheticFiles, "stimuli_info.csv"),
                    assay_colors = file.path(pathToAestheticFiles, "VAMR_colors.csv")
    )

    source(file.path(utils_folder, "loadData.R"))
    source(file.path(utils_folder, "add_flags_acc.R"))
  }

  data_prep_function <- function(pathToExp, exp_name, healthyAnimalScore) {
    # Bring logsheet into correct format
    logsheet_adapt(pathToExp = pathToExp)
    # Merge Zebrabox file and animallist
    data_preprocessing(pathToExp = pathToExp,
                       exp_name = exp_name,
                       healthyAnimalScore = healthyAnimalScore)
  }

  execute_plot_timeseries <- function(pathToExp, exp_name, healthyAnimalScore, control_var1, unit_var1,
                                      # assay_data, stimuli_info, stimuli_classes, acoustic_stimuli, assay_data_whole_timeseries,
                                      y_max) {
    cat("Executing functions to create lineplots \n")

    # Add error handling
    tryCatch({
      files <- list.files(file.path(pathToExp, "result_files"), full.names = TRUE,
                          pattern = paste0("^\\d{8}_", exp_name, "_plotdata_timeseries\\.rda$"))

      cat("Found", length(files), "timeseries files\n")

      if (length(files) > 0) {
        cat("Calling timeseries_plotting_median...\n")
        doubleVar_timeseries_plotting_median(control_var1 = control_var1,
                                             unit_var1 = unit_var1,
                                             pathToExp = pathToExp,
                                             exp_name = exp_name,
                                             # assay_data = assay_data,
                                             # stimuli_info = stimuli_info,
                                             # stimuli_classes = stimuli_classes,
                                             # acoustic_stimuli = acoustic_stimuli,
                                             # assay_data_whole_timeseries = assay_data_whole_timeseries,
                                             y_max = y_max)
        cat("timeseries_plotting_median completed\n")
      } else {
        cat("No timeseries files found, running data prep...\n")
        data_prep_function(pathToExp = pathToExp,
                           exp_name = exp_name,
                           healthyAnimalScore = healthyAnimalScore)

        cat("Data prep completed, now calling plotting function...\n")

        doubleVar_timeseries_plotting_median(control_var1 = control_var1,
                                             unit_var1 = unit_var1,
                                             pathToExp = pathToExp,
                                             exp_name = exp_name,
                                             # assay_data = assay_data,
                                             # stimuli_info = stimuli_info,
                                             # stimuli_classes = stimuli_classes,
                                             # acoustic_stimuli = acoustic_stimuli,
                                             # assay_data_whole_timeseries = assay_data_whole_timeseries,
                                             y_max = y_max)
        cat("timeseries_plotting_median completed\n")
      }
    }, error = function(e) {
      cat("ERROR in execute_plot_timeseries:", e$message, "\n")
      traceback()
      stop(e)
    })
  }


  execute_GAMM_fitting <- function(exp_name, pathToExp, healthyAnimalScore, endpoint_list, binsize, phase_name,
                                   x_axis_title, y_axis_title, unit_var1, review_colors, control_var1, control_var2
  ) {
    cat("Executing functions to fit the GAMM \n")

    files <- list.files(file.path(pathToExp, "result_files"), full.names = TRUE,
                        pattern = paste0("^\\d{8}_", exp_name, "_plotdata_timeseries\\.rda$"))

    if (length(files) == 0) {
      data_prep_function(pathToExp = pathToExp,
                         exp_name = exp_name,
                         healthyAnimalScore = healthyAnimalScore)
    }

    #conc_data <- conc_data_creation(pathToExp = pathToExp, unit = unit_var1) # existance of conc_data file is handled within the function
    conc_data <- conc_data_creation(pathToExp = pathToExp, unit = unit_var1, review_colors = review_colors, control_var1 = control_var1, control_var2 = control_var2) # existance of conc_data file is handled within the function


    phase_data_prep(endpoint_list = endpoint_list,
                    binsize = binsize,
                    phase_name = phase_name,
                    exp_name = exp_name,
                    pathToExp = pathToExp)
    model_fit(
      x_axis_title = x_axis_title,
      y_axis_title = y_axis_title,
      phase_name = phase_name,
      exp_name = exp_name,
      pathToExp = pathToExp,
      conc_data = conc_data)
  }

  execute_CRC_modeling_phases <- function(exp_name, pathToExp, healthyAnimalScore, endpoint_list, binsize, phase_name,
                                          x_axis_title, y_axis_title, unit_var1) {
    predict_data_files <- list.files(file.path(pathToExp, "result_files", "gam"),
                                     pattern = paste0(phase_name, "_predictions_plotdata_beta_all\\.rds"),
                                     full.names = TRUE,
                                     recursive = FALSE)

    # Check if GAMM fitting was performed
    if (length(predict_data_files) == 0) {
      # If GAMM wasn't fitted yet, check if data preprocessing was performed
      files <- list.files(file.path(pathToExp, "result_files"), full.names = TRUE,
                          pattern = paste0("^\\d{8}_", exp_name, "_plotdata_timeseries\\.rda$"))

      if (length(files) == 0) {
        data_prep_function(pathToExp = pathToExp,
                           exp_name = exp_name,
                           healthyAnimalScore = healthyAnimalScore)
      }
      execute_GAMM_fitting(exp_name = args$name,
                           pathToExp = pathToExp,
                           healthyAnimalScore = healthyAnimalScore,
                           endpoint_list = args$endpoint_list,
                           binsize = args$binsize,
                           phase_name = args$phase_name,
                           x_axis_title = args$x_axis_title,
                           y_axis_title = args$y_axis_title,
                           unit_var1 = args$unit_var1,
                           review_colors = args$review_colors,
                           control_var1 = args$control_var1,
                           control_var2 = args$control_var2)
    }
    CRC_model_phases(phase_name = phase_name,
                     exp_name = exp_name,
                     pathToExp = pathToExp,
                     unit_var1 = unit_var1)

  }

  execute_violin_plotting_phases <- function(exp_name, pathToExp, healthyAnimalScore, endpoint_list, binsize,
                                             phase_name, x_axis_title, y_axis_title, unit_var1, var1_def,
                                             review_colors, control_var1, control_var2) {

    predict_data_files <- list.files(file.path(pathToExp, "result_files", "gam"),
                                     pattern = paste0(phase_name, "_gamm_beta\\.rds"),
                                     full.names = TRUE,
                                     recursive = FALSE)

    # Check if GAMM fitting was performed
    if (length(predict_data_files) == 0) {
      # If GAMM wasn't fitted yet, check if data preprocessing was performed
      files <- list.files(file.path(pathToExp, "result_files"), full.names = TRUE,
                          pattern = paste0("^\\d{8}_", exp_name, "_plotdata_timeseries\\.rda$"))

      if (length(files) == 0) {
        data_prep_function(pathToExp = pathToExp,
                           exp_name = exp_name,
                           healthyAnimalScore = healthyAnimalScore)
      }
      execute_GAMM_fitting(exp_name = args$name,
                           pathToExp = pathToExp,
                           healthyAnimalScore = healthyAnimalScore,
                           endpoint_list = args$endpoint_list,
                           binsize = args$binsize,
                           phase_name = args$phase_name,
                           x_axis_title = args$x_axis_title,
                           y_axis_title = args$y_axis_title,
                           unit_var1 = args$unit_var1,
                           review_colors = args$review_colors,
                           control_var1 = args$control_var1,
                           control_var2 = args$control_var2)
    }
    #conc_data <- conc_data_creation(pathToExp = pathToExp, unit = unit_var1) # existance of conc_data file is handled within the function
    conc_data <- conc_data_creation(pathToExp = pathToExp, unit = unit_var1, review_colors = review_colors, control_var1 = control_var1, control_var2 = control_var2) # existance of conc_data file is handled within the function


    phase_boxplot_plotting_split_exp(phase_name = phase_name,
                                     y_axis_title = y_axis_title,
                                     pathToExp = pathToExp,
                                     unit_var1 = unit_var1,
                                     var1_def = var1_def,
                                     conc_data = conc_data,
                                     control_var1 = control_var1)
  }

  execute_CRC_modeling_SV_endpoints <- function(pathToExp, exp_name, healthyAnimalScore, unit_var1) {
    files <- list.files(file.path(pathToExp, "result_files"), full.names = TRUE,
                        pattern = paste0("^\\d{8}_", exp_name, "_raw_data_seconds\\.rda$"))

    if (length(files) == 0) {
      data_prep_function(pathToExp = pathToExp,
                         exp_name = exp_name,
                         healthyAnimalScore = healthyAnimalScore)
    }
    CRC_LM_double_var(pathToExp = pathToExp,
                      unit_var1 = unit_var1,
                      exp_name = exp_name)
  }


  execute_CR_modeling_allEndpoints <- function(exp_name, pathToExp, healthyAnimalScore, endpoint_list, binsize, phase_name,
                                               x_axis_title, y_axis_title, # assay_data_whole_timeseries,
                                               unit_var1) {
    CR_TS_files <- list.files(file.path(pathToExp, "result_files", "C-R_model"), full.names = TRUE,
                              pattern = paste0("^\\d{8}_.*", exp_name, ".*_beta_C-R_model\\.rda$"))
    CR_SV_files <- list.files(file.path(pathToExp, "result_files", "C-R_model"), full.names = TRUE,
                              pattern = paste0("^\\d{8}_.*", exp_name, ".*_C-R_model_allSVendpoints.*\\.rds$"))

    if (length(CR_TS_files) == 0 && length(CR_SV_files) == 0) {
      cat("Concentration-response modeling has to be performed for all endpoint types \n")
      cat("Starting with concentration-response modeling for timeseries endpoints \n")
      ts_results <- execute_CRC_modeling_phases(exp_name = exp_name,
                                                pathToExp = pathToExp,
                                                healthyAnimalScore = healthyAnimalScore,
                                                endpoint_list = endpoint_list,
                                                binsize = binsize,
                                                phase_name = phase_name,
                                                x_axis_title = x_axis_title,
                                                y_axis_title = y_axis_title,
                                                #     assay_data_whole_timeseries = assay_data_whole_timeseries,
                                                unit_var1 = unit_var1)
      cat("Concentration-response modeling for single value endpoints \n")
      sv_results <- execute_CRC_modeling_SV_endpoints(pathToExp = pathToExp,
                                                      exp_name = exp_name,
                                                      healthyAnimalScore = healthyAnimalScore,
                                                      unit_var1 = unit_var1)
    } else if (length(CR_TS_files) == 0) {
      cat("Tox metrics for single value endpoints exist. \n")
      cat("Modeling concentration-response relationship for time series endpoints \n")
      ts_results <- execute_CRC_modeling_phases(exp_name = exp_name,
                                                pathToExp = pathToExp,
                                                healthyAnimalScore = healthyAnimalScore,
                                                endpoint_list = endpoint_list,
                                                binsize = binsize,
                                                phase_name = phase_name,
                                                x_axis_title = x_axis_title,
                                                y_axis_title = y_axis_title,
                                                #    assay_data_whole_timeseries = assay_data_whole_timeseries,
                                                unit_var1 = unit_var1)
    } else if (length(CR_SV_files) == 0) {
      cat("Tox metrics for time series endpoints exist. \n")
      cat("Modeling concentration-response relationship for single value endpoints. \n")
      sv_results <- execute_CRC_modeling_SV_endpoints(pathToExp = pathToExp,
                                                      exp_name = exp_name,
                                                      healthyAnimalScore = healthyAnimalScore,
                                                      unit_var1 = unit_var1)
    } else {
      cat("Tox metrics exist for time series and single value endpoints. \n")
      ts_results <- get(load(get_latest_file(CR_TS_files)))
      sv_results <- readRDS(get_latest_file(CR_SV_files))
    }
    cat("Merging result files. \n")
    results_all <- dplyr::bind_rows(ts_results, sv_results)

    # Save results_all
    filename <- paste0(gsub("-", "", Sys.Date()), "_", exp_name, "_tox_metrics_allEndpoints")
    filepath <- file.path(pathToExp, "result_files", "C-R_model", filename)
    saveRDS(results_all, file = paste0(filepath, ".rds"))
    data.table::fwrite(results_all, paste0(filepath, ".csv"), sep = ",")
    cat("Result files are merged and saved in ", file.path(pathToExp, "result_files", "C-R_model"), ". \n")
  }

  execute_violin_plotting_SV_endpoints <- function(pathToExp, exp_name, healthyAnimalScore, unit_var1, var1_def, review_colors, control_var1, control_var2) {
    files <- list.files(file.path(pathToExp, "result_files"), full.names = TRUE,
                        pattern = paste0("^\\d{8}_", exp_name, "_raw_data_seconds\\.rda$"))

    if (length(files) == 0) {
      data_prep_function(pathToExp = pathToExp,
                         exp_name = exp_name,
                         healthyAnimalScore = healthyAnimalScore)
    }

    conc_data <- conc_data_creation(pathToExp = pathToExp, unit = unit_var1, review_colors = review_colors, control_var1 = control_var1, control_var2 = control_var2) # existance of conc_data file is handled within the function

    boxplots_LM(pathToExp = pathToExp,
                unit_var1 = unit_var1,
                exp_name = exp_name,
                var1_def = var1_def,
                conc_data = conc_data,
                control_var1 = control_var1)
  }

  execute_violin_plotting_allEndpoints <- function(exp_name, pathToExp, healthyAnimalScore, endpoint_list, binsize,
                                                   phase_name, x_axis_title, y_axis_title, unit_var1, var1_def,
                                                   control_var1, review_colors, control_var2) {
    execute_violin_plotting_SV_endpoints(pathToExp = pathToExp,
                                         exp_name = args$name,
                                         healthyAnimalScore = args$healthyAnimalScore,
                                         unit_var1 = args$unit_var1,
                                         var1_def = args$var1_def,
                                         control_var1 = args$control_var1,
                                         review_colors = args$review_colors,
                                         control_var2 = args$control_var2)

    execute_violin_plotting_phases(exp_name = args$name,
                                   pathToExp = pathToExp,
                                   healthyAnimalScore = args$healthyAnimalScore,
                                   endpoint_list = args$endpoint_list,
                                   binsize = args$binsize,
                                   phase_name = args$phase_name,
                                   x_axis_title = args$x_axis_title,
                                   y_axis_title = args$y_axis_title,
                                   unit_var1 = args$unit_var1,
                                   var1_def = args$var1_def,
                                   control_var1 = args$control_var1,
                                   review_colors = args$review_colors,
                                   control_var2 = args$control_var2)
  }

  execute_whole_pipeline <- function(exp_name, pathToExp, healthyAnimalScore, endpoint_list, control_var1, y_max, binsize, phase_name,
                                     x_axis_title, y_axis_title, unit_var1, var1_def) {

    execute_plot_timeseries(pathToExp = pathToExp,
                            exp_name = exp_name,
                            healthyAnimalScore = healthyAnimalScore,
                            control_var1 = control_var1,
                            unit_var1 = unit_var1,
                            y_max = y_max)

    execute_CR_modeling_allEndpoints(exp_name = exp_name,
                                     pathToExp = pathToExp,
                                     healthyAnimalScore = healthyAnimalScore,
                                     endpoint_list = endpoint_list,
                                     binsize = binsize,
                                     phase_name = phase_name,
                                     x_axis_title = x_axis_title,
                                     y_axis_title = y_axis_title,
                                     #     assay_data_whole_timeseries = assay_data_whole_timeseries,
                                     unit_var1 = unit_var1)


    execute_violin_plotting_allEndpoints(exp_name = exp_name,
                                         pathToExp = pathToExp,
                                         healthyAnimalScore = healthyAnimalScore,
                                         endpoint_list = endpoint_list,
                                         binsize = binsize,
                                         phase_name = phase_name,
                                         x_axis_title = x_axis_title,
                                         y_axis_title = y_axis_title,
                                         unit_var1 = unit_var1,
                                         var1_def = var1_def)
  }

  args$mode <- unlist(strsplit(args$mode, ","))
  args$mode <- trimws(args$mode)

  # Execute based on selected modes
  for (mode in args$mode) {
    pathToExp <- file.path(getwd(), args$name)

    startup_function(pathToExp = pathToExp,
                     utils_folder = args$utils
                     # aesthetic_zip = NULL
    )

    # modes: "all", "plot_timeseries", ("individual_endpoints_plotting"), "GAMM_model", "CRC_phase", "C-R_modeling"
    switch(mode,
           "plot_timeseries" = execute_plot_timeseries(pathToExp = pathToExp,
                                                       exp_name = args$name,
                                                       healthyAnimalScore = args$healthyAnimalScore,
                                                       control_var1 = args$control_var1,
                                                       unit_var1 = args$unit_var1,
                                                       y_max = args$y_max),

           "GAMM_model" = execute_GAMM_fitting(exp_name = args$name,
                                               pathToExp = pathToExp,
                                               healthyAnimalScore = healthyAnimalScore,
                                               endpoint_list = args$endpoint_list,
                                               binsize = args$binsize,
                                               phase_name = args$phase_name,
                                               x_axis_title = args$x_axis_title,
                                               y_axis_title = args$y_axis_title,
                                               unit_var1 = args$unit_var1,
                                               review_colors = args$review_colors,
                                               control_var1 = args$control_var1,
                                               control_var2 = args$control_var2),

           "CRC_phases" = execute_CRC_modeling_phases(exp_name = args$name,
                                                      pathToExp = pathToExp,
                                                      healthyAnimalScore = args$healthyAnimalScore,
                                                      endpoint_list = args$endpoint_list,
                                                      binsize = args$binsize,
                                                      phase_name = args$phase_name,
                                                      x_axis_title = args$x_axis_title,
                                                      y_axis_title = args$y_axis_title,
                                                      unit_var1 = args$unit_var1),
           "violin_plots_phases" = execute_violin_plotting_phases(exp_name = args$name,
                                                                  pathToExp = pathToExp,
                                                                  healthyAnimalScore = args$healthyAnimalScore,
                                                                  endpoint_list = args$endpoint_list,
                                                                  binsize = args$binsize,
                                                                  phase_name = args$phase_name,
                                                                  x_axis_title = args$x_axis_title,
                                                                  y_axis_title = args$y_axis_title,
                                                                  unit_var1 = args$unit_var1,
                                                                  var1_def = args$var1_def,
                                                                  control_var1 = args$control_var1,
                                                                  review_colors = args$review_colors,
                                                                  control_var2 = args$control_var2),
           "CRC_LM" = execute_CRC_modeling_SV_endpoints(pathToExp = pathToExp,
                                                        exp_name = args$name,
                                                        healthyAnimalScore = args$healthyAnimalScore,
                                                        unit_var1 = args$unit_var1),
           "CR_modeling_all" = execute_CR_modeling_allEndpoints(exp_name = args$name,
                                                                pathToExp = pathToExp,
                                                                healthyAnimalScore = args$healthyAnimalScore,
                                                                endpoint_list = args$endpoint_list,
                                                                binsize = args$binsize,
                                                                phase_name = args$phase_name,
                                                                x_axis_title = args$x_axis_title,
                                                                y_axis_title = args$y_axis_title,
                                                                unit_var1 = args$unit_var1),
           "violins_SV" = execute_violin_plotting_SV_endpoints(pathToExp = pathToExp,
                                                               exp_name = args$name,
                                                               healthyAnimalScore = args$healthyAnimalScore,
                                                               unit_var1 = args$unit_var1,
                                                               var1_def = args$var1_def,
                                                               review_colors = args$review_colors,
                                                               control_var1 = args$control_var1,
                                                               control_var2 = args$control_var2),
           "violins_all" = execute_violin_plotting_allEndpoints(exp_name = args$name,
                                                                pathToExp = pathToExp,
                                                                healthyAnimalScore = args$healthyAnimalScore,
                                                                endpoint_list = args$endpoint_list,
                                                                binsize = args$binsize,
                                                                phase_name = args$phase_name,
                                                                x_axis_title = args$x_axis_title,
                                                                y_axis_title = args$y_axis_title,
                                                                unit_var1 = args$unit_var1,
                                                                var1_def = args$var1_def,
                                                                review_colors = args$review_colors,
                                                                control_var1 = args$control_var1,
                                                                control_var2 = args$control_var2),
           "all" = execute_whole_pipeline(exp_name = args$name,
                                          pathToExp = pathToExp,
                                          healthyAnimalScore = args$healthyAnimalScore,
                                          endpoint_list = args$endpoint_list,
                                          control_var1 = args$control_var1,
                                          y_max = args$y_max,
                                          binsize = args$binsize,
                                          phase_name = args$phase_name,
                                          x_axis_title = args$x_axis_title,
                                          y_axis_title = args$y_axis_title,
                                          unit_var1 = args$unit_var1,
                                          var1_def = args$var1_def,
                                          review_colors = args$review_colors,
                                          control_var2 = args$control_var2)

    )
  }
  #files_to_zip <-
}

main_cli()


