#' Pre-process endpoint data for statistical analysis
#'
#' This function processes various experimental endpoints by applying specific
#' calculations and transformations to prepare data for downstream statistical
#' analysis. It handles different endpoint types including SR (Startle Response),
#' interval endpoints, and various ASH/ASR endpoint combinations.
#'
#' @param data A data frame containing experimental data with columns including:
#'   endpoint, animalID, var1, var2, chemical, stimulus_name, experiment, value,
#'   and stimulus_n (for some endpoints)
#' @param exp_name Character string specifying the experiment name, used in output file naming
#' @param pathToExp Character string. Path to the experiment directory containing necessary subdirectories for input and output
#' @return A data frame containing processed endpoint data with columns:
#'   animalID, endpoint, var1, var2, chemical, stimulus_name, experiment, and value.
#'   Zero values are replaced with 0.0001 to avoid issues in statistical analysis.
#'
#' @details
#' The function processes different endpoint types as follows:
#' \itemize{
#'   \item SR endpoints: Calculates mean values grouped by experimental factors
#'   \item Interval endpoints (containing "I"): Calculates sum of values
#'   \item ASH1 endpoints: Normalizes values using stimulus numbers <= 10 or >= 21,
#'         then sums normalized values for stimulus_n > 20
#'   \item ASR2_3 endpoints: Calculates ratio ASR3/(ASR2+ASR3), with 0.5 as default
#'         when sum is zero
#'   \item ASH1_5 endpoints: Calculates ratio ASH5/(ASH1+ASH5), with 0.5 as default
#'         when sum is zero
#'   \item ASHsum endpoints: Sums all ASH endpoint values per animal/treatment
#' }
#'
#' @note
#' The function saves results as both CSV and RDS files in the specified
#' pathToExp/result_files directory. File names include the current date and
#' experiment name.
#'
#' @examples
#' \dontrun{
#' # Process endpoint data
#' processed_data <- endp_prep_sv(
#'   data = my_experiment_data,
#'   exp_name = "pilot_study_01",
#'   pathToExp = "/path/to/experiment"
#' )
#' }
#'
#' @seealso
#' \code{\link[dplyr]{filter}}, \code{\link[dplyr]{group_by}},
#' \code{\link[dplyr]{summarise}}, \code{\link[tidyr]{pivot_wider}}
#'
#' @export

endp_prep_sv <- function(data, exp_name, pathToExp) {
  # avoid scientific notation
  options(scipen = 999)

  SR_table <- data %>%
    dplyr::filter(grepl("SR", endpoint, ignore.case = TRUE)) %>%
    dplyr::group_by(animalID, endpoint, var1, var2, chemical, stimulus_name, experiment) %>%
    dplyr::summarise(value = mean(value)) %>%
    dplyr::ungroup()

  interval_table <- data %>%
    dplyr::filter(grepl("I", endpoint, ignore.case = TRUE)) %>%
    dplyr::group_by(animalID, endpoint, var1, var2, chemical, stimulus_name, experiment) %>%
    dplyr::summarise(value = sum(value)) %>%
    dplyr::ungroup()

  ASH1_table <- data %>%
    dplyr::filter(endpoint == "ASH1") %>%
    dplyr::filter(stimulus_n <= 10 | stimulus_n >= 21) %>%
    dplyr::group_by(animalID, endpoint, var1, var2, chemical, stimulus_name, experiment) %>%
    dplyr::mutate(
      norm_value = if (sum(value) > 0) {
        value / sum(value)
      } else {
        0
      }
    ) %>%
    dplyr::filter(stimulus_n > 20) %>%
    dplyr::summarise(value = sum(norm_value)) %>%
    dplyr::ungroup()

  ASH1_table.5 <- data %>%
    dplyr::filter(endpoint == "ASH1") %>%
    dplyr::filter(stimulus_n <= 10 | stimulus_n >= 21) %>%
    dplyr::group_by(animalID, endpoint, var1, var2, chemical, stimulus_name, experiment) %>%
    dplyr::mutate(
      norm_value = if (sum(value) > 0) {
        value / sum(value)
      } else {
        0.5
      }
    ) %>%
    dplyr::filter(stimulus_n > 20) %>%
    dplyr::summarise(value = sum(norm_value)) %>%
    dplyr::ungroup()

  ASR2_3_table <- data %>%
    dplyr::filter(endpoint %in% c("ASR2", "ASR3")) %>%
    dplyr::group_by(chemical, endpoint, var1, var2, animalID, stimulus_name, experiment) %>%
    dplyr::summarise(mean_value = mean(value), .groups = "drop") %>%
    pivot_wider(names_from = endpoint,
                values_from = mean_value) %>%
    # print names without breaking the pipe
  #{ print(names(.)); . } %>%
    dplyr::mutate(value = ifelse((ASR2 + ASR3) == 0, 0.5, ASR3 / (ASR2 + ASR3)),
           endpoint = "ASR_2_3") %>%
    dplyr::select(-c(ASR2, ASR3))

  ASH1_5_table <- data %>%
    dplyr::filter(endpoint %in% c("ASH1", "ASH5")) %>%
    dplyr::filter(!is.na(stimulus_n)) %>%
    dplyr::group_by(chemical, endpoint, var1, var2, animalID, stimulus_name, experiment) %>%
    dplyr::summarise(summed_value = sum(value), .groups = "drop") %>%
    pivot_wider(names_from = endpoint,
                values_from = summed_value) %>%
    dplyr::mutate(value = ifelse((ASH1 + ASH5) == 0, 0.5, ASH5 / (ASH1 + ASH5)),
           endpoint = "ASH_1_5") %>%
    dplyr::select(-c(ASH1, ASH5))

  ASH_sum_table <- data %>%
    dplyr::filter(grepl("ASH", endpoint) & !is.na(stimulus_n)) %>%
    dplyr::group_by(chemical, var1, var2, animalID, stimulus_name, experiment) %>%
    dplyr::summarise(value = sum(value)) %>%
    dplyr::mutate(endpoint = "ASHsum")

  # bind all tables
  endpoint_table <- bind_rows(SR_table, interval_table, ASH1_table, ASR2_3_table, ASH1_5_table, ASH_sum_table)

  endpoint_table$value <- ifelse(endpoint_table$value == 0, 0.0001, endpoint_table$value)

  # write to csv
  filename <- paste0(gsub("-", "", Sys.Date()), "_", exp_name, "_SV_endpoints_pre-processed_results")
  filepath <- file.path(pathToExp, "result_files", filename)
  data.table::fwrite(endpoint_table, paste0(filepath, ".csv"),
                     sep = ",")
  saveRDS(endpoint_table, file = paste0(filepath, ".rds"))

  return(endpoint_table)
}
