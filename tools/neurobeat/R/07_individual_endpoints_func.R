#' Plot timeseries for individual endpoints
#'
#' Creates timeseries plots per endpoint, chemical, and experiment using median
#' values and MAD as error. Optionally groups endpoints and generates
#' habituation plots (e.g., ASH1 vs stimulus number).
#'
#' @param control_var1 Control value for `var1` used to include the control series in plots.
#' @param unit_var1 Character string. Unit of measurement for variable 1 (var1). If var1 has no unit, set `unit_var1 = NA`.
#' @param endp_groups Named list of endpoint groups to plot together, e.g. list(group1 = c("BSL1","BSL2"), group2 = c("VMR1","VMR2")).
#' @param habituation_assay_list Character vector of assays for which to generate habituation plots (e.g., `c("ASH1")`).
#' @param reference_pos Numeric y-position for drawing acoustic stimuli reference lines/boxes.
#' @param exp_name Character string specifying the experiment name, used in input and output file naming.
#' @param pathToExp Character string. Path to the experiment directory containing necessary subdirectories for input and output.
#'
#' @details
#' Required global objects loaded via aesthetics: `assay_data`, `acoustic_stimuli`,
#' and `stimuli_classes`.
#'
#' @examples
#' \dontrun{
#' individual_endpoints_plotting(
#'   control_var1 = 0,
#'   unit_var1 = "\u00B5M",
#'   endp_groups = list(group1 = c("BSL1","BSL2")),
#'   habituation_assay_list = c("ASH1"),
#'   reference_pos = -1,
#'   exp_name = "my_experiment",
#'   pathToExp = "/path/to/experiment"
#' )
#' }
#'
#' @export


#control_var1 = 0
#unit_var1 = "\u00B5M"
#endp_groups = list(
#  group1 = c("BSL1", "BSL2", "BSL3", "BSL4"),
#  group2 = c("VMR2", "VMR3", "VMR4", "VMR5")
#)
#habituation_assay_list = c("ASH1")
#reference_pos = -1

