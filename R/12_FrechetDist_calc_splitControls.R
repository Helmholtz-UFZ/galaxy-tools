#' Fréchet distance calculation for split controls
#'
#' Helper used by concentration response modeling to compute Fréchet distances
#' between modeled curves and derive noise band estimates across experiments.
#'
#' @param phase_data Data frame containing fitted values with and without random
#'   effects (`fit`, `fit2`) and their confidence intervals for each time point
#'   and concentration, including `time`, `var1`, `experiment`, and `animalID`.
#'
#' @return A list with elements:
#'   \describe{
#'     \item{dist_data}{Data frame with columns `dist`, `conc`, `experiment` containing the Fréchet distance to control per experiment}
#'     \item{meanModelMAD_all}{Numeric. Mean distance of control individuals from the experiment level control curve, averaged across experiments}
#'     \item{bsd_model}{Numeric. Baseline standard deviation estimate across experiments}
#'     \item{meanModelMAD_<exp>}{Numeric per experiment. Mean distance for each experiment}
#'   }
#'
#' @examples
#' \dontrun{
#' out <- frechetDist_calc_splitCtrl(phase_data)
#' out$dist_data
#' out$meanModelMAD_all
#' }
#'
#' @export
#'

frechetDist_calc_splitCtrl <- function(phase_data) {
  # get the non-random effect fits for each concentration and timepoint of the selected endpoint
  phase_grouped <- phase_data %>%
    group_by(time, var1, experiment) %>%
    summarise(
      fit2 = first(fit2),
      lwrCI2 = first(lwrCI2),
      upsCI2 = first(uprCI2)
    ) %>%
    ungroup()

  # Initialize outputlist to save the frechet distances between the concentrations and controls
  # and all different methods to calculate the cutoff for combined experiments
  output_list <- list()

  # create a list of all single dataframes for each concentration
  conc_dfs <- list()
  for (exp in unique(phase_grouped$experiment)) {
    exp_df <- phase_grouped %>%
      filter(experiment == exp)

    for (conc in unique(exp_df$var1)) {
      df <- exp_df %>%
        filter(var1 == conc)
      conc_dfs[[paste0(as.character(conc), "_", exp)]] <- df
    }
  }
  str(conc_dfs)

  #2. Frechet distance berechnen
  dist_data <- data.frame(dist = numeric(),
                          conc = numeric(),
                          experiment = character(),
                          stringsAsFactors = FALSE)

  for (conc_key in names(conc_dfs)) {
    # Split the name into concentration and experiment
    splits <- unlist(strsplit(conc_key, "_", fixed = TRUE))
    conc <- splits[1]
    exp_name <- paste(splits[-1], collapse = "_") # The rest after the first "_"

    if (conc == "0") next  # skip controls themselves

    # Find the name of the corresponding control for this experiment
    control_key <- paste0("0_", exp_name)
    if (!control_key %in% names(conc_dfs)) {
      cat("control key not found for ", exp)
      next
    }

    # Extract dfs
    control <- conc_dfs[[control_key]]
    df <- conc_dfs[[conc_key]]

    dist <- distFrechet(control$time, control$fit2,
                        df$time, df$fit2,
                        timeScale = 2, FrechetSumOrMax = "max")

    new_row <- data.frame(dist = dist, conc = as.numeric(conc), experiment = exp_name)
    dist_data <- rbind(dist_data, new_row)
  }

  output_list[["dist_data"]] <- dist_data

  ####################### Calculate Noise band ####################################################
  # 1. Noiseband: Frechét distances between indvidual control curves within the experiment and
  #               the respective mean ('global') curve of each experiment
  control_randEff <- phase_data %>%
    filter(var1 == 0)

  # Distances of each control curve from the mean ('global') control curve of the respsective experiment
  # to calculate meanModelAD
  distances_allSplines_respectiveControls <- list()
  for (exp in unique(control_randEff$experiment)) {
    control <- conc_dfs[[paste0("0_", exp)]]
    exp_df <- control_randEff %>%
      filter(experiment == exp)

    dist_ctrl_fit2 <- list()
    count <- 0
    for (animal in unique(exp_df$animalID)) {
      animal_df <- exp_df %>%
        filter(animalID == animal)

      count <- count + 1
      diff <- distFrechet(animal_df$time, animal_df$fit,
                          control$time, control$fit2)
      dist_ctrl_fit2[[count]] <- diff
    }
    meanModelMAD_value <- mean(unlist(dist_ctrl_fit2))
    #sd_model <- sqrt(sum(unlist(dist_ctrl_fit2)^2) / (length(dist_ctrl_fit2) - 1))
    output_list[[paste0("meanModelMAD_", exp)]] <- meanModelMAD_value

    distances_allSplines_respectiveControls <- append(distances_allSplines_respectiveControls, dist_ctrl_fit2)

  }
  meanModelMAD_value_all <- mean(unlist(distances_allSplines_respectiveControls))
  output_list[["meanModelMAD_all"]] <- meanModelMAD_value_all

  sd_model <- sqrt(sum(unlist(distances_allSplines_respectiveControls)^2) / (length(distances_allSplines_respectiveControls) - 1))
  output_list[["bsd_model"]] <- sd_model

  return(output_list)
}
