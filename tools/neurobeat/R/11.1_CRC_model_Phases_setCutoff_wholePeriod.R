#' Concentration response modeling for phases (whole period)
#'
#' Builds concentration response models for endpoints aggregated across a whole
#' period, using Fréchet distances to derive responses and computing a cutoff
#' based on either baseline MAD or mean model MAD.
#'
#' @param cutoff_method Character string. Choose between 'bmad' and 'meanMAD' to calculate the cutoff.
#' @param pathToExp Character string. Path to the experiment directory containing necessary subdirectories for input and output.
#' @param exp_name Character string specifying the experiment name, used in input and output file naming.
#'
#' @return Invisibly returns the fitted results object; also writes plots and results to `pathToExp/result_plots/C-R_curves` and `pathToExp/result_files/C-R_model`.
#'
#' @examples
#' \dontrun{
#' CRC_model_wholePeriod(
#'   cutoff_method = "meanMAD",
#'   pathToExp = "/path/to/experiment",
#'   exp_name = "my_experiment"
#' )
#' }
#'
#' @export

# phase_name <- "VMR1_VMR5"

CRC_model_wholePeriod <- function(cutoff_method, pathToExp, exp_name) {

  # 1. Data prep:
  # load plotdata
  plotdata_files <- list.files(file.path(pathToExp, "result_files", "gam"),
                               pattern = "plotdata.*\\.rda",
                               full.names = TRUE,
                               recursive = FALSE
  )
  phase_data <- plotdata_files[which.max(as.Date(substr(basename(plotdata_files), 1, 8), "%Y%m%d"))]
  loaded_objects <- load(file = phase_data)
  phase_data <- get(loaded_objects[1])

  if (any(is.na(phase_data$var1))) {
    cat(
      "var1 contains NA -> Check previous files! \n",
      "NAs deleted -> One ore more concentration(s) might be missing \n")
    phase_data <- phase_data %>% filter(!is.na(var1))
  }


  #results_allEndpoints <- data.frame()

  #for (endpoint in unique(plotdata$phase)) {
  #  phase_data <- plotdata %>%
  #    #filter(phase == "VMR2")
  #    filter(phase == endpoint)
  # If we want one startle response curve for the whole light-dark transition

  phase_name <- paste(as.character(unique(phase_data$phase)[1]),
                      as.character(unique(phase_data$phase)[length(unique(phase_data$phase))]),
                      sep = "-")


  # Calculate Fréchet distances, baseline MAD and baseline SD
  dist_results <- frechetDist_calc(phase_data)

  # Concentration-response Modelling
  # tested concentrations
  conc <- dist_results[["dist_data"]]$conc
  # observed responses at respective concentrations
  resp <- dist_results[["dist_data"]]$dist
  # row object with relevant parameters
  row <- list(conc = conc, resp = resp, bmed = 0, cutoff = dist_results[[cutoff_method]], onesd = dist_results[["bsd"]],
              name = paste0(unique(phase_data$chemical), " ", phase_name))
  # execute concentration-response modeling through potency estimation
  res <- concRespCore(row,
                      fitmodels = c("cnst", "hill", "gnls",
                                    "poly1", "poly2", "pow", "exp2", "exp3",
                                    "exp4", "exp5"),
                      conthits = T)

  # Extract fit_method to modify the legend
  #fit_method <- unique(res$fit_method)
  #legend_entry <- paste0("Fit Method: ", fit_method)

  # Original plot with base settings
  plot <- concRespPlot2(res, log_conc = TRUE) +
    ggtitle(paste0(unique(phase_data$chemical), " ", phase_name)) +
    geom_ribbon(aes(ymin = 0,
                    ymax = dist_results[[cutoff_method]]),
                fill = "grey",
                alpha = 0.4
    ) +
    geom_hline(
      aes(yintercept = dist_results[[cutoff_method]], linetype = cutoff_method
      ),
      color = "grey"
    ) +
    labs(color = "Model", linetype = "", fill = "") +
    theme(axis.text = element_text(size = 20,
                                   colour = "black",
                                   #face = "bold"
    ),
          axis.title = element_text(size = 20,
                                    colour = "black",
                                    face = "bold"),
          plot.title = element_text(size = 20, face = "bold"),
          legend.title = element_text(size = 20,
                                      colour = "black",
                                      face = "bold"),
          legend.text = element_text(size = 20)
    )


  #results_allEndpoints <- rbind(results_allEndpoints, res)

  # save the plot and the dist_results
  filename_curve <- paste0(gsub("-", "", Sys.Date()), "_", exp_name, "_", cutoff_method, "_", phase_name, "_C-R_curve")
  filepath_curve <- file.path(pathToExp, "result_plots", "C-R_curves", filename_curve)
  svg(paste0(filepath_curve, ".svg"))
  print(plot)
  dev.off()

  save(plot, dist_results, file = paste0(filepath_curve, ".rda"))
  #}

  # save the results_allEndpoints
  filename_allEndpoints <- paste0(gsub("-", "", Sys.Date()), "_", exp_name, "_wholePeriod_", cutoff_method, "_", "C-R_model")
  filepath_allEndpoints <- file.path(pathToExp, "result_files", "C-R_model", filename_allEndpoints)

  data.table::fwrite(res, paste0(filepath_allEndpoints, ".csv"),
                     sep = ",")
  save(res, file = paste0(filepath_allEndpoints, ".rda"))

  invisible(res)
}
