#' Concentration response modeling for single value endpoints
#'
#' Builds concentration response models for single value endpoints using results
#' from linear models, calculates cutoffs based on controls, and writes metrics
#' per endpoint, chemical, and experiment.
#'
#' @param pathToExp Character string. Path to the experiment directory containing necessary subdirectories for input and output.
#' @param unit_var1 Character string. Unit of measurement for variable 1 (var1). If var1 does not have a unit, unit_var1 = NA.
#' @param exp_name Character string specifying the experiment name, used in input and output file naming.
#'
#' @return A data frame with concentration response metrics across endpoints for the given experiment(s).
#'
#' @examples
#' \dontrun{
#' CRC_LM_double_var(
#'   pathToExp = "/path/to/experiment",
#'   unit_var1 = "\u00B5M",
#'   exp_name = "my_experiment"
#' )
#' }
#'
#' @export

# functions needed: loadData, data_pre-processing_singleValueEndp

#pathToExp_low_conc <- "/run/user/1001/gvfs/smb-share:server=isa.intranet.ufz.de,share=extra/tallab/Experiments_new/neuroBEAT/neuroBEAT_pyCharm/developmental/NEGATIVES/low_conc/D-Mannitol_VAMR4182-VAMR4184"
#pathToExp_high_conc <- "/run/user/1001/gvfs/smb-share:server=isa.intranet.ufz.de,share=extra/tallab/Experiments_new/neuroBEAT/neuroBEAT_pyCharm/developmental/NEGATIVES/high_conc/D-Mannitol_VAMR4136-VAMR4138"
#pathToExp <- "/run/user/1001/gvfs/smb-share:server=isa.intranet.ufz.de,share=extra/tallab/Experiments_new/neuroBEAT/neuroBEAT_pyCharm/developmental/NEGATIVES/combined/D-Mannitol_dev"

