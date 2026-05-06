#' Concentration response modeling for phases
#'
#' Builds concentration response models for each endpoint that was modeled with a
#' GAMM and derives potency metrics using Fréchet distances and noise band
#' estimates across split controls.
#'
#' @param phase_name Character string used in output filenames to identify the
#'   endpoint set (e.g., "BSL1_VMR5" or "PhaseSums").
#' @param exp_name Character string specifying the experiment name, used in input and output file naming.
#' @param pathToExp Character string. Path to the experiment directory containing necessary subdirectories for input and output.
#' @param unit_var1 Character string. Unit of measurement for variable 1 (var1). If var1 does not have a unit, unit_var1 = NA.
#'
#' @return A data frame with concentration response metrics per endpoint and experiment.
#'
#' @examples
#' \dontrun{
#' CRC_model_phases(
#'   phase_name = "BSL1_VMR5",
#'   exp_name = "my_experiment",
#'   pathToExp = "/path/to/experiment",
#'   unit_var1 = "\u00B5M"
#' )
#' }
#'
#' @export

##for split exp
#cutoff_method = "meanModelMAD_all"
#bsd = "bsd_model"

## for single exp
#cutoff_method = "meanModelMAD"
#bsd = "bsd_model"
#phase_name = "BSL1_VMR5"
##exp_name = "Ketamine"
##pathToExp = file.path("/run/user/1001/gvfs/smb-share:server=isa.intranet.ufz.de,share=extra/tallab/Experiments_new/neuroBEAT/neuroBEAT_pyCharm/chemicals_VAMR4_ForCluster/chemicals_VAMR4/chemicals_VAMR4", exp_name)

#exp_name = exp_name
#pathToEx = pathToExp
#unit_var1 = "\u00B5M"


