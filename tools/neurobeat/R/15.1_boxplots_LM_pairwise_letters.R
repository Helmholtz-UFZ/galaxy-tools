#' Boxplots with pairwise significance letters (experimental)
#'
#' Generates violin/boxplots per endpoint and chemical, fits linear models,
#' and annotates groups using compact letter displays from Tukey post hoc tests.
#' Supports multiple experiments by fitting an interaction of `experiment * var1`.
#'
#' Note: This function relies on several global objects and helper functions
#' already being available in the environment and is considered experimental.
#' Prefer `boxplots_LM()` for the stable workflow.
#'
#' @param pathToExp Character. Path to the experiment folder containing inputs and outputs.
#' @param exp_name Character. Experiment name used for labeling and output paths.
#' @param unit_var1 Character. Unit label for var1 (e.g., "\u00B5M").
#'
#' @details
#' Required context and globals:
#' - `loadData()` and `endp_prep_sv()` are expected to be available (see package utils).
#' - `assay_data` and `conc_data` should be loaded via aesthetics helpers.
#' - `pathToChems` needs to point to a CSV providing per-chemical colors.
#'
#' This function saves model summaries and plots to the experiment's result folders.
#'
#' @return No return value. Creates output files as a side effect.
#'
#' @examples
#' \dontrun{
#' boxplots_LM_pairwise(
#'   pathToExp = "/path/to/experiment",
#'   exp_name = "my_experiment",
#'   unit_var1 = "\u00B5M"
#' )
#' }
#'
#' @seealso \code{boxplots_LM}
#' @keywords internal

#function to generate the significance labels (based on Tukey post hoc test)
generate_label_df <- function(variable) {
  # Extract labels and factor levels from Tukey post-hoc
  Tukey_levels <- variable
  # generate letters for groups in post-hoc test to identify the groups that are significantly different
  Tukey_labels <- data.frame(multcompLetters(Tukey_levels)['Letters'])
  # put the labels in the same order as in the boxplot
  Tukey_labels$treatment <- rownames(Tukey_labels)
  Tukey_labels[order(Tukey_labels$treatment),]
}

