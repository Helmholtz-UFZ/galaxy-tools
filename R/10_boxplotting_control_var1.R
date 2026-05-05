#' Phase boxplot plotting (split experiments)
#'
#' Calculates and plots violin/boxplots for phase data per chemical and
#' experiment, and performs pairwise comparisons using fitted models.
#'
#' @param phase_name Character string used in output filenames to identify the
#'   endpoint set (e.g., "BSL1_VMR5" or "PhaseSums").
#' @param y_axis_title Character string for the y axis title.
#' @param pathToExp Character string. Path to the experiment directory containing necessary subdirectories for input and output.
#' @param unit_var1 Character string. Unit of measurement for variable 1 (var1). If var1 does not have a unit, unit_var1 = NA.
#' @param var1_def Character string. Definition of the first variable that appears in the table next to the violin plot (e.g., if var1 is concentration, var1_def could be 'c', so that it appears as column name in the table as c('unit')).
#' @param conc_data Data frame that assigns colors to the groups of var1, var2, and experiment for each chemical.
#' @param control_var1 Character/Numeric. Control value for var1
#'
#' @return No return value. Writes plots and statistical summaries to `pathToExp/result_plots/phase_boxplots` and `pathToExp/result_files/gam`.
#'
#' @examples
#' \dontrun{
#' phase_boxplot_plotting_split_exp(
#'   phase_name = "BSL1_VMR5",
#'   y_axis_title = "Summed distance moved (px/min)",
#'   pathToExp = "/path/to/experiment",
#'   unit_var1 = "\u00B5M",
#'   var1_def = "c",
#'   conc_data = conc_data
#' )
#' }
#'
#' @export