CRC_LM_double_var <- function(pathToExp, unit_var1, exp_name) {
  all_data <- loadData(pathToExp = pathToExp)

  chemicals <- unique(all_data$chemical)

  allChem <- data.frame()
  for (chem in chemicals) {

    chem_data <- all_data %>%
      dplyr::filter(chemical == chem)

    if (is.null(all_data$experiment)) {

      extract_core_plate <- function(plate_ID) {
        # Change this pattern according to your plate naming rules.
        sub("^([A-Z]+[0-9]+).*", "\\1", plate_ID)
      }

      chem_data$core_plate <- extract_core_plate(chem$plate_ID)
      plates <- unique(chem_data$core_plate)
      chem_data$experiment <- paste0(plates[[1]], "_", plates[[length(plates)]])
    }

    #allVar2 <- data.frame()
    #for (add_var in unique(chem_data$var2)) {
    #  var2_data <- chem_data %>%
    #    dplyr::filter(var2 == add_var)

    # data prep: pre-process values according to the requirements of the endpoints
    sv_data <- endp_prep_sv(data = chem_data, exp_name = exp_name, pathToExp = pathToExp)

    # Fit the linear model
    endpoints <- unique(sv_data$endpoint)

    all_endp_df <- data.frame()

    for (endp in endpoints) {
      endpoint_table <- sv_data %>%
        filter(endpoint == endp)

      endpoint_table$value <- ifelse(endpoint_table$value < 1e-4, 1e-4, endpoint_table$value)

      # Split the tibble by "experiment" column
      split_tables <- split(endpoint_table, endpoint_table$experiment)

      model_data <- list()
      for (exp in 1:length(split_tables)) {
        model_data[[exp]] <- lm_func(data = split_tables[[exp]], pathToExp = pathToExp)[[2]]
      }
      plotdata <- do.call(bind_rows, model_data)

      allVar2 <- data.frame()
      for (add_var in unique(plotdata$var2)) {
        var2_data <- plotdata %>%
          dplyr::filter(var2 == add_var)

        # Calculate cutoff and standard deviation
        control_data <- var2_data %>%
          filter(var1 == 0)

        mad_all_controls_splitByExp <- control_data %>%
          group_by(experiment) %>%
          mutate(centered = abs(value - mean(value))) %>%
          ungroup() %>%
          summarize(MAD = mean(centered)) %>%
          pull(MAD)

        sd_all_controls_splitByExp <- control_data %>%
          group_by(experiment) %>%
          mutate(centered = (value - mean(value))^2) %>%
          ungroup() %>%
          summarize(SD = sqrt(mean(centered))) %>%
          pull(SD)

        dist_data_allExp <- data.frame()
        for (exp in unique(var2_data$experiment)) {
          # Sort by concentration
          exp_data <- var2_data %>%
            dplyr::filter(experiment == exp) %>%
            dplyr::arrange(var1)
          #exp_data <- exp_data[order(exp_data$var1),]

          dist_data <- data.frame()
          for (conc in unique(exp_data$var1[exp_data$var1 != 0])) {
            conc_value <- exp_data %>%
              dplyr::filter(var1 == conc) %>%
              pull(prediction) %>%
              unique()

            control_value <- control_data %>%
              dplyr::filter(experiment == exp) %>%
              pull(prediction) %>%
              unique()

            response <- abs(conc_value - control_value)

            dist <- data.frame(conc = conc,
                               resp = response,
                               experiment = exp)
            dist_data <- bind_rows(dist_data, dist)
          }
          dist_data_allExp <- bind_rows(dist_data_allExp, dist_data)
        }

        row = list(
          conc = as.numeric(dist_data_allExp$conc),  # conc_df is plotdata without controls
          resp = dist_data_allExp$resp,
          bmed = 0,
          cutoff = mad_all_controls_splitByExp,
          onesd = sd_all_controls_splitByExp,
          chemical = chem, endpoint = endp, var2 = add_var
        )

        res <- safe_concRespCore(row,
                                 fitmodels = c("cnst", "hill", "gnls",
                                               "poly1", "poly2", "pow", "exp2", "exp3",
                                               "exp4", "exp5"),
                                 conthits = T, poly2.biphasic = TRUE)


        # Plot
        plot <- concRespPlot2(res, log_conc = TRUE)

        # Add flags
        res <- add_flags_acc(res)

        plot <- plot +
          ggtitle(paste0(chem, " ", endp)) +
          geom_ribbon(aes(ymin = 0,
                          ymax = row$cutoff),
                      fill = "grey",
                      alpha = 0.4) +
          geom_hline(
            aes(yintercept = row$cutoff, linetype = "cutoff"
            ),
            color = "grey"
          ) +
          geom_vline(
            aes(xintercept = log10(res$ac50), linetype = "AC50"), color = "blue"
          ) +
          labs(color = "Model & Metrics", linetype = NULL, fill = NULL
          ) +
          theme(axis.text = element_text(size = 18,
                                         colour = "black",
                                         #face = "bold"
          ),
                axis.title = element_text(size = 18,
                                          colour = "black",
                                          face = "bold"),
                plot.title = element_text(size = 20, face = "bold"),
                legend.title = element_text(size = 18,
                                            colour = "black", face = "bold"
                ),
                legend.text = element_text(size = 18),
                #legend.position = "none",
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

        library(cowplot)
        library(grid)
        legend <- get_legend(plot + theme(legend.position = "right"))

        format_num <- function(x) {
          if (is.na(x)) {
            return("")
          }
          if (abs(x) < 0.01) {
            formatC(x, format = "e", digits = 2)
          } else {
            formatC(x, format = "f", digits = 2)
          }
        }

        library(gridExtra)

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
        # summary_table <- tableGrob(
        #   table_data,
        #   rows = NULL,
        #   cols = NULL,
        #   theme = ttheme_default(core = list(fg_params = list(fontsize = 14)))
        # )
        #summary_table$widths <- grid::unit(rep(1, length(summary_table$widths)), "null")

        library(cowplot)

        legend_with_text <- ggdraw() +

          # legend at the top (40% of height)
          draw_plot(
            legend,
            x = 0,
            y = 0.55,      # bottom of legend starts at 55%
            width = 1,
            height = 0.40  # legend takes upper 40%
          ) +

          # table below the legend (55% of height)
          draw_plot(
            summary_table,
            x = 0,
            y = 0,
            width = 1,
            height = 0.55  # table takes middle 55%
          )

        # now combine with main plot
        plot_no_legend <- plot + theme(legend.position = "none")

        final_plot <- plot_grid(
          plot_no_legend,
          legend_with_text,
          ncol = 2,
          rel_widths = c(2, 1),
          align = "h",
          axis = "b"   # bottoms aligned
        )

        # print(final_plot)

        # save the plot and the dist_results
        if (unique(length(chem_data$var2)) == 1) {
          filename_curve <- paste0(gsub("-", "", Sys.Date()), "_", chem, "_", endp, "_C-R_curve_combinedExp")
        } else {
          filename_curve <- paste0(gsub("-", "", Sys.Date()), "_", chem, "_", endp, "_", add_var, "_C-R_curve_combinedExp")
        }
        filepath_curve <- file.path(pathToExp, "result_plots", "C-R_curves", filename_curve)

        if (!is.null(dev.list())) graphics.off()

        ggsave(plot = final_plot, file = paste0(filepath_curve, ".svg"), width = 7, height = 5)
        save(final_plot, res, file = paste0(filepath_curve, ".rda"))

        # save as pdf
        pdf(paste0(filepath_curve, ".pdf"), width = 7, height = 5)
        print(final_plot)
        dev.off()

        allVar2 <- bind_rows(allVar2, res)
      }
       all_endp_df <- bind_rows(all_endp_df, allVar2)
        all_endp_df <- all_endp_df %>%
          dplyr::select(-flag_vec)
    }
    # save the results of all endpoints and Var2
    filename_allEndpoints <- paste0(gsub("-", "", Sys.Date()), "_", chem, "_", exp_name, "_C-R_model_allSVendpoints")
    filepath_allEndpoints <- file.path(pathToExp, "result_files", "C-R_model", filename_allEndpoints)

    data.table::fwrite(all_endp_df, paste0(filepath_allEndpoints, ".csv"),
                       sep = ",")
    saveRDS(all_endp_df, file = paste0(filepath_allEndpoints, ".rds"))

    allChem <- bind_rows(allChem, all_endp_df)
  }
  # Save the tox metrics for all chemicals
  filename_allChemicals <- paste0(gsub("-", "", Sys.Date()), "_", paste(chemicals, collapse = "_"), "_", exp_name, "_C-R_model_allSVendpoints_allChemicals")
  filepath_allChemicals <- file.path(pathToExp, "result_files", "C-R_model", filename_allChemicals)
  saveRDS(allChem, file = paste0(filepath_allChemicals, ".rds"))
  data.table::fwrite(allChem, paste0(filepath_allChemicals, ".csv"),
                     sep = ",")

  return(allChem)
}

# helper function
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

#CRC_LM(pathToExp_low_conc = pathToExp_low_conc, pathToExp_high_conc = pathToExp_high_conc, pathToExp = pathToExp)