CRC_model_phases <- function(phase_name, exp_name, pathToExp, unit_var1) {

  # avoid scientific notation
  options(scipen = 999)

  # required packages (loaded once)
  library(cowplot)
  library(grid)
  library(gridExtra)

  # 1. Data prep:
  # load plotdata
  plotdata_files <- list.files(file.path(pathToExp, "result_files", "gam"),
                               pattern = paste0(phase_name, "_predictions_plotdata_beta_all\\.rds"),
                               full.names = TRUE,
                               recursive = FALSE)

  data <- readRDS(get_latest_file(plotdata_files))

  chemicals <- unique(data$chemical)

  for (chem in chemicals) {
    plotdata <- data %>%
      dplyr::filter(chemical == chem)

    if (any(is.na(plotdata$var1))) {
      cat(
        "var1 contains NA -> Check previous files! \n",
        "NAs deleted -> One ore more concentration(s) might be missing \n")
      plotdata <- plotdata %>% filter(!is.na(var1))
    }

    # If only one experiment, create experiment name
    if (is.null(plotdata$experiment)) {

      extract_core_plate <- function(plate_ID) {
        # Change this pattern according to your plate naming rules.
        sub("^([A-Z]+[0-9]+).*", "\\1", plate_ID)
      }

      plotdata$core_plate <- extract_core_plate(plotdata$plate_ID)
      plates <- unique(plotdata$core_plate)
      plotdata$experiment <- paste0(plates[[1]], "_", plates[[length(plates)]])
    }

    results_allEndpoints <- data.frame()
    for (endp in unique(plotdata$endpoint)) {
      endpoint_data <- plotdata %>%
        filter(endpoint == endp)

      results_allVar2 <- data.frame()
      for (add_var in unique(endpoint_data$var2)) {
        endpoint_data_var2 <- endpoint_data %>%
          dplyr::filter(var2 == add_var)

        # Calculate Fréchet distances, baseline MAD and baseline SD
        dist_results <- frechetDist_calc_splitCtrl(endpoint_data_var2)
        #dist_results <- frechetDist_calc(endpoint_data)

        # Concentration-response Modelling
        # tested concentrations
        conc <- dist_results[["dist_data"]]$conc
        # observed responses at respective concentrations
        resp <- dist_results[["dist_data"]]$dist
        # row object with relevant parameters
        row <- list(conc = conc, resp = resp, bmed = 0, cutoff = dist_results$meanModelMAD_all, onesd = dist_results$bsd_model,
                    chemical = unique(endpoint_data$chemical), endpoint = endp, var2 = add_var)

        # execute concentration-response modeling through potency estimation
        res <- safe_concRespCore(row,
                                 fitmodels = c("cnst", "hill", "gnls",
                                               "poly1", "poly2", "pow", "exp2", "exp3",
                                               "exp4", "exp5"),
                                 conthits = T, poly2.biphasic = TRUE)


        # Original plot with base settings
        plot <- concRespPlot2(res, log_conc = TRUE)

        # Add flags
        res <- add_flags_acc(res)

        plot <- plot +
          ggtitle(paste0(unique(endpoint_data_var2$chemical), " ", endp)) +
          geom_ribbon(aes(ymin = 0,
                          ymax = dist_results$meanModelMAD_all),
                      fill = "grey",
                      alpha = 0.4) +
          geom_hline(
            aes(yintercept = dist_results$meanModelMAD_all, linetype = "cutoff"
            ),
            color = "grey"
          ) +
          geom_vline(
            aes(xintercept = log10(res$ac50), linetype = "AC50"), color = "blue"
          ) +
          labs(color = "Model & Metrics", linetype = NULL, fill = NULL) +
          theme(axis.text = element_text(size = 18,
                                         colour = "black",
                                         #face = "bold"
          ),
                axis.title = element_text(size = 18,
                                          colour = "black",
                                          face = "bold"),
                plot.title = element_text(size = 20, face = "bold"),
                legend.title = element_text(size = 18,
                                            colour = "black",
                                            face = "bold"),
                legend.text = element_text(size = 18),
                legend.position = "right",
                legend.box = "vertical",
                legend.box.spacing = unit(0, "cm"),  # space between “Model” and AC50/ACC/cutoff
                legend.spacing.y = unit(0, "cm"),  # space between entries
                legend.key.height = unit(0.15, "cm"),
                legend.margin = margin(0, 0, 0, 0, "cm")
          ) +
          guides(
            color = guide_legend(order = 1),  # Model legend on top
            linetype = guide_legend(order = 2) # AC50 / ACC / cutoff below
          )

        if (!is.na(res$acc)) {
          plot <- plot +
            geom_vline(aes(xintercept = log10(res$acc), linetype = "ACC"), color = "black")
        }


        legend <- get_legend(plot + theme(legend.position = "right"))

        format_num <- function(x) {
          if (is.na(x)) return("")
          if (abs(x) < 0.01) formatC(x, format = "e", digits = 2) else formatC(x, format = "f", digits = 2)
        }

        # Prepare a data frame
        table_data <- data.frame(
          Name = c("Hitcall",
                   "AC50 ",
                   "ACC ",
                   "Flags"),
          Value = c(
            sprintf("%.2f", res$hitcall),
            paste0(format_num(res$ac50), " ", unit_var1),
            if (!is.na(res$acc)) paste0(format_num(res$acc), " ", unit_var1) else "/",
            gsub(",", "\n", res$flag)
          ),
          stringsAsFactors = FALSE
        )

        tt <- ttheme_default(
          core = list(
            fg_params = list(fontsize = 14),
            padding = unit(c(7, 4), "mm")
          ),
          colhead = list(
            fg_params = list(fontsize = 14),
            padding = unit(c(7, 4), "mm")
          )
        )

        summary_table <- tableGrob(
          table_data,
          rows = NULL,
          cols = NULL,
          theme = tt
        )

        legend_with_text <- ggdraw() +
          # legend at the top (40% of height)
          draw_plot(
            legend,
            x = 0,
            y = 0.55,
            width = 1,
            height = 0.40
          ) +
          # table below the legend (55% of height)
          draw_plot(
            summary_table,
            x = 0,
            y = 0,
            width = 1,
            height = 0.55
          )

        # combine with main plot
        plot_no_legend <- plot + theme(legend.position = "none")

        final_plot <- plot_grid(
          plot_no_legend,
          legend_with_text,
          ncol = 2,
          rel_widths = c(2, 1),
          align = "h",
          axis = "b"
        )

        # print(final_plot)

        # save the plot and the dist_results
        filename_curve <- paste0(gsub("-", "", Sys.Date()), "_", exp_name, "_", add_var, "_", endp, "_beta_C-R_curve")
        filepath_curve <- file.path(pathToExp, "result_plots", "C-R_curves", filename_curve)
        svg(paste0(filepath_curve, ".svg"), width = 7, height = 5)
        print(final_plot)
        dev.off()

        save(final_plot, dist_results, file = paste0(filepath_curve, ".rda"))

        results_allVar2 <- rbind(results_allVar2, res)
      }
      results_allEndpoints <- rbind(results_allEndpoints, results_allVar2)

    }
    results_allEndpoints <- results_allEndpoints %>%
      dplyr::select(-flag_vec)

    # save the results_allEndpoints
    filename_allEndpoints <- paste0(gsub("-", "", Sys.Date()), "_", chem, "_",
                                    exp_name, "_beta_C-R_model")
    filepath_allEndpoints <- file.path(pathToExp, "result_files", "C-R_model", filename_allEndpoints)

    data.table::fwrite(results_allEndpoints, paste0(filepath_allEndpoints, ".csv"),
                       sep = ",")
    save(results_allEndpoints, file = paste0(filepath_allEndpoints, ".rda"))

    return(results_allEndpoints)
  }
}


# helper functions
get_latest_file <- function(files) {
  dates <- as.Date(substr(basename(files), 1, 8), "%Y%m%d")
  files[which.max(dates)]
}

safe_concRespCore <- function(row, fitmodels, conthits, poly2.biphasic) {
  tryCatch(
  {
    concRespCore(row = row,
                 fitmodels = fitmodels,
                 conthits = conthits,
                 poly2.biphasic = poly2.biphasic)
  },
    error = function(e) {
      warning(sprintf("concRespCore failed: %s", conditionMessage(e)))
      NULL # Just indicate failure, continue pipiline
    }
  )
}
