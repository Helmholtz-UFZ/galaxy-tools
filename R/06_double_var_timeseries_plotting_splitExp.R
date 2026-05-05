#' Function to plot the timeseries data
#'
#' This function creates timeseries plots showing behavioral parameters over time,
#' with endpoints and applied stimuli labeled. It processes data for each variable 1
#' (e.g., different concentrations) and creates separate plots per chemical and
#' experiment. The function uses median values with median absolute deviation (MAD)
#' for error representation.
#'
#' @param control_var1 Character/Numeric. Control value for var1
#' @param unit_var1 Character string. Unit of measurement for variable 1 (var1).
#'                  If var1 does not have a unit, unit_var1 = NA.
#' @param pathToExp Character string. Path to the experiment directory containing necessary subdirectories for input and output
#' @param exp_name Character string specifying the experiment name, used in input file naming
#' @param y_max Numeric value setting the maximum y-axis limit for the plots.
#'              Should be chosen based on the expected range of your behavioral parameter values.
#'
#'#' @details
#' The function expects several global objects to be available in the environment:
#' \itemize{
#'   \item \code{assay_data}: Data frame containing assay information with columns including 'colors' and 'divider_lines'
#'   \item \code{stimuli_info}: Data frame with stimulus information including columns 'end_s', 'endpoint', 'stimulus_name', 'stimulus_name2', 'stimulus_n'
#'   \item \code{stimuli_classes}: Data frame defining stimulus classes with associated colors
#'   \item \code{acoustic_stimuli}: Data frame containing acoustic stimulus timing and positioning
#'   \item \code{assay_data_whole_timeseries}: Data frame with complete timeseries assay information
#' }
#'
#' @export
#' @examples
#' \dontrun{
#' # Basic usage
#' doubleVar_timeseries_plotting_median(
#'   control_var1 = "0",
#'   unit_var1 = "\u00B5M",
#'   pathToExp = "/path/to/experiment",
#'   exp_name = "my_experiment",
#'   y_max = 10
#' )
#' }
#'
#' @seealso
#' \code{\link{ggplot2}} for plotting functions used internally