phase_boxplot_plotting_split_exp <- function(phase_name,
                                             y_axis_title,
                                             pathToExp,
                                             unit_var1,
                                             var1_def,
                                             conc_data,
                                             control_var1) {

  # avoid scientific notation
  options(scipen = 999)

  # load the data
  modeldata_files <- list.files(file.path(pathToExp, "result_files", "gam"),
                                full.names = TRUE,
                                pattern = paste0(phase_name, "_predictions_plotdata_beta_all.*\\.rds"))

  modeldata_file <- get_latest_file(modeldata_files)
  data <- readRDS(modeldata_file)

  experiments <- unique(data$experiment)

  chemicals <- unique(data$chemical)

  for (chem in chemicals) {
    aes_data <- conc_data %>%
      dplyr::filter(chemical == chem)

    plotdata <- data %>%
      ungroup() %>%
      dplyr::filter(chemical == chem)

    plotdata$var1 <- factor(plotdata$var1, levels = levels(aes_data$var1))
    plotdata$var2 <- factor(plotdata$var2, levels = levels(aes_data$var2))

    save_chem <- gsub(" ", "_", chem)
    save_chem <- gsub(",", "_", save_chem)

    p_values_allExp <- data.frame()
    for (exp in experiments) {
      # load the model
      model_files <- list.files(file.path(pathToExp, "result_files", "gam"),
                                full.names = TRUE,
                                pattern = paste0(chem, "_", exp, "_", phase_name, "_gamm_beta\\.rds"))

      model <- readRDS(get_latest_file(model_files))
      model_summary <- summary(model)

      # Now conduct the contrasts
      if (length(unique(plotdata$var2)) > 1) {
        if (length(unique(plotdata$endpoint)) > 1) {
          emms <- emmeans::emmeans(model, ~var1 | endpoint + var2)
        } else {
          emms <- emmeans::emmeans(model, ~var1 | var2)
        }
      } else {
        if (length(unique(plotdata$endpoint)) > 1) {
          emms <- emmeans::emmeans(model, ~var1 | endpoint)
        } else {
          emms <- emmeans::emmeans(model, ~var1)
        }
      }

      #emms <- emmeans(model, ~var1 | endpoint)
      contr <- emmeans::contrast(emms, method = "trt.vs.ctrl", ref = 1)

      contr_tbl <- summary(contr)
      emms_sum <- summary(emms)

      ### Create an output dataframe containing the model summary and emmeans and contrasts summary
      out_df <- data.frame(capture.output(print(model_summary)))
      colnames(out_df) <- "OUTPUT_MODEL_EMMEANS_CONTRASTS"

      # Insert empty row before emmeans part and before conrasts
      empty = matrix(c(rep.int(NA, length(out_df))), nrow = 1, ncol = length(out_df))
      colnames(empty) = colnames(out_df)

      # Save the contrast table  # Save emmeans
      emm_out <- data.frame(capture.output(print(emms_sum)))
      colnames(emm_out) <- "OUTPUT_MODEL_EMMEANS_CONTRASTS"

      contr_out <- data.frame(capture.output(print(contr_tbl)))
      colnames(contr_out) <- "OUTPUT_MODEL_EMMEANS_CONTRASTS"

      final_output <- rbind(out_df, emm_out, contr_out)

      data.table::fwrite(x = final_output,
                         file = file.path(pathToExp, "result_files", "gam", paste0(gsub("-", "", Sys.Date()), "_", chem, "_", exp, "_", phase_name, "_model_summary_gam.csv")),
                         sep = ",")
      # Save emmeans
      filename_emmContr <- file.path(pathToExp, "result_files", "gam", paste0(gsub("-", "", Sys.Date()), "_", chem, "_", exp, "_", phase_name, "_emmeansContrasts_GAMM"))
      saveRDS(contr, file = paste0(filename_emmContr, ".rds"))
      #sink(file = paste0(filename_emmContr, ".txt"))
      #print(summary(contr))
      #sink()
      #data.table::fwrite(x = contr, file = paste0(filename_emmContr, ".txt"), sep = ", ")

      contr_tbl$experiment <- exp

      p_values_allExp <- bind_rows(p_values_allExp, contr_tbl)
    }

    ## Make a var1 column in the contrasts table
    x <- p_values_allExp$contrast

    # 1) Left side only
    left <- sub(" - .*", "", x)

    # 2) Remove parentheses
    left <- gsub("[()]", "", left)

    # 3) Remove 'var1' prefix
    p_values_allExp$var1 <- sub("^var1", "", left)

    p_values_allExp$var1 <- factor(p_values_allExp$var1, levels = levels(aes_data$var1))

    if (var1_def == "c") {
      # 4) Numeric + pretty formatting
      p_values_allExp$var1_num <- as.numeric(as.character(p_values_allExp$var1))

      pretty_var1 <- function(x) {
        sapply(x, function(val) {
          if (val < 0.001 & val != 0) {
            # Scientific notation for values < 0.001
            s <- sprintf("%.10e", val)
            s <- sub("0+e", "e", s)          # remove trailing zeros before 'e'
            s <- sub("\\.e", "e", s)          # remove trailing decimal point
            sub("e([+-])0+", "e\\1", s)      # remove leading zeros in exponent
          } else {
            # For other values remove trailing zeros
            s <- sprintf("%.10f", val)
            s <- sub("0+$", "", s)           # remove trailing zeros
            sub("\\.$", "", s)               # remove trailing decimal point
          }
        })
      }

      p_values_allExp <- p_values_allExp %>%
        dplyr::mutate(pretty_var1 = pretty_var1(var1_num)) %>%
        dplyr::arrange(var1_num)

    }
    #p_values_allExp$pretty_var1 <- pretty_var1(p_values_allExp$var1_num)

    # Create violin plots per endpoint
    for (endp in unique(plotdata$endpoint)) {
      endpoint_table <- plotdata %>%
        dplyr::filter(endpoint == endp)

      pval_table <- p_values_allExp
      # if we only have one endpoint, the contrast table doesn't have an endpoint column
      if (is.null(pval_table$endpoint)) {
        pval_table$endpoint <- endp
      } else {
        pval_table <- pval_table %>%
          dplyr::filter(endpoint == endp)
      }

      endp_color <- assay_data$colors[assay_data$assays == endp]
      header_color <- element_rect(fill = endp_color)

      if (var1_def == "c") {
        # order violins needed in ascending var1
        endpoint_table$var1_num <- as.numeric(as.character(endpoint_table$var1))

        exp_order <- endpoint_table %>%
          group_by(experiment) %>%
          summarise(min_conc = min(var1_num[var1_num > 0], na.rm = TRUE)) %>%
          arrange(min_conc) %>%
          pull(experiment)

        endpoint_table_ordered <- endpoint_table %>%
          mutate(experiment = factor(experiment, levels = exp_order)) %>%
          group_by(experiment) %>%
          arrange(var1_num, .by_group = TRUE)

        endpoint_table_ordered$pretty_var1 <- pretty_var1(endpoint_table_ordered$var1_num)

        # Insert a column for the combination of experiment and var1 and var2 if needed
        if (length(unique(endpoint_table_ordered$var2)) > 1) {
          endpoint_table_ordered$violins_needed <- factor(paste0(endpoint_table_ordered$pretty_var1, "_", endpoint_table_ordered$experiment, "_", endpoint_table_ordered$var2),
                                                          levels = unique(paste0(endpoint_table_ordered$pretty_var1, "_", endpoint_table_ordered$experiment, "_", endpoint_table_ordered$var2)))
          pval_table$violins_needed <- factor(paste0(pval_table$pretty_var1, "_", pval_table$experiment, "_", pval_table$var2),
                                              levels = unique(endpoint_table_ordered$violins_needed))
        } else {
          endpoint_table_ordered$violins_needed <- factor(paste0(endpoint_table_ordered$pretty_var1, "_", endpoint_table_ordered$experiment),
                                                          levels = unique(paste0(endpoint_table_ordered$pretty_var1, "_", endpoint_table_ordered$experiment)))
          pval_table$violins_needed <- factor(paste0(pval_table$pretty_var1, "_", pval_table$experiment),
                                              levels = unique(endpoint_table_ordered$violins_needed))
        }
      } else {
        endpoint_table$experiment <- as.character(endpoint_table$experiment)
        if (length(unique(endpoint_table_ordered$var2)) > 1) {
          endpoint_table_ordered$violins_needed <- factor(paste0(endpoint_table_ordered$var1, "_", endpoint_table_ordered$experiment, "_", endpoint_table_ordered$var2),
                                                          levels = unique(paste0(endpoint_table_ordered$var1, "_", endpoint_table_ordered$experiment, "_", endpoint_table_ordered$var2)))
          pval_table$violins_needed <- factor(paste0(p_values_allExp$var1, "_", p_values_allExp$experiment, "_", p_values_allExp$var2),
                                              levels = unique(endpoint_table_ordered$violins_needed))
        } else {
          endpoint_table_ordered$violins_needed <- factor(paste0(p_values_allExp$var1, "_", p_values_allExp$experiment),
                                                          levels = unique(paste0(endpoint_table_ordered$var1, "_", endpoint_table_ordered$experiment)))
          pval_table$violins_needed <- factor(paste0(p_values_allExp$var1, "_", p_values_allExp$experiment),
                                              levels = unique(endpoint_table_ordered$violins_needed))

        }
      }
      #endpoint_table_ordered$violins_needed <- factor(endpoint_table_ordered$violins_needed, levels = unique(endpoint_table_ordered$violins_needed))

      # Save contrast list
      file_name_modellist <- paste0(gsub("-", "", Sys.Date()), "_",
                                    save_chem, "_", endp, "_contrasts_gamm_pValues_plateID_randomEff.rds")
      saveRDS(pval_table, file.path(pathToExp, "result_files", "gam", file_name_modellist))


      x_start_end <- data.frame()
      for (add_var in unique(endpoint_table_ordered$var2)) {
        endp_tbl_var2 <- endpoint_table_ordered %>%
          dplyr::filter(var2 == add_var)

        #x_start <- grep("^0_", x = unique(endp_tbl_var2$violins_needed))

        x_uniq <- as.character(unique(endp_tbl_var2$violins_needed))
        ctrl_token <- if (exists("pretty_var1") && "pretty_var1" %in% ls()) {
          # if violins_needed uses pretty_var1(var1_num)
          paste0(pretty_var1(as.numeric(control_var1)), "_")
        } else {
          paste0(as.character(control_var1), "_")
        }
        x_start <- which(startsWith(x_uniq, ctrl_token))
        if (length(x_start) == 0) next
        names(x_start) <- x_uniq[x_start]
        start_df <- data.frame(
          start = names(x_start),
          position = x_start,
          experiment = gsub("^[^_]*_([^_]*)(?:_.*)?$", "\\1", names(x_start), perl
            = TRUE)
        )
        start_df$var2 <- rep(add_var, nrow(start_df))

        
        #x_uniq <- unique(endp_tbl_var2$violins_needed)
        #ctrl_str <- pretty_var1(as.numeric(control_var1))
        #x_start <- which(startsWith(as.character(x_uniq), paste0(ctrl_str, "_")))
        #names(x_start) <- unique(endp_tbl_var2$violins_needed)[x_start]
        #start_df <- data.frame(start = names(x_start), position = x_start,
        #                       experiment = gsub(pattern = "^[^_]*_([^_]*)(?:_.*)?$", replacement = "\\1", x = names(x_start), perl = TRUE))
        #start_df$var2 <- add_var


        start_df <- start_df %>%
          dplyr::mutate(end_idx = lead(position) - 1) %>%
          dplyr::mutate(
            end = ifelse(!is.na(end_idx),
                         as.character(unique(endp_tbl_var2$violins_needed)[end_idx]),
                         as.character(last(unique(endp_tbl_var2$violins_needed))))
          ) %>%
          dplyr::select(-c(position, end_idx))

        x_start_end <- bind_rows(x_start_end, start_df)
      }

      # Create the table that is shown on the right side of the plot showing the n for each group
      # summarize animals per group
      binned_data <- endpoint_table_ordered %>%
        #  binned_data <- plotdata %>%
        dplyr::group_by(violins_needed, var1, var2, experiment) %>%
        dplyr::summarize(n = dplyr::n_distinct(animalID), .groups = 'drop')

      # column name for var1 (e.g. concentration with its assigned unit in parentheses)
      if (is.null(unit_var1)) {
        new_name <- paste(var1_def)
        leg_title <- chem
      } else {
        new_name <- paste0(var1_def, "(", unit_var1, ")")
        leg_title <- paste0(chem, " (", unit_var1, ")")
      }


      # Add the new column name
      binned_data <- binned_data %>%
        dplyr::select(-violins_needed) %>%
        dplyr::rename(!!new_name := var1)

      # Delete var2 column if there is only one unique var2
      if (length(unique(binned_data$var2)) == 1) {
        binned_data <- binned_data %>%
          dplyr::select(-var2)
      }
      if (length(unique(binned_data$experiment)) == 1) {
        binned_data <- binned_data %>%
          dplyr::select(-experiment)
      }


      #legend key assembly
      leg_key <- paste0("n=", binned_data$n)

      library(grid)
      library(gridExtra)


      #set y-value accroding to the facets so the letter is placed under the graph.
      # there are 4 assay phases, custom axes will be set for the the first two
      # and for the second two

      yvalue <- assay_data$letter_pos[assay_data$assays == endp]

      final <- merge(pval_table, yvalue)

      final$endpoint <- endp

      print(final)

      # generate and store single endpoint plots
      # Only for the endpoints needed (for other endpoints boxplot_y_min is NA)
      if (!is.na(assay_data$boxplot_y_min[assay_data$assays == endp]) && assay_data$boxplot_y_min[assay_data$assays == endp] != "") {
        y_min <- assay_data$boxplot_y_min[assay_data$assays == endp] }
      if (y_min < 0) {
        # wenn y_min (aus assay_data table) kliener 0 -> y-Achse soll bei 0 beginnne
        y_min_break <- 0
      } else {
        # wenn y_min aus assay:data table bie was posititivem beginnt, soll auch y-Achse da beginnen
        y_min_break <- y_min
      }

      y_max <- assay_data$boxplot_y_max[assay_data$assays == endp]
      y_interval <- assay_data$boxplot_y_interval[assay_data$assays == endp]

      aes_data$pretty_var1 <- pretty_var1(aes_data$var1_numeric)
      if (length(unique(aes_data$var2)) > 1) {
        colscale <- setNames(aes_data$color,
                             paste0(aes_data$pretty_var1, "_", aes_data$experiment, "_", aes_data$var2))
      } else {
        colscale <- setNames(aes_data$color,
                             paste0(aes_data$pretty_var1, "_", aes_data$experiment))
      }

      # necessary to bind box- and violin plots to the same positions
      dodge <- position_dodge(width = 0.9)

      median_ctrl_exp <- endpoint_table_ordered %>%
        dplyr::group_by(violins_needed, experiment, var2) %>%
        dplyr::filter(var1 == 0) %>%
        dplyr::summarize(ctrl_median = median(sums))

      x_start_end <- merge(median_ctrl_exp, x_start_end, by = c("experiment", "var2"))

      lab_df <- dplyr::distinct(endpoint_table_ordered, violins_needed, pretty_var1)
      x_labs <- setNames(lab_df$pretty_var1, lab_df$violins_needed)


      final$label_base <- ifelse(
        final$p.value < 0.001,
        "<0.001",
        sprintf("%.3f", final$p.value)
      )

      # colour & transparency depending on significance
      final$label_color <- ifelse(
        final$p.value > 0.05,
        "grey50",      # non-significant
        "black"        # significant
      )

      if (length(unique(endpoint_table_ordered$var2)) > 1) {
        # Create the violin plots
        singleplot <- ggplot(endpoint_table_ordered,
                             aes(x = violins_needed,
                                 y = sums,
                                 fill = violins_needed)
        ) +
          facet_wrap(
            endpoint ~ var2,
            scales = "free_x"
            #strip = ggh4x::strip_themed(
            #  #background_x = header_color
            #  background_x = ggh4x::elem_list_rect(fill = header_color)
            #)
          ) +
          geom_violin(trim = F,
                      linewidth = 0.3,
                      alpha = .5,
                      bounds = c(0, Inf)
          ) +
          geom_segment(data = x_start_end,
                       aes(x = start,
                           xend = end,
                           y = ctrl_median,
                           yend = ctrl_median),
                       linetype = "dotted",
                       linewidth = 1,
                       color = "grey",
                       inherit.aes = FALSE) +
          geom_boxplot(width = 0.2
          ) +
          labs(
            x = leg_title,
            y = y_axis_title,
            fill = leg_title
          ) +
          scale_x_discrete(labels = x_labs) +
          scale_y_continuous(limits = c(y_min, y_max),
                             breaks = seq(y_min_break, y_max,
                                          by = y_interval)) +
          scale_fill_manual(labels = leg_key,
                            values = colscale) +
          theme_classic() +
          guides(fill = guide_legend(
            # ncol = 1,
            byrow = T)
          ) +
          theme(
            axis.ticks.length = unit(0.1, "cm"),
            axis.text = element_text(size = 17,
                                     colour = "black"
            ),
            axis.title.x = element_text(size = 18,
                                        margin = margin(t = 10),
                                        colour = "black" #, face = "bold"
            ),
            axis.title.y = element_text(size = 18,
                                        colour = "black" #, face = "bold"
            ),
            plot.title = element_text(face = "bold"),
            legend.position = "right",
            legend.title = element_text(size = 14,
                                        colour = "black",
            ),
            legend.text = element_text(size = 14,
            ),
            strip.text.x = element_text(size = 18,
                                        face = "bold"),
            strip.background = element_rect(fill = header_color$fill),
            panel.background = element_rect(fill = NA,
                                            color = "black"
            )
          )
      } else {
        # Create the violin plots
        singleplot <- ggplot(endpoint_table_ordered,
                             #plotdata,
                             aes(x = violins_needed,
                                 #x = pretty_var1,
                                 y = sums,
                                 #fill = var1
                                 fill = violins_needed)
        ) +
          ggh4x::facet_wrap2(
            ~endpoint #,
            #strip = ggh4x::strip_themed(
            #  background_x = header_color
            #)
          ) +
          geom_violin(trim = F,
                      linewidth = 0.3,
                      alpha = .5,
                      bounds = c(0, Inf)
                      #              position = dodge
          ) +
          geom_segment(data = x_start_end,
                       aes(x = start,
                           xend = end,
                           y = ctrl_median,
                           yend = ctrl_median),
                       linetype = "dotted",
                       linewidth = 1,
                       color = "grey",
                       inherit.aes = FALSE) +
          geom_boxplot(width = 0.2
                       #              position = dodge
          ) +
          labs(
            x = leg_title,
            y = y_axis_title,
            fill = leg_title
          ) +
          scale_x_discrete(labels = x_labs) +
          #scale_x_discrete(labels = function(x) sub("_.*", "", x)) +
          scale_y_continuous(limits = c(y_min, y_max),
                             breaks = seq(y_min_break, y_max,
                                          by = y_interval)) +
          scale_fill_manual(labels = leg_key,
                            #values = violins_needed) +
                            values = colscale) +
          theme_classic() +
          guides(fill = guide_legend(
            ncol = 1,
            byrow = T)
          ) +
          theme(
            #axis.line = element_line(linewidth = 1),
            #axis.ticks = element_line(linewidth = 1),
            axis.ticks.length = unit(0.1, "cm"),
            #axis.ticks.x = element_blank(),
            axis.text = element_text(size = 17,
                                     colour = "black",
                                     # face = "bold"
            ),
            #axis.text.x = element_blank(),
            axis.title.x = element_text(size = 18,
                                        margin = margin(t = 10),
                                        colour = "black" #, face = "bold"
            ),
            axis.title.y = element_text(size = 18,
                                        colour = "black" #, face = "bold"
            ),
            plot.title = element_text(face = "bold"),
            legend.position = "right",
            #legend.key.spacing.y = unit(0.5, "cm"),
            legend.title = element_text(size = 14,
                                        colour = "black",
                                        #                            face = "bold"
            ),
            legend.text = element_text(size = 14,
                                       #                           face = "bold"
            ),
            strip.text.x = element_text(size = 18,
                                        face = "bold"),
            strip.background = element_rect(fill = header_color$fill),
            panel.background = element_rect(fill = NA,
                                            color = "black"
                                            # linewidth = 1
            )
          )
      }

      # add the generated letters to the plot
      singleplot <- singleplot +
        geom_text(data = final,
                  aes(x = violins_needed,
                      #x = pretty_var1,
                      y = y,
                      label = label_base,
                      colour = label_color),
                  #fontface = "bold",
                  position = dodge,
                  size = 5) +
        scale_color_identity()


      # Save plot with legend as rds and svg
      file_name_singleplot <- paste0(gsub("-", "", Sys.Date()),
                                     "_single_plot_", save_chem, "_", endp)
      path_singleplot <- file.path(pathToExp, "result_plots", "phase_boxplots", file_name_singleplot)

      saveRDS(singleplot, file = paste0(path_singleplot, ".rds"))

      # Set the width of the plot depending on how many experiments and var2 are shown
      standard_width <- 12
      width <- standard_width + 1 / 2 * length(unique(endpoint_table_ordered$violins_needed))

      ggsave(filename = paste0(path_singleplot, ".svg"),
             plot = singleplot,
             width = width, # 18 for split exp
             height = 6)


      # Add table as legend next to the plot
      library(cowplot)
      binned_tbl <- gridExtra::tableGrob(binned_data, rows = NULL)
      singleplot_noleg <- singleplot + theme(legend.position = "none")

      singleplot <- plot_grid(
        singleplot_noleg,
        binned_tbl,
        ncol = 2,
        rel_widths = c(6, 1),
        align = "h",
        axis = "b"   # bottoms aligned
      )

      # Save plot with table
      ggsave(filename = paste0(path_singleplot, "_legend_table.svg"),
             plot = singleplot,
             width = width, # 18 for split exp
             height = 6)

      # save singleplot without legend
      ggsave(filename = paste0(path_singleplot, "_noLegend.svg"),
             plot = singleplot_noleg,
             width = width - 3, # 15 for split exp
             height = 6)

      ggsave(filename = paste0(path_singleplot, "_noLegend.pdf"),
             plot = singleplot_noleg,
             width = width - 3, # 15 for split exp
             height = 6)

      # Save the binned_tbl at the end
      if (endp == "VMR5") {
        file_name_table <- paste0(gsub("-", "", Sys.Date()),
                                  "_", save_chem, "_legend_table")
        path_table <- file.path(pathToExp, "result_plots", "phase_boxplots", file_name_table)

        tbl_width <- ncol(binned_data)
        tbl_height <- 5 + 0.2 * nrow(binned_data)

        # Save one legend table separately
        svg(paste0(path_table, ".svg"),
            width = tbl_width,
            height = tbl_height)
        grid.draw(binned_tbl)
        dev.off()

        pdf(paste0(path_singleplot, "_noLegend.pdf"),
            width = width - 3,
            height = 6)
        print(singleplot_noleg)
        dev.off()

        saveRDS(singleplot, file = paste0(path_singleplot, ".rds"))

      }
    }
  }

}
