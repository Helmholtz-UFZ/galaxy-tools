#' Preprocess Zebrabox behavioral data with logsheet metadata
#'
#' This function processes multiple Zebrabox data files along with their corresponding
#' logsheet files to create a cleaned and standardized dataset for behavioral analysis.
#' It joins the zebrabox files with experimental metadata, filters morphologicaly normal larvae,
#' and creates summary statistics (median and MAD) to create the timeseries lineplots.
#'
#' @param pathToExp Character string. Path to the experiment directory containing necessary subdirectories for input and output
#' @param exp_name Character string specifying the experiment name, used in output file naming
#' @param healthyAnimalScore Character vector of phenotype values considered "healthy" for filtering animals.
#' Animals with phenotypes not in this vector will be excluded.
#'  0 = normal, 1 = no swim bladder, 2 = abnormal, 3 = 1 + 2, 4 = dead, 5 = other
#' @param stimuli_info data frame containing stimulus information with columns
#'   'time' and stimulus descriptors.
#'
#' @return A list containing two data frames:
#'   \describe{
#'     \item{processed_data}{Individual animal data with columns: time, value, animalID,
#'       experimental metadata columns, and stimulus columns}
#'     \item{summary_data}{Aggregated data grouped by experimental conditions and time,
#'       with columns: experimental metadata, time, median, mad (median absolute deviation),
#'       and n (sample size)}
#'   }
#'
#' @section File Requirements:
#' \strong{Zebrabox files} should contain:
#' \itemize{
#'   \item UTF-16LE encoding, tab-separated
#'   \item Headers: location, pn, start, end, actinteg, datatype
#'   \item datatype column with "QuantizationSum" entries
#' }
#'
#' \strong{Logsheet files} should contain:
#' \itemize{
#'   \item 'location' column for joining with zebrabox data
#'   \item 'phenotype' column for health filtering
#'   \item Additional metadata columns (exp_ID, plate_ID, chemical, well, var1 etc.)
#' }
#'
#' @examples
#' \dontrun{
#' result <- preprocess_zebrabox_data(
#'   zebrabox_files = zb_files,
#'   logsheet_files = ls_files,
#'   healthyAnimalScore = c("healthy", "normal")
#' )
#'
#' result <- preprocess_zebrabox_data(
#'   healthyAnimalScore = 0
#' )
#' }
#' @export


data_preprocessing <- function(pathToExp, exp_name, healthyAnimalScore) {

  # avoid scientific notation
  options(scipen = 999)

  # ==== FILE DISCOVERY SECTION ====
  zebrabox_files <- list.files(file.path(pathToExp, "raw_data_ZebraBox"),
                               pattern = ".xls", full.names = TRUE)
  logsheet_files <- list.files(file.path(pathToExp, "result_logsheets_for_animallist_creation"),
                               pattern = "\\.rda$", full.names = TRUE)

  logsheet_files <- list.files(file.path(pathToExp, "result_logsheets_for_animallist_creation"),
                               pattern = "\\.rda$", full.names = TRUE)


  # ==== INPUT VALIDATION ====
  if (length(zebrabox_files) == 0) stop("No .xls files found")
  if (length(logsheet_files) == 0) stop("No logsheet files found")

  cat("Found", length(zebrabox_files), "zebrabox files and", length(logsheet_files), "logsheet files\n")

  # ==== MAIN DATA PROCESSING ====
  if (length(zebrabox_files) != length(logsheet_files)) {
    warning("Number of zebrabox files (", length(zebrabox_files),
            ") differs from logsheet files (", length(logsheet_files), ")")
  }

  all_data <- data.frame()
  for (file in seq_along(zebrabox_files)) {
    #all_data <- purr::map2_dfr(zebrabox_files, logsheet_files, function(zb_file, ls_file) {

    cat("Processing:", basename(zebrabox_files[[file]]), "with", basename(logsheet_files[[file]]), "\n")

    # Load logsheet
    logsheet_name <- load(logsheet_files[[file]])
    logsheet <- get(logsheet_name)

    # Create quality filter - keep all columns, just filter by health score
    quality_filter <- logsheet %>%
      filter(phenotype %in% healthyAnimalScore) %>%
      dplyr::select(-phenotype) # Remove phenotype since we already filtered by it

    zb_data <- read.table(zebrabox_files[[file]],
                          fileEncoding = "UTF-16LE",
                          sep = "\t",
                          header = TRUE, # first row is headers
                          stringsAsFactors = FALSE) %>%
      filter(datatype == "QuantizationSum") %>%
      select(location, pn, start, end, actinteg) %>%
      filter((end - start) <= 1) %>%
      # Join with quality filter - this brings in all metadata columns directly
      inner_join(quality_filter, by = "location") %>%
      # Clean up any spaces in text columns
      mutate(across(where(is.character), ~trimws(.)))

    all_data <- bind_rows(all_data, zb_data)
  }

  # ==== FINAL DATA TRANSFORMATION ====
  processed_data <- all_data %>%
    rename(time = pn, value = actinteg) %>%
    dplyr::select(-location, -start, -end) %>%
    mutate(animalID = paste(exp_ID, plate_ID, chemical, well, var1, var2, sep = "_")) %>%
    # Join with stimuli info if available
    left_join(., stimuli_info %>%
      select(end_s, endpoint, stimulus_name, stimulus_name2, stimulus_n),
              by = c("time" = "end_s"))

  # Remove rows with missing values
  processed_data <- processed_data %>%
    filter(!is.na(value), value != "")

  # ==== SUMMARY STATISTICS CALCULATION ====
  summary_data <- processed_data %>%
    group_by(time, chemical, var1, var2, experiment) %>%
    summarise(
      median = median(value, na.rm = TRUE),
      mad = mad(value, constant = 1, na.rm = TRUE),
      n = n(),
      .groups = "drop"
    )

  # ==== FILE SAVING ====
  timestamp <- format(Sys.Date(), "%Y%m%d")

  # Save raw data
  raw_filename_base <- paste0(timestamp, "_", exp_name, "_raw_data_seconds")
  save(processed_data, file = file.path(pathToExp, "result_files", paste0(raw_filename_base, ".rda")))
  data.table::fwrite(processed_data, file.path(pathToExp, "result_files", paste0(raw_filename_base, ".csv")))

  # Save summary data
  summary_filename_base <- paste0(timestamp, "_", exp_name, "_plotdata_timeseries")
  save(summary_data, file = file.path(pathToExp, "result_files", paste0(summary_filename_base, ".rda")))
  data.table::fwrite(summary_data, file.path(pathToExp, "result_files", paste0(summary_filename_base, ".csv")))

  # ==== PROGRESS REPORTING ====
  cat("Processing complete!\n")
  cat("Zebrabox files and logsheets merged\n")
  cat("Plotdata for timeseries lineplots and raw data seconds created and saved\n")
  cat("Summary data end time:", max(summary_data$time), "s \n")

  # Print column structure for verification
  cat("\nFinal data columns:\n")
  cat("Raw data:", paste(colnames(processed_data), collapse = ", "), "\n")
  cat("Summary data:", paste(colnames(summary_data), collapse = ", "), "\n")

  # Show example animalID values
  cat("\nExample animalID values:\n")
  cat(paste(head(unique(processed_data$animalID)), collapse = "\n"), "\n")

  return(list(raw_data = processed_data, summary_data = summary_data))
}