boxplots_LM_pairwise <- function(pathToExp, exp_name, unit_var1) {
  options(scipen = 999)
  all_data <- loadData(pathToExp = pathToExp)

  for (chem in unique(all_data$chemical)) {
    chem_data <- all_data %>%
      dplyr::filter(chemical == chem)


    chem_color_file <- file.path(pathToChems, "20251120_VAMR4_chemicals_colors.csv")
    chem_colors <- as.data.frame(data.table::fread(chem_color_file, check.names = FALSE))
    #chem_color <- chem_colors %>%
    #  filter(chemical == unique(chem_data$chemical)) %>%
    #  pull(color)

    rename_map <- c(
      "DPH" = "5,5-Diphenylhydantoin",
      "SodiumBenzoate" = "Sodium benzoate",
      "TriethyltinBromide" = "Triethyltin bromide"
    )
    chem_name <- rename_map[chem]
    chem_name <- ifelse(is.na(chem_name), chem, chem_name)

    chem_color <- chem_colors %>%
      filter(chemical == chem_name) %>%
      pull(color)

    # get separate tables by chemicals, as plotting will be done per chemical
    aes_data <- conc_data %>%
      dplyr::filter(chemical == chem) %>%
      dplyr::mutate(color = ifelse(var1 != 0, chem_color, "grey"))

    ## Factor setting helper
    set_factor_levels <- function(df, col, ref) {
      df[[col]] <- factor(df[[col]], levels = unique(ref))
      df
    }

    # make sure there is an experiment column
    if (is.null(chem_data$experiment)) {

      extract_core_plate <- function(plate_ID) {
        # Change this pattern according to your plate naming rules.
        sub("^([A-Z]+[0-9]+).*", "\\1", plate_ID)
      }

      chem_data$core_plate <- extract_core_plate(chem_data$plate_ID)
      plates <- unique(chem_data$core_plate)
      chem_data$experiment <- paste0(plates[[1]], "_", plates[[length(plates)]])
    }

    # data prep: pre-process values according to the requirements of the endpoints
    sv_data <- endp_prep_sv(data = chem_data)

    #sv_data$var1 <- as.numeric(as.character(sv_data$var1))
    ## set the factor order according to the aesthetic data input to ensure correct order in the plot
    sv_data$var1 <- factor(sv_data$var1, levels = aes_data$var1)
    #sv_data <- set_factor_levels(sv_data, "endpoint", assay_data$assays)
    #sv_data$animalID <- factor(sv_data$animalID)
    #sv_data <- set_factor_levels(sv_data, "var2", aes_data$var2)
    #sv_data <- set_factor_levels(sv_data, "var3", aes_data$var3)


    # Fit the linear model
    endpoints <- unique(sv_data$endpoint)

    all_endp_df <- data.frame()

    sv_data <- sv_data %>%
      mutate(endpoint = ifelse(endpoint == "ASR_2_3", "ASR2/3", endpoint),
             endpoint = ifelse(endpoint == "ASH_1_5", "ASH1/5", endpoint))

    #filtered_assays <- assay_data %>%
    #  dplyr::filter(assays %in% unique(sv_data$endpoint))
    #color_vector <- setNames(filtered_assays$colors, filtered_assays$assays)

    #strip_bg_list <- lapply(color_vector, function(clr) element_rect(fill = clr))
    ## Set the names! (should match your endpoint levels)
    #names(strip_bg_list) <- names(color_vector)

    letter_list <- list()
    for (endp in endpoints) {
      endpoint_table <- sv_data %>%
        filter(endpoint == endp)

      endpoint_table <- endpoint_table %>%
        mutate(endpoint = ifelse(endpoint == "ASR_2_3", "ASR2/3", endpoint),
               endpoint = ifelse(endpoint == "ASH_1_5", "ASH1/5", endpoint))

      endp_color <- assay_data$colors[assay_data$assays == endp]
      header_color <- element_rect(fill = endp_color)

      endpoint_table$value <- ifelse(endpoint_table$value < 1e-4, 1e-4, endpoint_table$value)

      # Split the tibble by "experiment" column
      split_tables <- split(endpoint_table, endpoint_table$experiment)

      modellist <- data.frame()
      #plotdata <- data.frame()
      # for (exp in unique(endpoint_table$experiment)) {
      #  exp_df <- endpoint_table %>%
      #    dplyr::filter(experiment == exp)

      endpoint_table$experiment <- factor(endpoint_table$experiment)
      # modellist[[table]] <- LM(data = split_tables[[table]], pathToExp = pathToExp)
      # lm_model <- lm(value ~ factor(var1), data = exp_df)

      #endpoint_table$group <- interaction(endpoint_table$experiment, endpoint_table$var1)
      #lm_model <- lm(value ~ group, data = endpoint_table)

      if (length(unique(endpoint_table$experiment)) > 1) {
        lm_model <- lm(value ~ experiment * var1, data = endpoint_table)
        #lm_model <- lm(value ~ experiment + var1 + var1:experiment, data = endpoint_table)

        # 2) Concentrations that exist in both experiments
        shared_conc <- endpoint_table %>%
          dplyr::group_by(var1) %>%
          dplyr::summarise(n_exp = dplyr::n_distinct(experiment), .groups = "drop") %>%
          dplyr::filter(n_exp > 1) %>%
          dplyr::pull(var1)

        # 3) Pooled emmeans over experiments, only for shared concentrations
        if (length(shared_conc) >= 2) {
          emm_shared <- emmeans(
            lm_model,
            ~var1,
            at = list(var1 = shared_conc)
          )
          # 4) Pairwise comparisons among those pooled concentrations
          posthoc_shared <- pairs(emm_shared, adjust = "tukey")
        } else {
          emm_shared <- NULL
          posthoc_shared <- NULL
          message("No shared concentrations across experiments → no pooled pairwise comparisons.")
        }
        posthoc_shared <- as.data.frame(posthoc_shared)

        emm_within <- emmeans(lm_model, pairwise ~ var1 | experiment, adjust = "tukey")
        posthoc_within <- emm_within$contrasts
        posthoc_clean <- subset(as.data.frame(posthoc_within), !is.na(estimate))
        posthoc_all <- bind_rows(posthoc_shared, posthoc_clean)

      } else {
        lm_model <- lm(value ~ var1, data = endpoint_table)
        # EMMs
        # Add the contrasts
        posthocraw <- emmeans::emmeans(lm_model, pairwise ~ var1, adjust = "tukey"
                                       #, pbkrtest.limit = 4767
        )
        posthoc <- summary(posthocraw)
        posthoc_all <- posthoc$contrasts
      }

      # save the model
      filename_lmModel <- file.path(pathToExp, "result_files", "LM",
                                    paste0(gsub("-", "", Sys.Date()), "_",
                                           chem, "_", endp, "_model_lm_ext.rds"))
      saveRDS(lm_model, filename_lmModel)

      # save model summary
      filename_model_summary <- file.path(pathToExp, "result_files", "LM",
                                          paste0(gsub("-", "", Sys.Date()), "_",
                                                 chem, "_", endp, "_LM_summary_lm_ext.txt"))
      sink(filename_model_summary)
      print(summary(lm_model))
      sink()

      # predict
      lm_pred <- predict(lm_model, newdata = endpoint_table)

      endpoint_table$prediction_1 <- lm_pred
      endpoint_table$model <- "LM"
      endpoint_table$AIC_1 <- AIC(lm_model)

      #exp_df$prediction <- lm_pred
      #exp_df$model <- "LM"
      #exp_df$AIC <- AIC(lm_model)

      #plotdata <- bind_rows(plotdata, endpoint_table)

      # EMMs
      # Add the contrasts
      # posthocraw <- emmeans::emmeans(lm_model, pairwise ~ var1, adjust = "tukey"
      #                                #, pbkrtest.limit = 4767
      #                                )

      ## summary used because it returns a df
      #posthoc <- summary(posthocraw)

      ## select only the first six columns of the pairwise comparisons
      #posthoc <- posthoc$contrasts[, 1:6]
      #posthoc$contrast <- gsub("\\(", "", posthoc$contrast)
      #posthoc$contrast <- gsub("\\)", "", posthoc$contrast)

      ## pairwise comp mod #####
      #contrastsplit <- strsplit(posthoc[, 1], " - ")

      ##converting the output list to a data frame
      #contrastdata <- as.data.frame(do.call("rbind", contrastsplit))
      #modellist <- bind_rows(modellist, cbind(contrastdata, posthoc))

      modellist <- posthoc_all
      # Save modellist
      file_name_modellist <- paste0(gsub("-", "", Sys.Date()), "_",
                                    chem, "_", endp, "_modellist_lm_ext.txt")
      saveRDS(modellist, file.path(pathToExp, "result_files", "LM", file_name_modellist))


      # save the data with predictions (data)
      filename_lm_df <- file.path(pathToExp, "result_files", "LM",
                                  paste0(gsub("-", "", Sys.Date()), "_",
                                         chem, "_", endp, "_LM_DATA_lm_ext"))
      saveRDS(endpoint_table, paste0(filename_lm_df, ".rds"))
      data.table::fwrite(x = endpoint_table,
                         file = paste0(filename_lm_df, ".csv"),
                         sep = ",")
      #}

      # Set y_min, y_max by endpoint (use left_join for vectorization)
      #phase_limits <- assay_data[, c("assays", "boxplot_y_min", "boxplot_y_max")]
      #colnames(phase_limits) <- c("endpoint", "y_min", "y_max")
      #plotdata <- merge(plotdata, phase_limits, by = "endpoint", all.x = TRUE)


      # summarize animals per group
      binned_data <- endpoint_table %>%
        #  binned_data <- plotdata %>%
        dplyr::group_by(var1, var2, experiment) %>%
        dplyr::summarize(n = dplyr::n_distinct(animalID), .groups = 'drop')

      if (length(unique(binned_data$var2) == 1)) {
        new_name <- paste0("c (", unit_var1, ")")

        binned_data <- binned_data %>%
          select(-var2) %>%
          rename(!!new_name := var1)

        #binned_data <- binned_data %>%
        #  dplyr::select(-var2) %>%
        #  rename("c (µM)" = var1)
      }

      #filtered_assays <- assay_data %>%
      #  dplyr::filter(assays %in% unique(endpoint_table$endpoint))
      #color_vector <- setNames(filtered_assays$colors, filtered_assays$assays)

      leg.unit <- gsub("uM", "\U03BCM", unique(aes_data$unit))

      if (leg.unit == "nounit") {

        leg.title <- unique(endpoint_table$chemical)

      } else {

        leg.title <- paste0(unique(endpoint_table$chemical),
                            " (", leg.unit, ")")
      }

      library(grid)
      library(gridExtra)

      # delete the whitespaces before and after "-". This is crucial, because
      # multcompLetters() needs this format to work properly
      modellist$contrast <- gsub(" - ", "-", modellist$contrast)

      # create a named vector of the p-values. This is important because
      # multcompLetters needs this info to match the values to the right concs
      posthoc2 <- setNames(modellist$p.value, modellist$contrast)

      # Format all columns to avoid scientific notation
      library(stringr)

      # fix_sci_inside <- function(x, digits = 6) {
      #   str_replace_all(
      #     x,
      #      "(?<!var)[0-9]*\\.?[0-9]+[eE]-?[0-9]+",
      #    # "[0-9]*\\.?[0-9]+[eE]-?[0-9]+",   # findet z.B. 19e-04, 1e-3, 3.5e+02
      #     function(m) {
      #       format(
      #         as.numeric(m),
      #         scientific = FALSE,
      #         digits = digits,
      #         trim = TRUE
      #       )
      #     }
      #   )
      # }

      # names(posthoc2) <- fix_sci_inside(names(posthoc2), digits = 6)

      # generate a df with the letters
      labels <- generate_label_df(posthoc2)

      names(labels) <- c("Letters", "var1")

      #set y-value accroding to the facets so the letter is placed under the graph.
      # there are 4 assay phases, custom axes will be set for the the first two
      # and for the second two

      endpoint_name <- unique(endpoint_table$endpoint)
      yvalue <- assay_data$letter_pos[assay_data$assays == endpoint_name]

      final <- merge(labels, yvalue)

      final$endpoint <- endpoint_name


      final$var1 <- sub("\\s[^ ]+$", "", final$var1)
      # necessary fix as emmeans > v1.7.0 adds a "conc" prefix
      final$var1 <- sub("var1", "", final$var1)

      print(final)
      letter_list[[endp]] <- final

      # generate and store single endpoint plots
      # Only for the endpoints needed (for other endpoints boxplot_y_min is NA)
      if (!is.na(assay_data$boxplot_y_min[assay_data$assays == endpoint_name]) && assay_data$boxplot_y_min[assay_data$assays == endpoint_name] != "") {

        y_min <- assay_data$boxplot_y_min[assay_data$assays == endpoint_name] }


      if (y_min < 0) {
        # wenn y_min (aus assay_data table) kliener 0 -> y-Achse soll bei 0 beginnne
        y_min_break <- 0

      } else {
        # wenn y_min aus assay:data table bie was posititivem beginnt, soll auch y-Achse da beginnen
        y_min_break <- y_min
      }

      y_max <- assay_data$boxplot_y_max[assay_data$assays == endpoint_name]

      y_interval <- assay_data$boxplot_y_interval[assay_data$assays == endpoint_name]

      #y_axis_title <- expression(paste("Motor activity (px/s)"))
      #y_axis_title <- ifelse(endp == "ASH1", "Habituation index", y_axis_title)

      y_axis_title <- if (endp == "ASH1") {
        "Habituation index"
      } else if (endp == "ASH1/5") {
        "Potentiation of habituation"
      } else if (endp == "ASR2/3") {
        "Retention index"
      } else if (grepl("ASR", endp, ignore.case = TRUE)) {
        expression(paste("Average motor activity (", Delta, "px/s)"))
      } else if (grepl("VSR", endp, ignore.case = TRUE)) {
        expression(paste("Motor activity (", Delta, "px/s)"))
      }else {
        expression(paste("Summed motor activity (", Delta, "px/s)"))
      }


      colscale <- setNames(aes_data$color,
                           aes_data$var1)

      # necessary to bind box- and violin plots to the same positions
      dodge <- position_dodge(width = 0.9)


      #vsrsub <- plotdata[plotdata$endpoint == endp]

      median_ctrl <- endpoint_table %>%
        # median_ctrl <- plotdata %>%
        dplyr::filter(var1 == 0) %>%
        summarize(median = median(value)) %>%
        pull(median)

      #strip_bg_list <- lapply(color_vector, function(clr) element_rect(fill = clr))
      ## Set the names! (should match your endpoint levels)
      #names(strip_bg_list) <- names(color_vector)

      #header_color <- strip_bg_list[[endpoint_name]]

      singleplot <- ggplot(endpoint_table,
                           #plotdata,
                           aes(x = factor(var1),
                               y = value,
                               fill = var1)
      ) +
        #facet_wrap2(~as.character(endpoint_name),
        #            strip = strip_themed(
        #              background_x = header_color
        #            )
        #) +
        ggh4x::facet_wrap2(
          ~endpoint,
          strip = ggh4x::strip_themed(
            background_x = header_color
          )
        ) +
        #facet_wrap(
        #  ~endpoint,
        #  strip = strip_themed(background_x = header_color)
        #) +
        geom_violin(trim = F,
                    linewidth = 0.3,
                    alpha = .5,
                    bounds = c(0, Inf)
                    #              position = dodge
        ) +
        geom_hline(aes(yintercept = median_ctrl),
                   linetype = "dotted",
                   linewidth = 1,
                   color = "grey"
        ) +
        geom_boxplot(width = 0.2
                     #              position = dodge
        ) +
        labs(
          x = leg.title,
          y = y_axis_title,
          fill = leg.title
          #chemicals[chem]
        ) +
        scale_y_continuous(limits = c(y_min, y_max),
                           breaks = seq(y_min_break, y_max,
                                        by = y_interval)) +
        #  scale_y_continuous(limits = c(-1000, 80000)) +
        scale_fill_manual( #labels = leg.key,
          #values = var1) +
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
          #legend.position = "right",
          #legend.key.spacing.y = unit(0.5, "cm"),
          #legend.title = element_text(size = 14,
          #                            colour = "black",
          #                            face = "bold"),
          #legend.text = element_text(size = 14,
          #                           face = "bold"),
          strip.text.x = element_text(size = 18,
                                      face = "bold"),
          panel.background = element_rect(fill = NA,
                                          color = "black"
                                          # linewidth = 1
          )
        )


      # add the generated letters to the plot
      singleplot <- singleplot + geom_text(data = letter_list[[endp]],
                                           aes(x = var1,
                                               y = y,
                                               label = Letters),
                                           #fontface = "bold",
                                           colour = "black",
                                           position = dodge,
                                           size = 7)

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
      # combined_plot <- gridExtra::grid.arrange(
      #   singleplot_noleg,
      #   #table_with_title,
      #   binned_tbl,
      #   ncol = 2,
      #   widths = c(3, 1)    # tweak relative widths
      # )

      print(singleplot)

      chem <- gsub(" ", "_", chem)
      file_name_singleplot <- paste0(gsub("-", "", Sys.Date()),
                                     "_single_plot_", chem, "_", endp)
      path_singleplot <- file.path(pathToExp, "result_plots", "phase_boxplots", file_name_singleplot)
      #pdf(paste0(path_singleplot, ".pdf"),
      #    width = 10,
      #    height = 10)
      #print(singleplot)
      #dev.off()

      svg(paste0(path_singleplot, ".svg"),
          width = 15,
          height = 5)
      print(singleplot)
      dev.off()

      # save singleplot without legend
      svg(paste0(path_singleplot, "_noLegend.svg"),
          width = 12,
          height = 5)
      print(singleplot_noleg)
      dev.off()

      pdf(paste0(path_singleplot, "_noLegend.pdf"),
          width = 12,
          height = 5)
      print(singleplot_noleg)
      dev.off()

      saveRDS(singleplot, file = paste0(path_singleplot, ".rds"))
    }

    file_name_table <- paste0(gsub("-", "", Sys.Date()),
                              "_", chem, "_legend_table")
    path_table <- file.path(pathToExp, "result_plots", "phase_boxplots", file_name_table)

    # Save one legend table separately
    svg(paste0(path_table, ".svg"),
        width = 2,
        height = 4)
    grid.draw(binned_tbl)
    dev.off()

    pdf(paste0(path_table, ".pdf"),
        width = 2,
        height = 4)
    grid.draw(binned_tbl)
    dev.off()
  }
}
