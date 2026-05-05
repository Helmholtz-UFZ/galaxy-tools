#' Prepare phase plotting data
#'
#' Aggregates time series values (in the unit of the `time` column) into fixed size
#' bins for endpoints where time dependent behavior is important. For VAMR this
#' includes the visual motor responses and the baseline endpoints in the dark
#' phase at the beginning. Writes the combined dataset for downstream GAMM modeling.
#'
#' @param endpoint_list Character vector of endpoints to include.
#'   For example: c("BSL1", "BSL2", "BSL3", "BSL4", "VMR1", "VMR2", "VMR3", "VMR4", "VMR5").
#' @param binsize Integer. Bin width in the time unit of `time` (e.g., seconds).
#'   For example, `binsize = 60` calculates the sum over 60 time steps per bin.
#' @param phase_name Character string used in output filenames to identify the
#'   endpoint set (e.g., "BSL1_VMR5" or "PhaseSums").
#' @param exp_name Character string specifying the experiment name, used in output file naming.
#' @param pathToExp Character string. Path to the experiment directory containing necessary subdirectories for input and output.
#'
#' @return No return value. Writes CSV and RDA files to `pathToExp/result_files/gam`.
#'
#' @examples
#' \dontrun{
#' phase_data_prep(
#'   endpoint_list = c("BSL1", "BSL2", "BSL3", "BSL4", "VMR1", "VMR2", "VMR3", "VMR4", "VMR5"),
#'   binsize = 60,
#'   phase_name = "BSL1_VMR5",
#'   exp_name = "my_experiment",
#'   pathToExp = "/path/to/experiment"
#' )
#' }
#'
#' @export

#endpoint_list = c("BSL1", "BSL2", "BSL3", "BSL4", "VMR1", "VMR2", "VMR3", "VMR4", "VMR5")
#binsize = 60
#phase_name = "BSL1_VMR5"

phase_data_prep <- function(endpoint_list,
                            binsize,
                            phase_name,
                            exp_name,
                            pathToExp) {

  options(scipen = 999)

  alldata <- loadData(pathToExp = pathToExp)

  allEndpoints <- data.frame()
  for (endp in endpoint_list) {

    endpoint_data <- alldata %>%
      filter(endpoint == endp) %>%
      filter(!if_all(everything(), is.na))

    if (is.null(endpoint_data$experiment)) {
      extract_core_plate <- function(plate_ID) {
        # Change this pattern according to your plate naming rules.
        sub("^([A-Z]+[0-9]+).*", "\\1", plate_ID)
      }
      endpoint_data$core_plate <- extract_core_plate(endpoint_data$plate_ID)
      plates <- unique(endpoint_data$core_plate)
      endpoint_data$experiment <- paste0(plates[[1]], "_", plates[[length(plates)]])
    }

    # create a metadata table and remove duplicated rows
    metadata <- endpoint_data %>%
      dplyr::select(exp_ID, plate_ID, chemical, well, var1, var2, animalID, endpoint, experiment) %>%
      distinct()

    oneMinBins <- seq(min(endpoint_data$time), max(endpoint_data$time), by = binsize)

    # to make sure that there is a bin until the last time value of this endpoint, we need to add a bin if necessary
    if (oneMinBins[length(oneMinBins)] < max(endpoint_data$time)) {
      oneMinBins[length(oneMinBins) + 1] <- max(endpoint_data$time) + 1
    } else {
      oneMinBins[length(oneMinBins)] <- oneMinBins[length(oneMinBins)] + 1
    }

    binned_data <- endpoint_data %>%
      mutate(ranges = cut(as.numeric(endpoint_data$time),
                          breaks = oneMinBins,
                          labels = sprintf("[%d,%d)", head(oneMinBins, -1), tail(oneMinBins, -1)), # sprintf can process two vectors in parallel. Here the first vector has all elements of oneMinBins except the last value and the second vector is has all values of oneMinBins except the first value, resulting in a the intervals
                          right = FALSE))

    binned_data <- binned_data %>%
      group_by(animalID, ranges) %>%
      summarize(sums = sum(as.numeric(value)))

    # no timestamp at this point, retrieve it from the intervals
    # only the last value in the interval is taken for the added time column
    binned_data$time <- as.numeric(gsub("^.*,(.*?))", "\\1",
                                        binned_data$ranges)) - 1

    combined_bin_data <- dplyr::inner_join(binned_data, metadata,
                                           by = "animalID")


    allEndpoints <- rbind(allEndpoints, combined_bin_data)
  }

  # write to csv
  file_name <- paste0(gsub("-", "", Sys.Date()), "_",
                      exp_name, "_", phase_name, "_results")
  full_path <- file.path(pathToExp, "result_files", "gam", file_name)
  data.table::fwrite(allEndpoints, paste0(full_path, ".csv"),
                     row.names = F, quote = F, sep = ",")

  # save as rda file 
  saveRDS(allEndpoints, file = paste0(full_path, ".rds"))

  print("endpoint data written to folder!")
}
