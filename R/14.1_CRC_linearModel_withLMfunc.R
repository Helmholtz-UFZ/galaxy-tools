#' Fit linear model for single value endpoints
#'
#' Fits a linear model with `var1` as factor, saves the model and predictions,
#' and returns the fitted model. Intended for single value endpoints.
#'
#' @param data Data frame containing columns `value`, `var1`, `endpoint`, `chemical`, and `experiment`.
#' @param pathToExp Character string. Path to the experiment directory containing necessary subdirectories for input and output.
#'
#' @return The fitted `lm` model. Also writes model files and augmented data to `pathToExp/result_files/LM`.
#'
#' @export

# functions needed: loadData, data_pre-processing_singleValueEndp
LM <- function(data, pathToExp) {
  # Model1: LM
  lm_model <- lm(value ~ factor(var1), data = data)

  # save the model
  endpoint <- unique(data$endpoint)
  filename_lmModel <- file.path(pathToExp, "result_files", "LM",
                                paste0(gsub("-", "", Sys.Date()), "_",
                                       unique(data$chemical), "_", endpoint, "_", unique(data$experiment), "_model.rds"))
  saveRDS(lm_model, filename_lmModel)

  # save model summary
  filename_model_summary <- file.path(pathToExp, "result_files", "LM",
                                      paste0(gsub("-", "", Sys.Date()), "_",
                                             unique(data$chemical), "_", endpoint, "_", unique(data$experiment), "_LM_summary.txt"))
  sink(filename_model_summary)
  print(summary(lm_model))
  sink()


  # predict
  lm_pred <- predict(lm_model, newdata = data)

  data$prediction <- lm_pred
  data$model <- "LM"
  data$AIC <- AIC(lm_model)

  #data_metrics <- err_table(data)

  # save the data with predictions (data)
  filename_lm_df <- file.path(pathToExp, "result_files", "LM",
                              paste0(gsub("-", "", Sys.Date()), "_",
                                     unique(data$chemical), "_", endpoint, "_", unique(data$experiment), "_LM_DATA"))
  saveRDS(data, paste0(filename_lm_df, ".rds"))
  data.table::fwrite(x = data,
                     file = paste0(filename_lm_df, ".csv"),
                     sep = ",")

  return(lm_model)
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


CRC_LM_positives_newLegend <- function(pathToExp, unit_var1, exp_name) {

  all_data <- loadData(pathToExp = pathToExp)

  chemicals <- unique(all_data$chemical)
  allChem <- data.frame()
  for (chem in chemicals) {

    if (is.null(all_data$experiment)) {

      extract_core_plate <- function(plate_ID) {
        # Change this pattern according to your plate naming rules.
        sub("^([A-Z]+[0-9]+).*", "\\1", plate_ID)
      }

      all_data$core_plate <- extract_core_plate(all_data$plate_ID)
      plates <- unique(all_data$core_plate)
      all_data$experiment <- paste0(plates[[1]], "_", plates[[length(plates)]])
    }

    # data prep: pre-process values according to the requirements of the endpoints
    sv_data <- endp_prep_sv(data = all_data, exp_name = exp_name, pathToExp = pathToExp)

    # Fit the linear model
    endpoints <- unique(sv_data$endpoint)

    all_endp_df <- data.frame()

    for (endp in endpoints) {
      endpoint_table <- sv_data %>%
        filter(endpoint == endp)

      endpoint_table$value <- ifelse(endpoint_table$value < 1e-4, 1e-4, endpoint_table$value)

      # Split the tibble by "experiment" column
      split_tables <- split(endpoint_table, endpoint_table$experiment)

      models <- list()
      for (table in 1:length(split_tables)) {
        models[[table]] <- LM(data = split_tables[[table]], pathToExp = pathToExp)
      }

      estimates_all <- data.frame()
      for (lm_model in models) {
        # Get model coefficients
        coef_data <- data.frame(
          effect = abs(coef(lm_model)), # absolute effects
          se = sqrt(diag(vcov(lm_model)))
        )
        coef_clean <- subset(as.data.frame(coef_data), !is.na(effect))

        # Create estimates data frame
        rows_idx <- grep("^factor\\(var1\\)", rownames(coef_data))
        #rows_idx <- grep("^var1", rownames(coef_data))

        estimates <- data.frame(
          conc = as.numeric(gsub("factor\\(var1\\)", "", rownames(coef_data)[rows_idx])),
          #conc = as.numeric(gsub("var1", "", rownames(coef_data)[rows_idx])),
          eff = coef_data[rows_idx, "effect"],
          se = coef_data[rows_idx, "se"]
        )

        estimates_all <- bind_rows(estimates_all, estimates)
      }
      # Sort by concentration
      estimates_all <- estimates_all[order(estimates_all$conc),]

      # Calculate cutoff and standard deviation
      control_data <- endpoint_table %>%
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

      cutoff_types <- c(
        #"mad_all_controls",
        "mad_all_controls_splitByExp"
        # names(mad_per_experiment_vec)
      )
      cutoff_values <- c(
        #mad_all_controls,
        mad_all_controls_splitByExp
        #  mad_per_experiment_vec
      )
      sd_values <- c(
        # std_dev,
        sd_all_controls_splitByExp
        # sd_per_experiment_vec
      )

      cutoffs_df <- data.frame(
        type = cutoff_types,
        cutoff = cutoff_values,
        sd = sd_values,
        stringsAsFactors = FALSE
      )

      allMethods_df <- data.frame()
      for (i in seq_len(nrow(cutoffs_df))) {
        cutoff_type <- cutoffs_df$type[i]
        cutoff_value <- cutoffs_df$cutoff[i]
        sd_value <- cutoffs_df$sd[i]

        row = list(
          conc = as.numeric(estimates_all$conc),  # conc_df is plotdata without controls
          resp = estimates_all$eff,
          bmed = 0,
          cutoff = cutoff_value,
          onesd = sd_value,
          chemical = chem, endpoint = endp #, cutoff_method = cutoff_type
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
                          ymax = cutoff_value),
                      fill = "grey",
                      alpha = 0.4) +
          geom_hline(
            aes(yintercept = cutoff_value, linetype = "cutoff"
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
        filename_curve <- paste0(gsub("-", "", Sys.Date()), "_", chem, "_", endp, "_", cutoff_type, "_C-R_curve_combinedExp")
        filepath_curve <- file.path(pathToExp, "result_plots", "C-R_curves", filename_curve)

        if (!is.null(dev.list())) graphics.off()
        ggsave(plot = final_plot, filename = paste0(filepath_curve, ".svg"), width = 7, height = 5)
        #svg(paste0(filepath_curve, ".svg"), width = 7, height = 5)
        #print(final_plot)
        #dev.off()

        save(final_plot, file = paste0(filepath_curve, ".rda"))

        # save as pdf
        pdf(paste0(filepath_curve, ".pdf"), width = 7, height = 5)
        print(final_plot)
        dev.off()

        allMethods_df <- bind_rows(allMethods_df, res)
      }

      all_endp_df <- bind_rows(all_endp_df, allMethods_df)
      all_endp_df <- all_endp_df %>%
        dplyr::select(-flag_vec)

    }
    # save the results of all endpoints
    filename_allEndpoints <- paste0(gsub("-", "", Sys.Date()), "_", chem, "_", exp_name, "_C-R_model_allSVendpoints_combinedExp_splitbyExp")
    filepath_allEndpoints <- file.path(pathToExp, "result_files", "C-R_model", filename_allEndpoints)

    data.table::fwrite(all_endp_df, paste0(filepath_allEndpoints, ".csv"),
                       sep = ",")
    saveRDS(all_endp_df, file = paste0(filepath_allEndpoints, ".rds"))

    allChem <- bind_rows(allChem, all_endp_df)
  }

  # Save the tox metrics for all chemicals
  filename_allChemicals <- paste0(gsub("-", "", Sys.Date()), "_", paste(chemicals, collapse = "_"), "_", exp_name, "_C-R_model_allSVendpoints_combinedExp_allChemicals_splitbyExp")
  filepath_allChemicals <- file.path(pathToExp, "result_files", "C-R_model", filename_allChemicals)
  saveRDS(allChem, file = paste0(filepath_allChemicals, ".rds"))
  data.table::fwrite(allChem, paste0(filepath_allChemicals, ".csv"), sep = ",")

  return(allChem)
}

#CRC_LM(pathToExp_low_conc = pathToExp_low_conc, pathToExp_high_conc = pathToExp_high_conc, pathToExp = pathToExp)
