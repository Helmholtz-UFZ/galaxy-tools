#' Main function for neuroBEAT
#'
#' Executes the main operations of the package.
#' @export

main <- function(pathToExp, exp_name,
                 pathToFunctions, config, aesthetic_zip = NULL) {

  startUpFunction(utils_folder = file.path(pathToFunctions, "R/utils"),
                  pathToExp = config$pathToExp,
                  aesthetic_zip = aesthetic_zip)

  cat("Executing main function of neuroBEAT for ", config$exp_name, "\n")

  logsheet_adapt(pathToExp = config$pathToExp)

  data_preprocessing(pathToExp = config$pathToExp,
                     exp_name = config$exp_name,
                     healthyAnimalScore = config$healthyAnimalScore)

  conc_data <- conc_data_creation(pathToExp = config$pathToExp, unit_var1 = config$unit_var1, review_colors = config$review_colors)

  doubleVar_timeseries_plotting_median(control_var1 = config$control_var1, # renamed control_chem to control_var1,
                                       unit_var1 = config$unit_var1,
                                       pathToExp = config$pathToExp,
                                       exp_name = config$exp_name,
                                       y_max = config$y_max)


  phase_data_prep(endpoint_list = config$endpoint_list,
                  binsize = config$binsize,
                  phase_name = config$phase_name,
                  exp_name = config$exp_name,
                  pathToExp = config$pathToExp)

  model_fit(x_axis_title = config$x_axis_title,
            y_axis_title = config$y_axis_title,
            #ref_grid_size = config$ref_grid_size,
            phase_name = config$phase_name,
            exp_name = config$exp_name,
            pathToExp = config$pathToExp,
            #unit_var1 = config$unit_var1,
            conc_data = conc_data
  )

  # Concentration-response modeling for timeseries endpoints
  results_TS_endpoints <- CRC_model_phases(phase_name = config$phase_name,
                                           exp_name = config$exp_name,
                                           pathToExp = config$pathToExp,
                                           unit_var1 = config$unit_var1)


  phase_boxplot_plotting_split_exp(phase_name = config$phase_name,
                                   y_axis_title = config$y_axis_title,
                                   pathToExp = config$pathToExp,
                                   unit_var1 = config$unit_var1,
                                   conc_data = conc_data,
                                   var1_def = config$var1_def, # for concentration
                                   control_var1 = config$control_var1
  )

  # Concentration-response modeling for single value endpoints
  results_SV_endpoints <- CRC_LM_double_var(pathToExp = config$pathToExp,
                                            unit_var1 = config$unit_var1,
                                            exp_name = config$exp_name)

  # Combine and save concentration-response modeling results for all endpoints
  results_all_VAMR_endpoints <- bind_rows(results_TS_endpoints, results_SV_endpoints)

  filename <- paste0(gsub("-", "", Sys.Date()), "_", config$exp_name, "_tox_metrics_allEndpoints")
  filepath <- file.path(config$pathToExp, "result_files", "C-R_model", filename)
  saveRDS(results_all_VAMR_endpoints, file = paste0(filepath, ".rds"))
  data.table::fwrite(results_all_VAMR_endpoints, paste0(filepath, ".csv"), sep = ",")

  # Boxplots for single value endpoints
  boxplots_LM(pathToExp = config$pathToExp,
              unit_var1 = config$unit_var1,
              exp_name = config$exp_name,
              var1_def = "c",
              conc_data = conc_data,
              control_var1 = config$control_var1)

  cat("All functions executed.")
}

startUpFunction <- function(utils_folder, pathToExp, aesthetic_zip = NULL #, exp_name, pathToChems
) {

  source(file.path(utils_folder, "Packages.R"))
  load_packages()

  source(file.path(utils_folder, "01_folder_structure_creation_func.R"))
  folder_struct(pathToExp)

  # now you have to load the aestehtic files, zebrabox files and logsheets into the corresponding folders
  cat("1. Load the aesthetic files into the 'aesthetic_files' folder of your experiment folder \n",
      "2. Load the treatment lists into the 'logsheets' folder of your experiment folder \n",
      "3. Load the Zebrabox files into the 'raw_data_ZebraBox' folder of your experiment folder \n")

  # read the aesthetic files
  source(file.path(utils_folder, "aesthetic_files.R"))

  # Check if the user uploaded the aesthetic files, if so, use them, if not use the default ones from the package
  default_dir <- system.file("aesthetic_files", package = "neuroBEAT")
  default_files <- list.files(default_dir, full.names = TRUE)
  pathToAestheticFiles <- file.path(pathToExp, "aesthetic_files")

  if (is.null(aesthetic_zip)) {
    file.copy(default_files, pathToAestheticFiles)
  } else {
    unzip(aesthetic_zip, exdir = pathToAestheticFiles)

    required_files <- c(
      "assay_phases_indiv.csv",
      "assay_phases.csv",
      "acoustic_stimuli.csv",
      "acoustic_stimuli_indiv.csv",
      "stimuli_classes.csv",
      "stimuli_info.csv",
      "VAMR_colors.csv"
    )

    zip_files <- list.files(pathToAestheticFiles, pattern = "\\.csv$", full.names = FALSE)

    missing <- setdiff(required_files, zip_files)

    if (length(missing) > 0) {
      stop(
        paste0(
          "Aesthetic ZIP is invalid.\n",
          "Missing or misnamed required files:\n- ",
          paste(missing, collapse = "\n- ")
        )
      )
    }
  message("Files found in ZIP:\n", paste(zip_files, collapse = ", "))
  }

  read_aesthetics( #conc_data = file.path(pathToExp, "aesthetic_files", "conc_data.csv"),
    assay_data_indiv = file.path(pathToAestheticFiles, "assay_phases_indiv.csv"),
    assay_data = file.path(pathToAestheticFiles, "assay_phases.csv"),
    acoustic_stimuli = file.path(pathToAestheticFiles, "acoustic_stimuli.csv"),
    acoustic_stimuli_indiv = file.path(pathToAestheticFiles, "acoustic_stimuli_indiv.csv"),
    stimuli_classes = file.path(pathToAestheticFiles, "stimuli_classes.csv"),
    stimuli_info = file.path(pathToAestheticFiles, "stimuli_info.csv"),
    assay_colors = file.path(pathToAestheticFiles, "VAMR_colors.csv")
  )

  # Source further utils functions
  source(file.path(utils_folder, "loadData.R"))
  source(file.path(utils_folder, "add_flags_acc.R"))
  source(file.path(utils_folder, "normalize_unit.R"))
}