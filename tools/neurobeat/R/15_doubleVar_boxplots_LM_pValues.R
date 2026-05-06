#' Generate Boxplots with Linear Model Analysis
#'
#' This function creates violin/boxplots with statistical analysis using linear models
#' for experimental data. It processes chemical exposure data, fits linear models,
#' performs statistical contrasts, and generates publication-ready plots with
#' significance annotations.
#'
#' @param pathToExp Character string. Path to the experiment directory containing
#'   the data files and where results will be saved.
#' @param unit_var1 Character string. Unit of measurement for variable 1 (var1).
#'   If var1 does not have a unit, unit_var1 = NA.
#' @param exp_name Character string. Name of the experiment used for data
#'   preprocessing and file naming.
#' @param var1_def Character string. Definition of the first variable that appears
#'   in the table next to the violin plot (e.g., if var1 is concentration,
#'   var1_def could be 'c', so that it appears as column name in the table as c('unit')).
#' @param conc_data File metadata file that assigns colors to the groups of var1, var2, experiment
#' @param control_var1 Character/Numeric. Control value for var1
#'
#' @return This function does not return a value. It generates and saves:
#'   \itemize{
#'     \item Statistical model summaries (CSV files)
#'     \item Individual endpoint plots (SVG and PDF formats)
#'   }
#'
#' @details
#' The function performs the following operations:
#' \enumerate{
#'   \item Loads experimental data using \code{loadData()}
#'   \item Processes data for each chemical separately
#'   \item Creates experiment groupings from plate IDs if not present
#'   \item Preprocesses data using \code{endp_prep_sv()}
#'   \item For each endpoint:
#'     \itemize{
#'       \item Fits linear models or loads existing models
#'       \item Performs emmeans analysis and contrasts
#'       \item Generates statistical summaries
#'       \item Creates violin/boxplots with significance annotations
#'       \item Saves plots in multiple formats
#'     }
#'   \item Handles multiple experiments and variables (var2) when present
#'   \item Generates custom y-axis scaling based on assay-specific parameters
#'   \item Creates legend tables showing sample sizes per group
#' }
#'
#' @section File Structure:
#' The function expects and creates the following directory structure:
#' \itemize{
#'   \item \code{pathToExp/result_files/LM/} - Linear model results and summaries
#'   \item \code{pathToExp/result_plots/phase_boxplots/} - Generated plots
#' }
#'
#' @section Dependencies:
#' Required packages: dplyr, ggplot2, emmeans, data.table, grid, gridExtra,
#' cowplot, ggh4x
#'
#' @section Global Variables:
#' The function relies on several global objects that must be defined:
#' \itemize{
#'   \item \code{conc_data} - Concentration/aesthetic data for plotting
#'   \item \code{assay_data} - Assay-specific parameters (colors, axis limits, etc.)
#'   \item \code{var1_def} - Definition/name of the first variable
#' }
#'
#' @examples
#' \dontrun{
#' # Basic usage
#' boxplots_LM(
#'   pathToExp = "/path/to/experiment",
#'   unit_var1 = "\u00B5M",
#'   exp_name = "chemical_exposure_study"
#' )
#' }
#'
#' @seealso
#' \code{\link{loadData}}, \code{\link{endp_prep_sv}}, \code{\link{LM}}
#'
#' @export

