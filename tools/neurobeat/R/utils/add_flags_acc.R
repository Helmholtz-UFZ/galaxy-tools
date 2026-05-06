#' Add Quality Control Flags to Dose-Response Results
#'
#' This function processes dose-response analysis results and adds quality control
#' flags based on various criteria including hit calling, AC50 values, concentration
#' ranges, and fitting methods. It evaluates data quality and potential issues
#' with the dose-response curves.
#'
#' @param res A data frame containing dose-response analysis results. Expected columns include:
#'   \describe{
#'     \item{conc}{Character. Pipe-separated concentration values (e.g., "0.1|1|10")}
#'     \item{hitcall}{Numeric. Hit call probability (0-1 scale)}
#'     \item{ac50}{Numeric. Half-maximal activity concentration}
#'     \item{top}{Numeric. Top asymptote of the dose-response curve}
#'     \item{cutoff}{Numeric. Activity cutoff threshold}
#'     \item{acc}{Numeric. Activity concentration at cutoff}
#'     \item{fit_method}{Character. Fitting method used (e.g., "gnls")}
#'     \item{n_gt_cutoff}{Integer. Number of points above cutoff}
#'   }
#'
#' @return A data frame identical to the input with additional columns:
#'   \describe{
#'     \item{conc_num}{List column. Numeric vectors of concentration values}
#'     \item{n_conc}{Integer. Number of concentration points tested}
#'     \item{min_conc}{Numeric. Minimum concentration tested}
#'     \item{max_conc}{Numeric. Maximum concentration tested}
#'     \item{flag_vec}{List column. Vector of quality control flags for each row}
#'     \item{flag}{Character. Comma-separated string of flags, or "-" if no flags}
#'   }
#'
#' @details
#' The function applies the following quality control flags:
#' \describe{
#'   \item{no.hit}{Hit call probability < 0.9}
#'   \item{ac50.lowconc}{AC50 below the minimum tested concentration}
#'   \item{border}{Top response within 20% of the cutoff threshold (0.8-1.2× cutoff)}
#'   \item{low.nconc}{Fewer than 4 concentration points tested}
#'   \item{acc.high}{Activity concentration at cutoff exceeds AC50}
#'   \item{glns.lowconc}{For gain-loss fits: AC50 outside the tested concentration range}
#'   \item{singlept.hit.mid}{Single point hit with high hit call (≥0.9)}
#'   \item{multipoint.neg}{Multiple points above cutoff but low hit call (<0.9)}
#'   \item{-}{No flags}
#' }
#'
#' # Add quality control flags
#' flagged_results <- add_flags_acc(results)
#'
#' @seealso
#' \code{\link[dplyr]{mutate}}, \code{\link[purrr]{map}}, \code{\link[stringr]{str_c}}
#'
#' @importFrom dplyr mutate rowwise ungroup
#' @importFrom purrr map map_int map_dbl
#' @importFrom stringr str_c
#'
#' @export

add_flags_acc <- function(res) {

  data <- res %>%
    mutate(
      # Split string into character vector, then as.numeric
      conc_num = map(conc, ~as.numeric(strsplit(.x, "\\|")[[1]])),
      # Calculate the number of concentrations
      n_conc = map_int(conc_num, length),
      # Minimum concentration
      min_conc = map_dbl(conc_num, min, na.rm = TRUE),
      # Maximum concentration
      max_conc = map_dbl(conc_num, max, na.rm = TRUE)
    )

  library(stringr)
  library(dplyr)

  data <- data %>%
    rowwise() %>%
    mutate(
      flag_vec = list(
        c(
          if (!is.na(hitcall) & hitcall < 0.9) "no.hit",
          if (!is.na(ac50) &
            !is.na(min_conc) &
            ac50 < min_conc) "ac50.lowconc",
          if (!is.na(top) &
            !is.na(cutoff) &
            top <= 1.2 * cutoff & top >= 0.8 * cutoff) "border",
          if (!is.na(n_conc) & n_conc < 4) "low.nconc",
          if (!is.na(acc) & !is.na(ac50) & acc > ac50) "acc.high",
          if (fit_method == "gnls" &
            !is.na(ac50) &
            !is.na(min_conc) &
            !is.na(max_conc) &
            (ac50 < min_conc | ac50 > max_conc)) "glns.lowconc",
          if (!is.na(hitcall) &
            hitcall >= 0.9 & n_gt_cutoff == 1) "singlept.hit.mid",
          if (!is.na(hitcall) & hitcall < 0.9 & n_gt_cutoff > 1) "multipoint.neg"
        )
      )
    ) %>%
    mutate(flag = if (length(flag_vec[[1]]) == 0) "-" else str_c(flag_vec, collapse = ",")) %>%
    ungroup()

  return(data)
}