individual_endpoints_plotting <- function(control_var1,
                                          unit_var1,
                                          endp_groups,
                                          habituation_assay_list,
                                          reference_pos, exp_name, pathToExp) { # y pos for acoustic stimuli

  # avoid scientific notation
  options(scipen = 999)

  # The errorbars overlapped, so use position_dodge to move them horizontally
  pd <- ggplot2::position_dodge(0.1)  # move them .05 to the left and right

  # create plotting list with data for all concentrations
  files <- list.files(file.path(pathToExp, "result_files", "timeseries_plot_df_per_var1"), pattern = "\\.rda$", full.names = TRUE)
  #latest_files_filtered <- get_latest_file(files)
  dates <- as.Date(substr(basename(files), 1, 8), format = "%Y%m%d")
  latest_files <- files[which(dates == max(dates))]
  latest_files_filtered <- latest_files[grepl(exp_name, latest_files)]

  # Extract concentration in the filename 
  # ^.*_ all charactres before underscore are ignored; 
  # \\d+(\\.\\d+)? One or more digits with optional decimal point are extracted
  extracted_values <- sub("^.*_(\\d+(\\.\\d+)?)\\.rda$", "\\1", basename(latest_files_filtered))
  sorted_files <- latest_files_filtered[order(as.numeric(extracted_values))]
  plotting_list <- list()
  for (file in sorted_files) {
    loaded_object_name <- load(file)
    loaded_object <- get(loaded_object_name)

    if (is.data.frame(loaded_object)) {
      # add data frame to plotting list
      plotting_list[[length(plotting_list) + 1]] <- loaded_object
    } else {
      warning(paste(file, "is not a dataframe."))
    }
  }

  # info for stimuli labels
  assay_data$colors <- as.factor(assay_data$colors)


  # plot every dataframe in plotting_list (every concentration)
  for (i in seq_along(plotting_list)) {
    #i <- 1
    initial_df <- plotting_list[[i]]

    # Create a vector of all assays
    assays_list <- unique(initial_df$endpoint[!is.na(initial_df$endpoint) & initial_df$endpoint != ""])

    # Check if a groups argument exists
    if (exists("endp_groups") && length(endp_groups) > 0) {
      # assays that are grouped
      grouped_assays <- unlist(endp_groups)

      # all ungrouped assays
      ungrouped_assays <- setdiff(assays_list, grouped_assays)

      # new list containing ungrouped assays and groups
      updated_assay_list <- list()

      # add groups to updated_assay_list
      for (group in names(endp_groups)) {
        updated_assay_list[[group]] <- endp_groups[[group]]
      }

      # add ungrouped assays as single list elements
      for (assay in ungrouped_assays) {
        updated_assay_list[[assay]] <- assay
      }
    } else {
      updated_assay_list <- list()
      for (assay in assays_list) {
        updated_assay_list[[assay]] <- assay
      }
    }
    # print(updated_assay_list)


    # for each element in updated_assay_list
    for (assay in names(updated_assay_list)) {
      #assay <- names(updated_assay_list)[10]
      var1_df_1 <- initial_df[initial_df$endpoint %in% updated_assay_list[[assay]],]

      start_time <- min(var1_df_1$time)
      end_time <- max(var1_df_1$time)

      # add a time window of 5 sec only for indivual assays, not for groups
      if (length(updated_assay_list[[assay]]) > 1) {
        time_window <- c(start_time, end_time)
      } else {
        time_window <- c(start_time - 5, end_time + 5)
      }

      # filter var1_df to include only rows where time is within the calculated time window
      var1_df <- initial_df[initial_df$time >= time_window[1] & initial_df$time <= time_window[2],]

      # convert stimulus_name from factor to character
      var1_df$stimulus_name <- as.character(var1_df$stimulus_name)
      var1_df$stimuli <- NA_character_

      # add a stimuli column that contains all the stimuli, that are displayed in the legend
      for (i in seq_len(nrow(var1_df))) {
        #if (is.na(var1_df$stimulus_name2[i]) | var1_df$stimulus_name2[i] == "")
        if (is.na(var1_df$stimulus_name2[i]) || trimws(var1_df$stimulus_name2[i]) == "") {
          var1_df$stimuli[i] <- var1_df$stimulus_name[i]  # Assign stimulus_name to stimuli if stimulus_name2 is NA
        } else {
          var1_df$stimuli[i] <- paste(var1_df$stimulus_name[i], var1_df$stimulus_name2[i], sep = ", ")
        }
      }

      var1_df$stimuli[1] <- ""
      var1_df$stimuli[2] <- "Stimulus"


      #### the following lines (the creation of the stimuli_cleaned column in var1_df)
      #### are to make sure that the legend has all the information needed and to
      ####remove duplicated strings (e.g. "IR light")

      # split all stimuli and check, if the single values are in stimuli_classes
      # stimuli_split is a list, that contains all single stimuli present in each row of var1_df
      # (wenn in stimuli classes einzelne Wörter, können sie so auch in der Legende übernommen werden,
      # wenn nicht, ist es ein zusammenhängender Stimulus, der nicht getrennt werden sollte)
      stimuli_split <- strsplit(var1_df$stimuli, ", ")
      stimuli_class_values <- unique(stimuli_classes$stimulus_class)

      # Create a list, that contains all stimuli that have to be displayed in the legend
      stimuli_cleaned <- character(length(stimuli_split))
      # create a list to track, which of the single stimuli was written to a new column
      stimuli_pair_tracker <- list()
      # Check for each entry of the stimuli_split list/row of var1_df:
      for (i in seq_along(stimuli_split)) {
        entry <- stimuli_split[[i]]
        if (length(entry) == 0) {
          stimuli_cleaned <- ""
        }else if (length(entry) == 1) {
          stimuli_cleaned[[i]] <- entry
        } else {
          stimuli_pair <- paste(entry, collapse = ",")

          # compare if stimuli cell is identical with the one in the row above
          # if so, select alternating one of the stimuli for stimuli_cleaned
          if (i > 1 && var1_df$stimuli[i] == var1_df$stimuli[i - 1]) {
            if (!stimuli_pair %in% names(stimuli_pair_tracker)) {
              stimuli_pair_tracker[[stimuli_pair]] <- 1
            }
            current_index <- stimuli_pair_tracker[[stimuli_pair]]
            stimuli_cleaned[[i]] <- entry[current_index]
            next_index <- (current_index %% length(entry)) + 1
            stimuli_pair_tracker[[stimuli_pair]] <- next_index
          } else {
            # If the following rows are not identical, select the stimulus which is not yet listed in stimuli_cleaned
            for (val in entry) {
              if (!(val %in% stimuli_cleaned)) {
                stimuli_cleaned[i] <- val
                break  ## unnötig??
              }else {
                stimuli_cleaned[i] <- entry[1]
              }
            }
          }
        }
      }
      var1_df$stimuli_cleaned <- stimuli_cleaned
      #view(var1_df)

      # adjust acoustic_stimuli for the stimuli during the assay
      acoustic_stimuli_filtered <- acoustic_stimuli_indiv[
        acoustic_stimuli_indiv$start < time_window[2] & acoustic_stimuli_indiv$end >= time_window[1],]  # changed <= to < -> avoid stimuli in plot that do not belong to this assay

      # set start and end of the stimuli to the time range around the assay
      acoustic_stimuli_filtered$start <- ifelse(acoustic_stimuli_filtered$start < time_window[1], time_window[1], acoustic_stimuli_filtered$start)
      acoustic_stimuli_filtered$end <- ifelse(acoustic_stimuli_filtered$end > time_window[2], time_window[2], acoustic_stimuli_filtered$end)


      # adjust assays_info
      assays_names <- unique(var1_df_1$endpoint)
      title_plot <- unique(var1_df_1$endpoint)
      filtered_assays_info <- assay_data[assay_data$assays %in% assays_names,]

      if (length(assays_names) > 1) {
        title_plot <- paste(assays_names, collapse = " ")
        assays_names <- paste0(assays_names[1], "_", assays_names[length(assays_names)])
      }

      filtered_assays_info$start <- ifelse(filtered_assays_info$start < time_window[1], time_window[1], filtered_assays_info$start)
      filtered_assays_info$end <- ifelse(filtered_assays_info$end > time_window[2], time_window[2], filtered_assays_info$end)

      assays_dividers <- filtered_assays_info[filtered_assays_info$divider_lines == "yes",]

      # plot specific concentration against control
      if (length(unique(var1_df$var1)) == 1) {
        colorscale <- "gray25"
      } else {
        colorscale <- c("gray25", "red")
      }

      # create legend with value of var1, control and stimuli classes
      # filter stimuli classes that are in this assay
      # set up of table containing the outer line color and the fill of the squares in the legend
      data_colors <- data.frame(unique(as.character(var1_df$legend_key)),
                                colorscale,
                                colorscale)

      colnames(data_colors) <- colnames(stimuli_classes)

      stimuli_classes_filtered <- data.frame()
      var1_stim <- unique(var1_df$stimuli_cleaned)
      stimuli_classes_filtered <- stimuli_classes[stimuli_classes$stimulus_class %in% var1_stim,]


      # add the outer line color and the fill of the squares for the stimuli, taken from the excel table loaded in the beginning
      stimuli_classes_all <- rbind(data_colors, stimuli_classes_filtered)

      # convert the stimulus_class column to factors, so they appear in our desired order in the plot
      stimuli_classes_all$stimulus_class <- factor(stimuli_classes_all$stimulus_class,
                                                   levels = stimuli_classes_all$stimulus_class)

      var1_df$title <- title_plot

      # fill color for title bar
      if (nrow(filtered_assays_info) == 0) {
        fill_color <- "white"
      }else {
        fill_color <- as.character(filtered_assays_info$color[1])
      }
      print(paste0("Assay: ", assay, " - color: ", fill_color))

      # define y pos according to reference_pos
      for (i in seq_len(nrow(acoustic_stimuli_filtered))) {
        if (acoustic_stimuli_filtered$y_pos[i] < reference_pos) {
          acoustic_stimuli_filtered$y_pos_updated[i] <- reference_pos - acoustic_stimuli_filtered$height[i]
        }else {
          acoustic_stimuli_filtered$y_pos_updated[i] <- acoustic_stimuli_filtered$y_pos[i]
        }
      }

      # y-axis position of x-axis
      y_min <- min(acoustic_stimuli_filtered$y_pos_updated) - 0.2

      ################### plot grouped assays ################################
      # for grouped assays, create facet plots
      if (length(updated_assay_list[[assay]]) > 1) {
        lineplot <- ggplot(var1_df, aes(x = time)) +
          facet_grid(. ~ endpoint, scales = "free_x") +
          geom_tile(aes(x = time,
                        y = median / 100,
                        color = stimuli_cleaned,
                        fill = stimuli_cleaned),
                    alpha = 0.5,
          ) +
          geom_ribbon(aes(x = time,
                          ymin = median / 100 - mad / 100, # CI_0.025 -> Mean - SD
                          ymax = median / 100 + mad / 100, # CI_0.975 -> Mean - SD
                          fill = legend_key
          ),
                      alpha = 0.2,
                      show.legend = TRUE
          ) +
          geom_line(aes(x = time, # time_s -> time
                        y = median / 100,
                        color = legend_key),
                    linewidth = 1,
                    alpha = 0.5,
                    show.legend = FALSE) +
          labs(x = "time (s)",
               #y = paste0("Motor activity (", 10^2, " px/s)"),
               y = expression(Motor ~ activity ~ (10^2 ~ px / s)),
               color = paste0("[",
                              unique(var1_df$chemical),
                              "] ", unit_var1),
               fill = paste0("[",
                             unique(var1_df$chemical),
                             "] ", unit_var1)
          ) +
          scale_color_manual(breaks = stimuli_classes_all$stimulus_class,
                             values = stimuli_classes_all$color) +
          scale_fill_manual(breaks = stimuli_classes_all$stimulus_class,
                            values = stimuli_classes_all$fill) +

          guides(fill = guide_legend(override.aes = list(alpha = c(rep(0.5, length(colorscale)),
                                                                   rep(NA, nrow(stimuli_classes_filtered))),
                                                         linetype = c(rep(0, length(colorscale)),
                                                                      rep(1, nrow(stimuli_classes_filtered)))
          )
          )
          ) +
          coord_cartesian(ylim = c(y_min, 6)) +
          scale_y_continuous(breaks = seq(0, 6, by = 2)) +
          theme_classic() +
          theme(
            axis.line = element_line(linewidth = 1),
            axis.ticks = element_line(linewidth = 1),
            axis.ticks.length = unit(0.25, "cm"),
            axis.title.x = element_text(size = 18,
                                        colour = "black"),
            axis.title.y = element_text(size = 18,
                                        colour = "black"),
            legend.title = element_text(size = 14,
                                        colour = "black",
                                        face = "bold"),
            legend.text = element_text(size = 14,
                                       face = "bold"),
            strip.text.x = element_text(size = 18,
                                        face = "bold"),
            panel.border = element_rect(colour = "black", fill = NA, linewidth = 0.2), # adds a frame (gray dashed lines) around the facet plots
            legend.justification = c(1, 0.75),
            legend.key.size = unit(0.2, "cm"),
            legend.position = "right",
            axis.text = element_text(size = 14, color = "black", face = "bold"),
            strip.background = element_rect(  # assigning the assay color to the title box
              fill = fill_color,
              color = "white",
              linewidth = 0.2)
          )

        #print(lineplot)

        # individual dataframes for facets
        # endpoint as factor
        var1_df$endpoint <- factor(var1_df$endpoint)
        df_list <- list()
        for (i in seq_along(levels(var1_df$endpoint))) {
          # add assay name to the dataframe
          acoustic_stimuli_filtered$endpoint <- levels(var1_df$endpoint)[[i]]
          facet_data <- var1_df[var1_df$endpoint == levels(var1_df$endpoint)[[i]],]
          acoustic_stimuli_filtered_new <- acoustic_stimuli_filtered
          # make acoustic stimuli dataframes for every assay and adapt start and end time for the stimuli according to the duration of the assay
          for (stimulus in acoustic_stimuli_filtered$acoustic_assays) {
            # if the stimulus starts earlier than the assay, set the start time of the stimulus to the time the assay starts
            if (acoustic_stimuli_filtered$start[acoustic_stimuli_filtered$acoustic_assays == stimulus] < facet_data$time[1]) {
              acoustic_stimuli_filtered_new$start[acoustic_stimuli_filtered_new$acoustic_assays == stimulus] <- facet_data$time[1]
            }
            # if the stimulus ends later than the assay, set the end time of the stimulus to the time the assay ends
            if (acoustic_stimuli_filtered$end[acoustic_stimuli_filtered$acoustic_assays == stimulus] > facet_data$time[nrow(facet_data)]) {
              acoustic_stimuli_filtered_new$end[acoustic_stimuli_filtered_new$acoustic_assays == stimulus] <- facet_data$time[nrow(facet_data)]
            }
            # if stimulus starts later than the assay ends, delete it from this dataframe
            if (acoustic_stimuli_filtered$start[acoustic_stimuli_filtered$acoustic_assays == stimulus] > facet_data$time[nrow(facet_data)]) {
              acoustic_stimuli_filtered_new <- acoustic_stimuli_filtered_new[acoustic_stimuli_filtered_new$acoustic_assays != stimulus,]
            }
            # if the stimulus ends earlier than the assay starts, delete it from this dataframe
            if (acoustic_stimuli_filtered$end[acoustic_stimuli_filtered$acoustic_assays == stimulus] < facet_data$time[1]) {
              acoustic_stimuli_filtered_new <- acoustic_stimuli_filtered_new[acoustic_stimuli_filtered_new$acoustic_assays != stimulus,]
            }
          }
          df_list[[i]] <- acoustic_stimuli_filtered_new

          lineplot <- lineplot +
            geom_rect(data = acoustic_stimuli_filtered_new,
                      aes(xmin = start, xmax = end,
                          ymin = y_pos, ymax = y_pos + height),
                      fill = acoustic_stimuli_filtered_new$fill,
                      color = acoustic_stimuli_filtered_new$color,
                      linewidth = 0.3,
                      inherit.aes = FALSE,
                      show.legend = FALSE)
          #print(lineplot)
        }

        ##################### plot assays individally #########################
      } else {
        lineplot <- ggplot(var1_df) +
          geom_tile(aes(x = time,
                         y = median / 100,  #added /100
                        color = stimuli_cleaned,
                        fill = stimuli_cleaned),
                     #alpha = 0.5,
          ) +
          geom_ribbon(aes(x = time,
                          ymin = median / 100 - mad / 100, # CI_0.025 -> Mean - SD
                          ymax = median / 100 + mad / 100, # CI_0.975 -> Mean - SD
                          fill = legend_key
          ),
                      alpha = 0.2,
                      show.legend = TRUE
          ) +
          facet_grid(. ~ title) +
          geom_line(aes(x = time, # time_s -> time
                        y = median / 100, # median -> Means
                        color = legend_key),
                    linewidth = 1,
                    alpha = 0.5,
                    show.legend = FALSE) +  # changed from FALSE to TRUE
          labs(x = "time (s)",
               #y = paste0("Motor activity (", 10^2, " px/s)"),
               y = expression(Motor ~ activity ~ (10^2 ~ px / s)),
               color = paste0("[",
                              unique(var1_df$chemical),
                              "] ", unit_var1),
               fill = paste0("[",
                             unique(var1_df$chemical),
                             "] ", unit_var1)
          ) +
          # assay dividers, dashed lines
          geom_segment(data = assays_dividers,
                       aes(x = start, xend = start,
                           y = 0, yend = Inf),
                       linetype = 3,
                       inherit.aes = FALSE,
                       linewidth = 0.2) +
          geom_segment(data = assays_dividers,
                       aes(x = end, xend = end,
                           y = 0, yend = Inf),
                       linetype = 3,
                       inherit.aes = FALSE,
                       linewidth = 0.2) +

          # acoustic stimuli
          geom_rect(aes(xmin = start, xmax = end,
                        ymin = y_pos_updated, ymax = y_pos_updated + height),
                        fill = acoustic_stimuli_filtered$fill,
                        color = acoustic_stimuli_filtered$color,
                    linewidth = 0.3,
                    inherit.aes = FALSE,
                    show.legend = FALSE,
                    data = acoustic_stimuli_filtered) +
          scale_fill_manual(breaks = stimuli_classes_all$stimulus_class,
                             #values = stimuli_classes_all$color
                             values = setNames(stimuli_classes_all$color, stimuli_classes_all$stimulus_class)) +
          scale_color_manual(breaks = stimuli_classes_all$stimulus_class,
                             #values = stimuli_classes_all$color
                             values = setNames(stimuli_classes_all$color, stimuli_classes_all$stimulus_class),
                             guide = "none"
          ) +
          guides(fill = guide_legend(override.aes = list(
            color = stimuli_classes_all$color,
            fill = stimuli_classes_all$fill
          ))) +
          #guides(fill = guide_legend(override.aes = list(alpha = c(rep(0.5, length(colorscale)),
          #                                                         rep(NA, nrow(stimuli_classes_filtered)))
          #                                               linetype = c(rep(0, length(colorscale)),
          #                                                            rep(1, nrow(stimuli_classes_filtered)))
          #))) +
          coord_cartesian(ylim = c(y_min, 6)) +
          scale_y_continuous(breaks = seq(0, 6, by = 2)) +
          scale_x_continuous(expand = c(0, 0)) +
          theme_classic() +
          theme(
            axis.line = element_line(linewidth = 1),
            axis.ticks = element_line(linewidth = 1),
            axis.ticks.length = unit(0.25, "cm"),
            #y.axis.text = element_text(size = 18,
            #                         colour = "black",
            #                         face = "bold"),
            #x.axis.text = element_text(size = 17,
            #                           color = "black"),
            axis.title.x = element_text(size = 18,
                                        colour = "black"),
            #face = "bold"),
            axis.title.y = element_text(size = 18,
                                        colour = "black"),
            #face = "bold"),
            #axis.title = element_text(size = 18,
            #                          colour = "black",
            #                          face = "bold"),
            legend.title = element_text(size = 14,
                                        colour = "black",
                                        face = "bold"),
            legend.text = element_text(size = 14,
                                       face = "bold"),
            strip.text.x = element_text(size = 18,
                                        face = "bold"),
            panel.border = element_rect(colour = "black", fill = NA, linewidth = 0.2), # adds a frame (gray dashed lines) around the facet plots
            legend.justification = c(1, 0.75),
            legend.key.size = unit(0.2, "cm"),
            legend.position = "right",
            axis.text = element_text(size = 14, color = "black", face = "bold"),
            strip.background = element_rect(  # assigning the assay color to the title box
              fill = fill_color,
              color = "white",
              linewidth = 0.2)
          )
        # print(lineplot)
      }

      ####################### Plot habituation curve ###############################
      for (phase in habituation_assay_list) {
        if (assay == phase) {           # unnötig?
          habit_df <- var1_df[!is.na(var1_df$stimulus_n) & var1_df$endpoint == phase,]

          ASHplot <- ggplot(habit_df) +
            geom_ribbon(aes(x = stimulus_n,
                            ymin = median / 100 - mad / 100, # CI_0.025 -> Mean - SD
                            ymax = median / 100 + mad / 100, # CI_0.975 -> Mean - SD
                            fill = legend_key
            ),
                        alpha = 0.2,
                        show.legend = TRUE
            ) +
            facet_grid(. ~ title) +
            geom_line(aes(y = median / 100,
                          x = stimulus_n,
                          color = legend_key),
                      linewidth = 1,
                      alpha = 0.5
            ) +
            labs(x = "Stimulus no.",
                 #y = paste0("Motor activity (", 10^2, " px/s)"),
                 y = expression(Motor ~ activity ~ (10^2 ~ px / s)),
                 color = paste0("[",
                                unique(var1_df$chemical),
                                "] ", unit_var1),
                 fill = paste0("[",
                               unique(var1_df$chemical),
                               "] ", unit_var1)
            ) +
            scale_color_manual(breaks = data_colors$stimulus_class,
                               values = data_colors$color) +
            scale_fill_manual(breaks = data_colors$stimulus_class,
                              values = data_colors$fill) +
            guides(fill = guide_legend(override.aes = list(alpha = rep(0.5, length(colorscale)),
                                                           linetype = rep(0, length(colorscale))
            )
            )
            ) +
            coord_fixed(ratio = 8) +
            #coord_cartesian(ylim = c(0, 6)) +
            scale_y_continuous(breaks = seq(0, 6, by = 2), limits = c(0, 6)) +
            #scale_y_continuous(breaks = seq(0, 6, by = 2))+
            #scale_x_continuous(expand = c(0, 0))+
            theme_classic() +
            theme(
              axis.line = element_line(linewidth = 1),
              axis.ticks = element_line(linewidth = 1),
              axis.ticks.length = unit(0.25, "cm"),
              axis.title.x = element_text(size = 18,
                                          colour = "black"),
              #face = "bold"),
              axis.title.y = element_text(size = 18,
                                          colour = "black"),
              #face = "bold"),
              legend.title = element_text(size = 14,
                                          colour = "black"),
              #face = "bold"),
              legend.text = element_text(size = 12),
              #face = "bold"),
              strip.text.x = element_text(size = 14,
                                          face = "bold"),
              panel.border = element_rect(colour = "black", fill = NA, linewidth = 0.2), # adds a frame (gray dashed lines) around the facet plots
              legend.justification = c(1, 0.75),
              legend.key.size = unit(0.2, "cm"),
              legend.position = "right",
              axis.text = element_text(size = 14, color = "black", face = "bold"),
              strip.background = element_rect(  # assigning the assay color to the title box
                fill = fill_color,
                color = "white",
                linewidth = 0.2)
            )

          # print(ASHplot)

          ### Create a filename containing assay name(s), exp. name and var1
          var1 <- unique(var1_df$var1)
          if (length(var1) == 1) {
            var1 <- control_var1
          } else {
            if (var1[1] == control_var1) {
              var1 <- var1[2]
            } else {
              var1 <- var1[1]
            }
          }

          filename <- paste0(gsub("-", "", Sys.Date()), "_", paste0(unique(var1_df$experiment), collapse = "_"), "_", var1, "_", phase, "_stimuli")
          file_path <- file.path(pathToExp, "result_plots", "individual_assays_timeseries", filename)

          ## close all open graphic devices
          #while (dev.cur() > 1) dev.off()

          ggsave(filename = paste0(file_path, ".svg"), plot = ASHplot, device = "svg")
          save(ASHplot, file = paste0(file_path, ".rda"))
        }
      }

      #### Create a filename containing assay name(s), exp. name and var1
      var1 <- unique(var1_df$var1)
      if (length(var1) == 1) {
        var1 <- control_var1
      } else {
        if (var1[1] == control_var1) {
          var1 <- var1[2]
        } else {
          var1 <- var1[1]
        }
      }

      if (length(assays_names) > 1) {
        assays_names <- paste0(assays_names[1], "_", assays_names[length(assays_names)])
      }
      filename <- paste0(gsub("-", "", Sys.Date()), "_", paste0(unique(var1_df$experiment), collapse = "_"), "_", var1, "_", assays_names, "_timeseries")
      file_path <- file.path(pathToExp, "result_plots", "individual_assays_timeseries", filename)

      ## close all open graphic devices
      #while (dev.cur() > 1) dev.off()

      if (nrow(var1_df_1) <= 2) {
        plot_width <- 5
      } else {
        plot_width <- 10
      }
      ggsave(filename = paste0(file_path, ".svg"), plot = lineplot, device = "svg", width = plot_width, height = 4)

      save(lineplot, file = paste0(file_path, ".rda"))
    }
  }

}