boxplots_LM <- function(pathToExp, unit_var1, exp_name, var1_def, conc_data, control_var1) {
  options(scipen = 999)
  all_data <- loadData(pathToExp = pathToExp)

  for (chem in unique(all_data$chemical)) {

    chem_data <- all_data %>%
      dplyr::filter(chemical == chem)

    # get separate tables by chemicals, as plotting will be done per chemical
    aes_data <- conc_data %>%
      dplyr::filter(chemical == chem)
    #dplyr::mutate(color = ifelse(var1 != 0, chem_color, "grey"))

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
    sv_data <- endp_prep_sv(data = chem_data, exp_name = exp_name, pathToExp = pathToExp)

    ## set the factor order according to the aesthetic data input to ensure correct order in the plot
    sv_data$var1 <- factor(sv_data$var1, levels = levels(aes_data$var1))
    sv_data$var2 <- factor(sv_data$var2, levels = levels(aes_data$var2))

    #sv_data <- set_factor_levels(sv_data, "endpoint", assay_data$assays)
    #sv_data$animalID <- factor(sv_data$animalID)
    #sv_data <- set_factor_levels(sv_data, "var2", aes_data$var2)
    #sv_data <- set_factor_levels(sv_data, "var3", aes_data$var3)


    # Fit the linear model
    endpoints <- unique(sv_data$endpoint)


    for (endp in endpoints) {
      endpoint_table <- sv_data %>%
        dplyr::filter(endpoint == endp) %>%
        dplyr::mutate(endpoint = ifelse(endpoint == "ASR_2_3", "ASR2/3", endpoint),
                      endpoint = ifelse(endpoint == "ASH_1_5", "ASH1/5", endpoint))

      endp_name <- unique(endpoint_table$endpoint)

      endp_color <- assay_data$colors[assay_data$assays == endp_name]
      header_color <- element_rect(fill = endp_color)

      endpoint_table$value <- ifelse(endpoint_table$value < 1e-4, 1e-4, endpoint_table$value)

      endpoint_table$experiment <- factor(endpoint_table$experiment)

      experiments <- unique(endpoint_table$experiment)

      #if (length(experiments) > 1) {

      p_values_allExp <- data.frame()
      endp_data_allExp <- data.frame()
      for (exp in experiments) {
        # Load the fitted data
        exp_regex <- gsub("([0-9]+)", "\\1[A-Z]?", exp) # needed if experiment is taken from plate_ID and therefore has a letter attached to its experiment name
        if (length(experiments) > 1) {
          endpoint_file <- list.files(path = file.path(pathToExp, "result_files", "LM"),
                                      pattern = paste0(endp, "_", exp_regex, "_LM_DATA\\.rds"),
                                      full.names = TRUE, recursive = FALSE)
        } else {
          endpoint_file <- list.files(path = file.path(pathToExp, "result_files", "LM"),
                                      pattern = paste0(endp, ".*_LM_DATA\\.rds"),
                                      full.names = TRUE, recursive = FALSE)
        }

        # if there are no LM data files yet, fit the
        if (length(endpoint_file) != 0) {
          endp_data <- get_latest_file(endpoint_file)
          endpoint_data <- readRDS(endp_data)
          endpoint_data$experiment <- ifelse(is.null(endpoint_data$experiment), exp, endpoint_data$experiment)

          # get the model
          if (length(experiments) > 1) {
            model_files <- list.files(path = file.path(pathToExp, "result_files", "LM"),
                                      pattern = paste0(endp, "_", exp_regex, "_model\\.rds"),
                                      full.names = TRUE, recursive = FALSE)
          } else {
            model_files <- list.files(path = file.path(pathToExp, "result_files", "LM"),
                                      pattern = paste0(endp, ".*_model\\.rds"),
                                      full.names = TRUE, recursive = FALSE)
          }

          model_file <- get_latest_file(model_files)
          lm_model <- readRDS(model_file)

        } else {
          # Fit the LM
          exp_table <- endpoint_table %>%
            dplyr::filter(experiment == exp)

          output_list <- lm_func(data = exp_table, pathToExp = pathToExp)

          lm_model <- output_list[[1]]
          endpoint_data <- output_list[[2]]
          endpoint_data$experiment <- ifelse(is.null(endpoint_data$experiment), exp, endpoint_data$experiment)
        }

        model_summary <- summary(lm_model)

        # Now conduct the contrasts
        if (length(unique(all_data$var2)) > 1) {
          emms <- emmeans::emmeans(lm_model, ~var1 | var2)
        } else {
          emms <- emmeans::emmeans(lm_model, ~var1)
        }
        #emms <- emmeans(lm_model, ~var1)
        contr <- emmeans::contrast(emms, method = "trt.vs.ctrl", ref = 1)

        contr_tbl <- summary(contr)
        emms_sum <- summary(emms)

        ### Create an output dataframe containing the model summary and emmeans and contrasts summary
        out_df <- data.frame(capture.output(print(model_summary)))
        header_out <- colnames(out_df)
        colnames(out_df) <- "OUTPUT_MODEL_EMMEANS_CONTRASTS"
        header_df <- data.frame("OUTPUT_MODEL_EMMEANS_CONTRASTS" = c(" ", header_out))

        # Insert empty row before emmeans part and before conrasts
        empty = matrix(c(rep.int(NA, length(out_df))), nrow = 1, ncol = length(out_df))
        colnames(empty) = colnames(out_df)

        # Save the contrast table  # Save emmeans
        emm_out <- data.frame(capture.output(print(emms_sum)))
        header_emm <- colnames(emm_out)
        colnames(emm_out) <- "OUTPUT_MODEL_EMMEANS_CONTRASTS"
        header_emm <- data.frame("OUTPUT_MODEL_EMMEANS_CONTRASTS" = header_emm)
        header_emm <- rbind(empty, header_emm)

        contr_out <- data.frame(capture.output(print(contr_tbl)))
        header_contr <- colnames(contr_out)
        colnames(contr_out) <- "OUTPUT_MODEL_EMMEANS_CONTRASTS"
        header_contr <- data.frame("OUTPUT_MODEL_EMMEANS_CONTRASTS" = header_contr)
        header_contr <- rbind(empty, header_contr)

        final_endp_output <- rbind(header_df, out_df, header_emm, emm_out, header_contr, contr_out)

        data.table::fwrite(x = final_endp_output,
                           file = file.path(pathToExp, "result_files", "LM", paste0(gsub("-", "", Sys.Date()), "_", chem, "_", exp, "_", endp, "_model_summary_LM.csv")),
                           sep = ",")
        # Save emmeans
        filename_emmContr <- file.path(pathToExp, "result_files", "LM", paste0(gsub("-", "", Sys.Date()), "_", chem, "_", exp, "_", endp, "_emmeansContrasts_LM"))
        saveRDS(contr, file = paste0(filename_emmContr, ".rds"))

        contr_tbl$experiment <- exp
        p_values_allExp <- bind_rows(p_values_allExp, contr_tbl)
      }

      # Extract var1, thtat was compared to the control from the contrasts
      x <- p_values_allExp$contrast

      # 1) Left side only
      left <- sub(" - .*", "", x)

      # 2) Remove parentheses
      left <- gsub("[()]", "", left)

      # 3) Remove 'var1' prefix
      p_values_allExp$var1 <- sub("^var1", "", left)

      if (var1_def == "c") {
        # 4) Numeric + pretty formatting
        p_values_allExp$var1_num <- as.numeric(p_values_allExp$var1)

        pretty_var1 <- function(x) {
          # 1) format as fixed decimal with "enough" digits
          s <- formatC(x, format = "f", digits = 7)
          # 2) drop trailing zeros
          s <- sub("0+$", "", s)
          # 3) drop a trailing decimal point if left over
          s <- sub("\\.$", "", s)
          s
        }


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


        #p_values_allExp$pretty_var1 <- pretty_var1(p_values_allExp$var1_num)
        p_values_allExp <- p_values_allExp %>%
          dplyr::mutate(pretty_var1 = pretty_var1(var1_num)) %>%
          dplyr::arrange(var1_num)

        # order violins needed in ascending var1 (therefore ordering experiment as well in ascending var1
        endpoint_table$var1_num <- as.numeric(as.character(endpoint_table$var1))
        endpoint_table$experiment <- as.character(endpoint_table$experiment)

        exp_order <- endpoint_table %>%
          dplyr::group_by(experiment) %>%
          dplyr::summarise(min_conc = min(var1_num[var1_num > 0], na.rm = TRUE)) %>%
          dplyr::arrange(min_conc) %>%
          pull(experiment)

        endpoint_table_ordered <- endpoint_table %>%
          dplyr::mutate(experiment = factor(experiment, levels = exp_order)) %>%
          dplyr::group_by(experiment) %>%
          dplyr::arrange(var1_num, .by_group = TRUE)

        endpoint_table_ordered$pretty_var1 <- pretty_var1(endpoint_table_ordered$var1_num)

        # Insert a column for the combination of experiment and var1 and var2 if needed
        if (length(unique(endpoint_table_ordered$var2)) > 1) {
          endpoint_table_ordered$violins_needed <- factor(paste0(endpoint_table_ordered$pretty_var1, "_", endpoint_table_ordered$experiment, "_", endpoint_table_ordered$var2),
                                                          levels = unique(paste0(endpoint_table_ordered$pretty_var1, "_", endpoint_table_ordered$experiment, "_", endpoint_table_ordered$var2)))
          p_values_allExp$violins_needed <- factor(paste0(p_values_allExp$pretty_var1, "_", p_values_allExp$experiment, "_", p_values_allExp$var2),
                                                   levels = unique(endpoint_table_ordered$violins_needed))
        } else {
          endpoint_table_ordered$violins_needed <- factor(paste0(endpoint_table_ordered$pretty_var1, "_", endpoint_table_ordered$experiment),
                                                          levels = unique(paste0(endpoint_table_ordered$pretty_var1, "_", endpoint_table_ordered$experiment)))
          p_values_allExp$violins_needed <- factor(paste0(p_values_allExp$pretty_var1, "_", p_values_allExp$experiment),
                                                   levels = unique(endpoint_table_ordered$violins_needed))
        }
      } else {
        if (length(unique(endpoint_table_ordered$var2)) > 1) {
          endpoint_table_ordered$violins_needed <- factor(paste0(endpoint_table_ordered$var1, "_", endpoint_table_ordered$experiment, "_", endpoint_table_ordered$var2),
                                                          levels = unique(paste0(endpoint_table_ordered$var1, "_", endpoint_table_ordered$experiment, "_", endpoint_table_ordered$var2)))
          p_values_allExp$violins_needed <- factor(paste0(p_values_allExp$var1, "_", p_values_allExp$experiment, "_", p_values_allExp$var2),
                                                   levels = unique(endpoint_table_ordered$violins_needed))
        } else {
          endpoint_table_ordered$violins_needed <- factor(paste0(p_values_allExp$var1, "_", p_values_allExp$experiment),
                                                          levels = unique(paste0(endpoint_table_ordered$var1, "_", endpoint_table_ordered$experiment)))
          p_values_allExp$violins_needed <- factor(paste0(p_values_allExp$var1, "_", p_values_allExp$experiment),
                                                   levels = unique(endpoint_table_ordered$violins_needed))

        }
      }

      save_chem <- gsub(pattern = " ", replacement = "_", x = chem)
      save_chem <- gsub(pattern = ",", replacement = "_", x = save_chem)

      # Save contrast list
      file_name_modellist <- paste0(gsub("-", "", Sys.Date()), "_",
                                    save_chem, "_", endp, "_contrasts_lm_pValues.rds")
      saveRDS(p_values_allExp, file.path(pathToExp, "result_files", "LM", file_name_modellist))

      x_start_end <- data.frame()
      for (add_var in unique(endpoint_table_ordered$var2)) {
        endp_tbl_var2 <- endpoint_table_ordered %>%
          dplyr::filter(var2 == add_var)

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


        #x_start <- grep("^0_", x = unique(endp_tbl_var2$violins_needed))
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

      yvalue <- assay_data$letter_pos[assay_data$assays == endp_name]

      final <- merge(p_values_allExp, yvalue)

      final$endpoint <- endp_name

      #print(final)

      # generate and store single endpoint plots
      # Only for the endpoints needed (for other endpoints boxplot_y_min is NA)
      if (!is.na(assay_data$boxplot_y_min[assay_data$assays == endp_name]) && assay_data$boxplot_y_min[assay_data$assays == endp_name] != "") {
        y_min <- assay_data$boxplot_y_min[assay_data$assays == endp_name]
      } else {
        error("y_min can not be extracted as either boxplot_y_min column is missing in the assay_data file or endp ", endp_name,
              "\n Check your aesthic_files folder for 'assay_phases_indiv.csv' and ensure it has the columns boxplot_y_min, boxplot_y_max and boxplot_y_interval")
      }
      if (y_min < 0) {
        # wenn y_min (aus assay_data table) kliener 0 -> y-Achse soll bei 0 beginnne
        y_min_break <- 0
      } else {
        # wenn y_min aus assay:data table bie was posititivem beginnt, soll auch y-Achse da beginnen
        y_min_break <- y_min
      }

      y_max <- assay_data$boxplot_y_max[assay_data$assays == endp_name]
      y_interval <- assay_data$boxplot_y_interval[assay_data$assays == endp_name]

      y_axis_title <- if (endp_name == "ASH1") {
        "Habituation index"
      } else if (endp_name == "ASH1/5") {
        "Potentiation of habituation"
      } else if (endp_name == "ASR2/3") {
        "Memory retention index"
      } else if (grepl("ASR", endp_name, ignore.case = TRUE)) {
        expression(paste("Mean motor activity (px/s)"))
      } else if (grepl("VSR", endp_name, ignore.case = TRUE)) {
        expression(paste("Motor activity (px/s)"))
      }else {
        expression(paste("Total motor activity (px)"))
      }

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
        dplyr::summarise(ctrl_median = median(value))

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
                                 y = value,
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
          #scale_x_discrete(labels = function(x) sub("_.*", "", x)) +
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
                                     colour = "black",
                                     # face = "bold"
            ),
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
            strip.background = element_rect(fill = header_color$fill),
            panel.background = element_rect(fill = NA,
                                            color = "black"
            )
          )
      } else {
        # Create the violin plots
        singleplot <- ggplot(endpoint_table_ordered,
                             aes(x = violins_needed,
                                 y = value,
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
                      y = y,
                      label = label_base,
                      colour = label_color),
                  #fontface = "bold",
                  position = dodge,
                  size = 5) +
        scale_color_identity()

      # Save the plot with legend
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

      # print(singleplot)

      ## Save plot with table
      #ggsave(filename = paste0(path_singleplot, "_legend_table.svg"),
      #       plot = singleplot,
      #       width = width, # 18 for split exp
      #       height = 6)

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
      if (endp == "ASHsum") {
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

        pdf(paste0(path_table, ".pdf"),
            width = 3,
            height = 5)
        grid.draw(binned_tbl)
        dev.off()
      }
    }
  }
}