doubleVar_timeseries_plotting_median <- function(control_var1, #assay_data, stimuli_info, stimuli_classes, acoustic_stimuli, assay_data_whole_timeseries,
                                                 unit_var1, pathToExp, exp_name, y_max) {

  # avoid scientific notation
  options(scipen = 999)

  files <- list.files(file.path(pathToExp, "result_files"), full.names = TRUE, pattern = paste0("^\\d{8}_", exp_name, "_plotdata_timeseries\\.rda$")) # filename has 8 digits and plotdata_timesereis

  if (length(files) == 0) {
    stop("No matching timeseries data files found in the result_files directory.")
  }
  latest_plotdata_file <- files[which.max(as.Date(substr(basename(files), 1, 8), "%Y%m%d"))]

  outputlist <- load(latest_plotdata_file)
  outputlist <- get(outputlist)

  assay_data$colors <- as.factor(assay_data$colors)

  assays_dividers <- assay_data[assay_data$divider_lines == "yes",]

  # The errorbars overlapped, so use position_dodge to move them horizontally
  pd <- ggplot2::position_dodge(0.1) # move them .05 to the left and right

  # create a new folder for result_files per chemical and var1
  new_folder_name <- "timeseries_plot_df_per_var1"
  new_folder_path <- file.path(pathToExp, "result_files", new_folder_name)
  # dir.create(new_folder_path, recursive = TRUE)

  # plot per chemical
  for (chem in unique(outputlist$chemical)) {
    # extract info for respective chemical
    splitsub <- outputlist %>%
      dplyr::filter(chemical == chem)
    #print(splitsub)

    # create a list to save the dataframes per var1 for plotting
    plotting_list <- list()
    # plot per experiment
    for (exp in unique(splitsub$experiment)) {
      exp_df <- splitsub %>%
        dplyr::filter(experiment == exp)

      # plot per var1 (in this case: concentration)
      for (value in unique(exp_df$var1)) {
        #print(value)
        # extract info for respective value of var1
        var1_df <- exp_df %>%
          dplyr::filter(var1 == value)

        # add control data to the dataframe
        control_df <- exp_df %>%
          dplyr::filter(var1 == control_var1)
        if (value != control_var1) {
          var1_df <- rbind(control_df, var1_df)
        }

        # add columns from stimuli list to var1_df
        var1_df <- left_join(var1_df, stimuli_info[, c("end_s", "endpoint", "stimulus_name", "stimulus_name2", "stimulus_n")], by = c("time" = "end_s"))


        # determine the number of replicates and add them to the legend
        var1_df$legend_key <- as.factor(paste0(var1_df$var1, " ",
                                               " (n=",
                                               var1_df$n,
                                               ")"
        )
        )

        # Convert stimulus_name from factor to character and initialize stimuli_cleaned column
        var1_df_new <- var1_df %>%
          mutate(stimulus_name = as.character(stimulus_name)) %>%
          group_by(var2) %>%
          mutate(
            # Step 1: Combine stimulus_name and stimulus_name2
            combined_stimulus = case_when(
              row_number() == 1 ~ "",
              row_number() == 2 ~ "Stimulus",
              is.na(stimulus_name2) | trimws(stimulus_name2) == "" ~ stimulus_name,
              TRUE ~ paste(stimulus_name, stimulus_name2, sep = ", ")
            ),
            # Step 2: Split and alternate for multiple stimuli
            stimuli_cleaned = purrr::map2_chr(combined_stimulus, row_number(), function(stim, idx) {
              if (stim %in% c("", "Stimulus")) return(stim)

              entries <- str_split(stim, ", ")[[1]]
              if (length(entries) == 1) return(entries[1])

              # For multiple entries, alternate based on row position
              entry_idx <- ((idx - 3) %% length(entries)) + 1
              return(entries[entry_idx])
            })
          ) %>%
          ungroup()

        #var1_df_list <- var1_df_list.append(var1_df) # in case we want one rda file with all dataframes

        # add var1_df to plotting_list, to have all dfs per chemical listed for plotting
        key <- paste0(value, "_", exp)
        plotting_list[[key]] <- var1_df_new

        filename <- paste0(gsub("-", "", Sys.Date()), "_", exp, "_", value, ".csv")
        file_path <- file.path(new_folder_path, filename)
        filename2 <- paste0(gsub("-", "", Sys.Date()), "_", exp, "_", value, ".rda")
        file_path2 <- file.path(new_folder_path, filename2)
        #print(var1_df)

        data.table::fwrite(var1_df_new, file_path,
                           sep = ",")
        save(var1_df_new, file = file_path2)

        print(paste0(var1_df_new$chemical[1], ", ", value, " µM calculated and saved!"))

      }
    }


    lineplot_list <- list()
    pdf_files <- c()
    # plot every dataframe in plotting_list
    for (value in names(plotting_list)) {
      # plot specific concentration against control
      var1_df <- plotting_list[[value]]

      if (length(unique(splitsub$experiment)) > 1) {
        experiment_name <- unique(var1_df$experiment)
        legend_title <- paste0(unique(var1_df$chemical), " ", experiment_name,
                               " (", unit_var1, ")")
      } else {
        legend_title <- paste0(unique(var1_df$chemical), " (", unit_var1, ")")
      }

      # in case different var2 are applied, create separate plots for each var2 level
      # Get unique var2 values
      var2_levels <- unique(var1_df$var2)
      plot_list <- list()

      for (level in var2_levels) {
        # Filter data for this var2 level
        data_subset <- var1_df[var1_df$var2 == level,]

        # Get unique legend_key values for this subset only
        legend_keys_subset <- unique(data_subset$legend_key)

        # Create color scale for this subset
        if (length(unique(data_subset$var1)) == 1) {
          colorscale_subset <- "gray25"
        } else {
          colorscale_subset <- c("gray25", "red")
        }

        data_colors_subset <- data.frame(stimulus_class = legend_keys_subset,
                                         color = colorscale_subset[1:length(legend_keys_subset)],  # Fix indexing
                                         fill = colorscale_subset[1:length(legend_keys_subset)])   # Fix indexing

        # Combine with stimuli classes
        stimuli_classes_subset <- rbind(data_colors_subset, stimuli_classes)
        stimuli_classes_subset$stimulus_class <- factor(stimuli_classes_subset$stimulus_class,
                                                        levels = stimuli_classes_subset$stimulus_class)

        ## Filter background data for this level
        #acoustic_stimuli_level <- acoustic_stimuli_faceted[acoustic_stimuli_faceted$var2 == level,]
        #assay_data_level <- assay_data_faceted[assay_data_faceted$var2 == level,]
        #assays_dividers_level <- assays_dividers_faceted[assays_dividers_faceted$var2 == level,]

        length_colorscale_subset <- length(colorscale_subset)
        n_stimuli_classes <- nrow(stimuli_classes)

        n_levels <- length(var2_levels)
        plot_title <- if (n_levels > 1 && !is.null(level)) {
          paste("var2:", level)
        } else {
          NULL
        }

        # Create plot for this level
        plot_level <- ggplot(data_subset) +
          geom_tile(aes(x = time, y = median / 100,
                        color = stimuli_cleaned, fill = stimuli_cleaned),
                    alpha = 0.5) +
          geom_ribbon(aes(x = time,
                          ymin = (median - mad) / 100,
                          ymax = (median + mad) / 100,
                          fill = legend_key),
                      alpha = 0.2, show.legend = TRUE) +
          geom_line(aes(x = time, y = median / 100, color = legend_key),
                    linewidth = 0.5, alpha = 0.5, show.legend = FALSE) +
          labs(x = "",
               y = expression(Motor ~ activity ~ (10^2 ~ px / s)),
               color = legend_title, fill = legend_title,
               title = plot_title) +
          geom_segment(data = assays_dividers,
                       aes(x = start, xend = start, y = 0, yend = Inf),
                       linetype = 3, inherit.aes = FALSE, linewidth = 0.2) +
          geom_segment(data = assays_dividers,
                       aes(x = end, xend = end, y = 0, yend = Inf),
                       linetype = 3, inherit.aes = FALSE, linewidth = 0.2) +
          geom_rect(data = acoustic_stimuli,
                    aes(xmin = start, xmax = end,
                        ymin = y_pos, ymax = y_pos + height),
                    fill = acoustic_stimuli$fill,
                    color = acoustic_stimuli$color,
                    linewidth = 0.3, inherit.aes = FALSE, show.legend = FALSE) +
          geom_rect(data = assay_data_whole_timeseries,
                    aes(xmin = start, xmax = end,
                        ymin = y_pos - 0.45, ymax = y_pos + 0.45),
                    fill = assay_data_whole_timeseries$colors, color = "white",
                    linewidth = 0.15, inherit.aes = FALSE, show.legend = FALSE) +
          geom_text(data = assay_data_whole_timeseries,
                    aes(x = label_pos, y = y_pos,
                        label = gsub("\\\\n", " \n", assays)),
                    lineheight = 1, color = "black", size = 1.8, inherit.aes = FALSE) +
          scale_fill_manual(breaks = stimuli_classes_subset$stimulus_class,
                            #values = stimuli_classes_subset$color
                            values = setNames(stimuli_classes_subset$fill, stimuli_classes_subset$stimulus_class)) +
          scale_color_manual(breaks = stimuli_classes_subset$stimulus_class,
                             #values = stimuli_classes_subset$color
                             values = setNames(stimuli_classes_subset$color, stimuli_classes_subset$stimulus_class),
                             guide = "none"
          ) +
          #guides(fill = guide_legend(override.aes = list(
          #  color = stimuli_classes_subset$color,
          #  fill = stimuli_classes_subset$fill
          #))) +
          guides(fill = guide_legend(override.aes = list(
            alpha = c(rep(0.5, length(legend_keys_subset)), rep(NA, n_stimuli_classes)),
            linetype = c(rep(0, length(legend_keys_subset)), rep(1, n_stimuli_classes)),
            color = stimuli_classes_subset$color, linewidth = 0.2
          ))) +
          coord_cartesian(ylim = c(-5, y_max)) +
          scale_y_continuous(breaks = seq(0, y_max, by = 2)) +
          scale_x_continuous(expand = c(0, 0)) +
          theme_classic() +
          theme(
            legend.justification = c(1, 0.75),
            legend.key.size = unit(0.2, "cm"),
            legend.text = element_text(size = 4),
            legend.title = element_text(size = 4),
            axis.title.y = element_text(size = 5),
            axis.title.x = element_blank(),
            axis.text.x = element_blank(),
            axis.text.y = element_text(size = 5, color = "black"),
            axis.ticks = element_blank(),
            axis.ticks.x = element_blank(),
            axis.line.x = element_blank(),
            axis.line.y = element_blank(),
            plot.title = element_text(size = 5)
          )
        plot_list[[level]] <- plot_level
      }

      # Combine appropriately based on number of levels
      if (length(var2_levels) > 1) {
        library(patchwork)
        combined_plot <- wrap_plots(plot_list, ncol = 1)
      } else {
        # If only one level, just use the single plot
        combined_plot <- plot_list[[1]]
      }

      # Use combined_plot for saving/displaying
      lineplot <- combined_plot
      #print(lineplot)

      # Save the plot in a list
      # key <- paste0(value, "_", exp)
      lineplot_list[[value]] <- lineplot

      filename <- paste0(gsub("-", "", Sys.Date()), "_", var1_df$chemical[1], "_", value, "MAD_VAMR_timeseries")
      full_path <- file.path(pathToExp, "result_plots", "timeseries", filename)

      # # Get var1 for creating a filename for the plots
      # if (length(unique(var1_df$var1)) == 1) {
      #   var1 <- control_var1
      # } else {
      #   var1 <- var1_df[var1_df$var1 != control_var1,]
      #   var1 <- unique(var1$var1)
      # }
      result_dir <- file.path(pathToExp, "result_plots", "timeseries")
      if (!dir.exists(result_dir)) {
        dir.create(result_dir)
      }

      filename <- paste0(gsub("-", "", Sys.Date()), "_", value, "_MAD_VAMR_timeseries")
      # filename <- paste0(gsub("-", "", Sys.Date()), "_", var1_df$chemical[1], "_", var1, "MAD_VAMR_timeseries")
      full_path <- file.path(result_dir, filename)

      # Set height depending on the number of facets
      height <- 1.25 + 0.75 * (length(var2_levels) - 1) * 1.25
      ggsave(filename = paste0(full_path, ".svg"), plot = lineplot, device = "svg", width = 6.25, height = height)

      save(lineplot, file = paste0(full_path, ".rda"))

      ## 3) NEW: individual 6.25 x 1.25 inch PDF
      #single_pdf_path <- paste0(full_path, ".pdf")
      #grDevices::pdf(single_pdf_path, width = 6.25, height = 1.25)
      #print(lineplot)
      #dev.off()
    }
  }
}
