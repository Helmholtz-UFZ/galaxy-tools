#' Phase boxplot plotting
#'
#' Calculates and plots boxplots for phase data using model outputs. Handles
#' multiple experiments by selecting the latest model list per experiment and
#' combining them for plotting and pairwise comparisons.
#'
#' @param phase_name Character string used in output filenames to identify the
#'   endpoint set (e.g., "BSL1_VMR5" or "PhaseSums").
#' @param y_axis_title Character string for the y axis title.
#' @param pathToExp Character string. Path to the experiment directory containing necessary subdirectories for input and output.
#'
#' @return No return value. Writes plots to `pathToExp/result_plots/phase_boxplots`.
#'
#' @examples
#' \dontrun{
#' phase_boxplot_plotting_pairwise(
#'   phase_name = "BSL1_VMR5",
#'   y_axis_title = "Summed distance moved (px/min)",
#'   pathToExp = "/path/to/experiment"
#' )
#' }
#'
#' @export


#y_axis_title = "Summed distance moved\n(px/min)"
#phase_name = "BSL1_VMR5"
#phase_name <- "PhaseSums"


phase_boxplot_plotting_pairwise <- function(phase_name, y_axis_title, pathToExp) {

  # avoid scientific notation
  options(scipen = 999)

  # load the data
  modeldata_files <- list.files(file.path(pathToExp, "result_files", "gam"), full.names = TRUE, pattern = paste0(phase_name, ".*_gamm_beta_modellist.rds"))

  # if data does not come from more than one experiments
  # modeldata_file <- modeldata_files[which.max(as.Date(substr(basename(modeldata_files), 1, 8), "%Y%m%d"))]
  # modellist <- readRDS(modeldata_file)

  # For split controls
  # extract experiment substrings from the file names
  get_experiment <- function(filename, phase_name) {
    # Remove the directory path first
    fname <- basename(filename)
    # Extract the substring between phase_name and _gamm_beta_modellist.rds
    pattern <- paste0(phase_name, "_(.*)_gamm_beta_modellist\\.rds$")
    matches <- regmatches(fname, regexec(pattern, fname))
    if (length(matches[[1]]) > 1) matches[[1]][2] else NA
  }

  # Extract the date from the file name (assumed to be the first 8 characters)
  get_file_date <- function(filename) {
    as.Date(substr(basename(filename), 1, 8), "%Y%m%d")
  }

  file_info <- data.frame(
    file = modeldata_files,
    experiment = sapply(modeldata_files, get_experiment, phase_name = phase_name),
    date = sapply(modeldata_files, get_file_date),
    stringsAsFactors = FALSE
  )

  latest_files <- file_info %>%
    group_by(experiment) %>%
    filter(date == max(date)) %>%
    pull(file)

  print(latest_files)

  # Read all lists from files
  model_lists <- lapply(latest_files, readRDS)

  # Get all unique chemical names present across all model_lists
  all_chems <- unique(unlist(lapply(model_lists, names)))

  # For each chemical, collect the data frames from all experiments, then bind them
  combined_by_chem <- lapply(all_chems, function(chem) {
    chem_dfs <- lapply(model_lists, function(lst) {
      lst[[chem]]
    })
    bind_rows(chem_dfs)
  })

  # Set names, so you can access via chemical name
  names(combined_by_chem) <- all_chems

  modellist <- combined_by_chem

  # load the phase data
  phase_data_files <- list.files(file.path(pathToExp, "result_files", "gam"),
                                 pattern = paste0(phase_name, "_results.rda"),
                                 full.names = TRUE,
                                 recursive = FALSE
  )
  loaded_objects <- load(file = get_latest_file(phase_data_files))
  oneMinBinData <- get(loaded_objects[1])

  # Factor setting helper
  set_factor_levels <- function(df, col, ref) {
    df[[col]] <- factor(df[[col]], levels = unique(ref))
    df
  }

  # function to add custom y-axes to each facet
  scale_inidividual_facet_y_axes <- function(plot, ylims, ybreaks) {

    # saves the original init_scales function from ggplot 
    init_scales_orig <- plot$facet$init_scales

    # modification of init_scales function
    init_scales_new <- function(...) {
      r <- init_scales_orig(...)
      # Extract the Y Scale Limits
      y <- r$y
      print(y)
      # If this is not the y axis, then return the original values
      if (is.null(y)) return(r)
      # If these are the y axis limits, 
      # then we iterate over them, replacing them as 
      # specified by our ylims parameter
      for (i in seq(1, length(y))) {
        ylim <- ylims[[i]]
        ybreak <- ybreaks[[i]]
        if (!is.null(ylim)) {
          y[[i]]$limits <- ylim
          y[[i]]$breaks <- ybreak
        }
      }
      # Now we reattach the modified Y axis limit list to the original return object
      r$y <- y
      return(r)
    }

    plot$facet$init_scales <- init_scales_new

    return(plot)
  }

  # get separate tables by chemicals, as plotting will be done per chemical
  aes_list <- split(conc_data, conc_data$chemical)
  aes_list <- aes_list[order(names(aes_list))]

  # get separate tables by chemicals, as plotting will be done per chemical
  chemsplit <- split(oneMinBinData, oneMinBinData$chemical)
  chemsplit <- chemsplit[order(names(chemsplit))]

  chemicals <- names(chemsplit)

  # str(chemsplit)

  #########################

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

  ##################


  for (chem in chemicals) {
    #chem <- 1 # for testing for loop -> delete when executing function!!!

    # extract info for respective chemical
    aes_data <- aes_list[[chem]]

    # extract info for respective chemical
    plotdata <- chemsplit[[chem]]

    # set the factor order according to the aesthetic data input to ensure correct order in the plot
    plotdata <- set_factor_levels(plotdata, "var1", gsub(" uM", "", aes_data$var1))
    plotdata <- set_factor_levels(plotdata, "endpoint", assay_data$assays)
    plotdata$animalID <- factor(plotdata$animalID)
    plotdata <- set_factor_levels(plotdata, "var2", aes_data$var2)
    plotdata <- set_factor_levels(plotdata, "var3", aes_data$var3)

    # summarize animals per group
    binned_data <- plotdata %>%
      dplyr::group_by(var1, var2) %>%
      dplyr::summarize(sums = dplyr::n_distinct(animalID), .groups = 'drop')

    #legend key assembly
    leg.key <- paste0("n=", binned_data$sums)

    # necessary to bind box- and violin plots to the same positions
    dodge <- position_dodge(width = 0.9)

    colscale <- aes_list[[chem]]$color

    plotdata <- data.table(plotdata)


    # Set y_min, y_max by endpoint (use left_join for vectorization)
    phase_limits <- assay_data[, c("assays", "boxplot_y_min", "boxplot_y_max")]
    colnames(phase_limits) <- c("endpoint", "y_min", "y_max")
    plotdata <- merge(plotdata, phase_limits, by = "endpoint", all.x = TRUE)


    # this block generates the limits and breaks for the boxplots.
    # data is taken from the assay data file and transformed into a list.
    # an important feature is that the y-axis minimum is set automatically 
    # to zero if the y_min is set a value <0. This is necessary to ensure
    # available space for the significance letter underneath.
    # limit_list <- list()
    # breaks_list <- list()

    limit_list <- tapply(plotdata$sums, plotdata$endpoint,
                         function(x) range(x, na.rm = TRUE))
    breaks_list <- tapply(plotdata$sums, plotdata$endpoint,
                          function(x) pretty(range(x, na.rm = TRUE)))

    filtered_assays <- assay_data_whole_timeseries %>%
      dplyr::filter(assays %in% unique(plotdata$endpoint))
    color_vector <- setNames(filtered_assays$colors, filtered_assays$assays)

    #  for (assay in seq_len(nrow(assay_data))) {
    #    # Only for the assay phases needed (for other assay phases boxplot_y_min is NA)
    #    if (!is.na(assay_data$boxplot_y_min[assay]) && assay_data$boxplot_y_min[assay] != "") {

    #       assay.limits <- c(assay_data$boxplot_y_min[assay],
    #                         assay_data$boxplot_y_max[assay]
    #       )

    #      if (assay_data$boxplot_y_min[assay] < 0) {
    #        assay.breaks <- seq(0,
    #                            assay_data$boxplot_y_max[assay],
    #                            by = assay_data$boxplot_y_interval[assay]
    #        )
    #      } else {
    #        assay.breaks <- seq(assay_data$boxplot_y_min[assay],
    #                            assay_data$boxplot_y_max[assay],
    #                            by = assay_data$boxplot_y_interval[assay]
    #        )
    #      }
    #      #limit_list[[assay]] <- assay.limits
    #      #breaks_list[[assay]] <- assay.breaks
    #      limit_list <- append(limit_list, list(assay.limits))
    #      breaks_list <- append(breaks_list, list(assay.breaks))
    #      #limit_list <- append(limit_list, assay.limits)
    #      #breaks_list <- append(breaks_list, assay.breaks)
    #    }
    #  }

    # define the legend label. "\U03BC" is the unicode for
    # the mikro sign. As the mikro sign is not available on 
    # non-german keyboards, the user can use "uM" as a synonym for
    # mikro molar in the aesthetic file. 
    # These lines recognize the "uM" pattern and transform
    # it to "µM".
    leg.unit <- gsub("uM", "\U03BCM", unique(aes_data$unit))


    # if you want the unit to appear in the plot legend,
    # you fill out the "unit" column in the aesthetic_file.
    # Depending on the unit you entered, it appears in brackets.
    # If you do not test concentrations with a unit 
    # (e.g. when comparing fish lines), or do not want them to appear,
    # you write "nounit" column in the aesthetic_file.
    if (leg.unit == "nounit") {

      leg.title <- unique(plotdata$chemical)

    } else {

      leg.title <- paste0(unique(plotdata$chemical),
                          " (", leg.unit, ")")
    }

    # plotting of boxplots. Two different boxplots
    # depending on if you included the additional variable or not
    if (length(unique(plotdata$var2)) > 1) {

      # combine the two variables to a unique ID, necessary to avoid
      # confusion of colors
      binned_data$plot_cols <- paste0(binned_data$var1, "@",
                                      binned_data$var2)

      # combine the two variables to a unique ID, necessary to avoid
      # confusion of colors
      aes_data$plot_cols <- paste0(mod_concscale, "@",
                                   aes_data$var2)

      # combine the two variables to a unique ID, necessary to avoid
      # confusion of colors
      plotdata$plot_cols <- paste0(plotdata$var1, "@",
                                   plotdata$var2)

      # set the factor order according to the aesthetic data input to
      # ensure correct order in the plot
      plotdata$plot_cols <- factor(plotdata$plot_cols,
                                   levels = binned_data$plot_cols)

      colscale <- setNames(aes_data$color,
                           aes_data$plot_cols)

      colscale <- colscale[order(factor(names(colscale),
                                        levels = binned_data$plot_cols))]


      var1.labs <- unique(aes_list[[chem]]$var1)


      names(var1.labs) <- levels(plotdata$var1)

      # plotting
      vsrplot <- ggplot2::ggplot(plotdata,
                                 aes(x = var2,
                                     y = sums,
                                     fill = plot_cols)
      ) +
        facet_grid(variable ~ var1,
                   scales = "free_x",
                   labeller = labeller(var1 = var1.labs
                   )
                   #ncol = 3
        ) +
        geom_blank(
          aes(y = y_min)
        ) +
        geom_blank(
          aes(y = y_max)
        ) +
        geom_violin(
          trim = F,
          linewidth = 0.3,
          alpha = .5,
          position = dodge,
          bounds = c(0, Inf)
        ) +
        geom_boxplot(
          width = 0.2,
          position = dodge
        ) +
        labs(
          x = leg.title,
          y = y_axis_title,
          fill = gsub(" ", "\n", leg.title)
        ) +
        # scale_y_continuous(limits = limit_list[[1]],
        #                    breaks = breaks_list[[1]]) +
        scale_fill_manual(
          labels = leg.key,
          values = colscale
        ) +
        theme_classic() +
        guides(
          fill = guide_legend(
            nrow = 3,
            byrow = T)
        ) +
        theme(
          axis.line = element_line(linewidth = 1),
          axis.ticks = element_line(linewidth = 1),
          axis.ticks.length = unit(0.2, "cm"),
          #axis.ticks.x = element_blank(),
          axis.text.y = element_text(size = 14,
                                     colour = "black",
                                     face = "bold"),
          axis.text.x = element_text(size = 14,
                                     colour = "black",
                                     face = "bold",
                                     angle = 90,
                                     hjust = 1,
                                     vjust = 0.5),
          #axis.text.x = element_blank(),
          axis.title = element_text(size = 25,
                                    colour = "black",
                                    face = "bold"),
          legend.position = "bottom",
          legend.title = element_text(size = 14,
                                      colour = "black",
                                      face = "bold"),
          legend.text = element_text(size = 12,
                                     face = "bold"),
          strip.text = element_text(size = 25, face = "bold"),
          panel.background = element_rect(fill = NA,
                                          color = "black",
                                          linewidth = 1)
        )
      print(vsrplot)

    } else {


      strip_bg_list <- lapply(color_vector, function(clr) element_rect(fill = clr))
      # Set the names! (should match your endpoint levels)
      names(strip_bg_list) <- names(color_vector)

      vsrplot <- ggplot(plotdata,
                        aes(x = var1,
                            y = sums,
                            fill = var1)
      ) +
        facet_wrap2(~factor(endpoint,
                            levels = assay_data$assays),
                    #scales = "free_y",
                    #nrow = 2,
                    ncol = 3,
                    strip = strip_themed(
                      background_x = strip_bg_list
                    )
        ) +
        geom_blank(
          aes(y = y_min)
        ) +
        geom_blank(
          aes(y = y_max)
        ) +
        geom_violin(
          trim = FALSE,
          linewidth = 0.3,
          alpha = .5,
          bounds = c(0, Inf)
          #position = dodge
        ) +
        geom_boxplot(
          width = 0.2,
          #position = dodge
        ) +
        labs(
          x = leg.title,
          y = y_axis_title,
          fill = gsub(" ", "\n", leg.title)
        ) +
        #  scale_y_continuous(limits = limit_list[[1]],
        #                     breaks = breaks_list[[1]]) +
        scale_fill_manual(
          labels = leg.key,
          values = colscale
        ) +
        theme_classic() +
        guides(
          fill = guide_legend(
            nrow = 3,
            byrow = T)
        ) +
        theme(
          axis.line = element_line(linewidth = 1),
          axis.ticks = element_line(linewidth = 1),
          axis.ticks.length = unit(0.2, "cm"),
          #axis.ticks.x = element_blank(),
          axis.text.y = element_text(size = 14,
                                     colour = "black",
                                     face = "bold"),
          axis.text.x = element_text(size = 14,
                                     colour = "black",
                                     face = "bold",
                                     angle = 90,
                                     hjust = 1,
                                     vjust = 0.5),
          #axis.text.x = element_blank(),
          axis.title = element_text(
            size = 18,
            colour = "black",
            face = "bold"),
          legend.position = "bottom",
          legend.title = element_text(
            size = 14,
            colour = "black",
            face = "bold"),
          legend.text = element_text(
            size = 14,
            face = "bold"),
          strip.text.x = element_text(
            size = 18,
            face = "bold"),
          panel.background = element_rect(
            fill = NA,
            color = "black")
        )

    }

    # rescaling of the y-axes using the lists created above
    # vsrplot <- scale_inidividual_facet_y_axes(vsrplot,
    #                                           ylims = limit_list,
    #                                           ybreaks = breaks_list)


    letter_list <- list()


    # generation of the significance labels 
    for (facetk in as.character(unique(plotdata$endpoint))) {

      posthocdata <- modellist[[chem]]

      # extract the relevant data
      posthoc <- with(posthocdata,
                      posthocdata[V1 %like% facetk & V2 %like% facetk,])

      # delete the whitespaces before and after "-". This is crucial, because
      # multcompLetters() needs this format to work properly
      posthoc$contrast <- gsub(" - ", "-", posthoc$contrast)

      # create a named vector of the p-values. This is important because 
      # multcompLetters needs this info to match the values to the right concs
      posthoc2 <- setNames(posthoc$p.value, posthoc$contrast)

      # generate a df with the letters
      labels <- generate_label_df(posthoc2)

      names(labels) <- c("Letters", "var1")

      #set y-value accroding to the facets so the letter is placed under the graph.
      # there are 4 assay phases, custom axes will be set for the the first two
      # and for the second two

      yvalue <- assay_data$letter_pos[assay_data$assays == facetk]

      final <- merge(labels, yvalue)

      final$endpoint <- facetk

      if (length(unique(plotdata$var2)) > 1) {

        final$var2 <- sub(".*\\s(.*)\\s.*", "\\1", final$var1)

        final$var1 <- sub("\\s[^ ]+$", "", final$var1)

        final$var1 <- sub("\\s[^ ]+$", "", final$var1)

        final$plot_cols <- paste0(final$var1, "@", final$var2)

      } else {

        final$var1 <- sub("\\s[^ ]+$", "", final$var1)
        # necessary fix as emmeans > v1.7.0 adds a "conc" prefix
        final$var1 <- sub("var1", "", final$var1)

      }


      print(final)

      #letter_list[[i]] <- final
      letter_list[[facetk]] <- final

      # add the generated letters to the plot
      vsrplot <- vsrplot + geom_text(data = final, aes(x = var1, y = y, label = Letters),
                                     fontface = "bold", colour = "black",
                                     position = dodge,
                                     size = 5)
    }

    print(vsrplot)

    # generate and store single endpoint plots
    for (endp in unique(plotdata$endpoint)) {
      #endp <- "ASH5"
      # Only for the endpoints needed (for other endpoints boxplot_y_min is NA)
      if (!is.na(assay_data$boxplot_y_min[assay_data$assays == endp]) && assay_data$boxplot_y_min[assay_data$assays == endp] != "") {

        y_min <- assay_data$boxplot_y_min[assay_data$assays == endp]

        if (y_min < 0) {
          # wenn y_min (aus assay_data table) kliener 0 -> y-Achse soll bei 0 beginnne
          y_min_break <- 0

        } else {
          # wenn y_min aus assay:data table bie was posititivem beginnt, soll auch y-Achse da beginnen
          y_min_break <- y_min
        }

        y_max <- assay_data$boxplot_y_max[assay_data$assays == endp]

        y_interval <- assay_data$boxplot_y_interval[assay_data$assays == endp]

        vsrsub <- plotdata[plotdata$endpoint == endp]

        header_color <- strip_bg_list[[endp]]

        if (length(unique(plotdata$var2)) > 1) {

          singleplot <- ggplot(vsrsub, aes(x = var1,
                                           y = sums,
                                           fill = plot_cols
          )
          ) +
            facet_wrap(~as.character(endp),
                       strip = strip_themed(
                         background_x = strip_bg_list
                       )
            ) +
            geom_violin(trim = FALSE,
                        linewidth = 0.3,
                        alpha = .5,
                        bounds = c(0, Inf)
                        #, position = dodge
            ) +
            geom_boxplot(width = 0.2 #, position = dodge
            ) +

            labs(
              x = "",
              y = y_axis_title,
              fill = bquote(bold(atop(.(chemicals[chem]),
                                      "(" * mu * "M)")))
              #chemicals[chem]
            ) +
            #  scale_y_continuous(limits = c(y_min, y_max),
            #                     breaks = seq(y_min_break, y_max,
            #                                  by = y_interval)) +
            scale_y_continuous(limits = c(-1000, 80000)) +
            scale_fill_manual(labels = leg.key, values = colscale) +
            theme_classic() +
            guides(fill = guide_legend(
              ncol = 1,
              byrow = T)
            ) +
            theme(
              axis.line = element_line(linewidth = 1),
              axis.ticks = element_line(linewidth = 1),
              axis.ticks.length = unit(0.25, "cm"),
              axis.ticks.x = element_blank(),
              axis.text = element_text(size = 14, colour = "black", face = "bold"),
              axis.text.x = element_blank(),
              axis.title = element_text(size = 18, colour = "black", face = "bold"),
              plot.title = element_text(face = "bold"),
              legend.position = "right",
              legend.key.spacing.y = unit(0.5, "cm"),
              legend.title = element_text(size = 14, colour = "black", face = "bold"),
              legend.text = element_text(size = 12, face = "bold"),
              strip.text.x = element_text(size = 18, face = "bold"),
              panel.background = element_rect(fill = NA, color = "black",
                                              linewidth = 1)
            )

        } else {

          singleplot <- ggplot(vsrsub, aes(x = factor(var1),
                                           y = sums,
                                           fill = var1
          )
          ) +
            facet_wrap2(~as.character(endp),
                       strip = strip_themed(
                         background_x = header_color
                       )
            ) +
            geom_violin(trim = F,
                        linewidth = 0.3,
                        alpha = .5,
                        bounds = c(0, Inf)
                        #              position = dodge
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
            #  scale_y_continuous(limits = c(y_min, y_max),
            #                     breaks = seq(y_min_break, y_max,
            #                                  by = y_interval)) +
            #  scale_y_continuous(limits = c(-1000, 80000)) +
            scale_fill_manual(labels = leg.key, values = colscale) +
            theme_classic() +
            guides(fill = guide_legend(
              ncol = 1,
              byrow = T)
            ) +
            theme(
              axis.line = element_line(linewidth = 1),
              axis.ticks = element_line(linewidth = 1),
              axis.ticks.length = unit(0.25, "cm"),
              #axis.ticks.x = element_blank(),
              axis.text = element_text(size = 17,
                                       colour = "black",
                                       face = "bold"),
              #axis.text.x = element_blank(),
              axis.title = element_text(size = 18,
                                        colour = "black",
                                        face = "bold"),
              plot.title = element_text(face = "bold"),
              legend.position = "right",
              legend.key.spacing.y = unit(0.5, "cm"),
              legend.title = element_text(size = 14,
                                          colour = "black",
                                          face = "bold"),
              legend.text = element_text(size = 14,
                                         face = "bold"),
              strip.text.x = element_text(size = 18,
                                          face = "bold"),
              panel.background = element_rect(fill = NA,
                                              color = "black",
                                              linewidth = 1)
            )

        }

        # add the generated letters to the plot
        singleplot <- singleplot + geom_text(data = letter_list[[endp]],
                                             aes(x = var1,
                                                 y = y,
                                                 label = Letters),
                                             fontface = "bold",
                                             colour = "black",
                                             position = dodge,
                                             size = 8)


        print(singleplot)
        chem <- gsub(" ", "_", chem)
        file_name_singleplot <- paste0(gsub("-", "", Sys.Date()),
                                       "_", chem, "_single_plot_", endp, "_", chemicals[chem])
        path_singleplot <- file.path(pathToExp, "result_plots", "phase_boxplots", file_name_singleplot)
        #pdf(paste0(path_singleplot, ".pdf"),
        #    width = 10,
        #    height = 10)
        #print(singleplot)
        #dev.off()

        svg(paste0(path_singleplot, ".svg"),
            width = 10,
            height = 10)
        print(singleplot)
        dev.off()

        save(singleplot, file = paste0(path_singleplot, ".rda"))

        #png(paste0(path_singleplot, ".png"),
        #    width = 950,
        #    height = 950)
        #print(singleplot)
        #dev.off()
      }
    }

    ##############################################
    chem <- gsub(" ", "_", chem)
    file_name_plot <- paste0(gsub("-", "", Sys.Date()),
                             chem, "_violins_Bins_GAM_short_phases", "_", chemicals[chem])
    path_plots <- file.path(pathToExp, "result_plots", "phase_boxplots", file_name_plot)
    #pdf(paste0(path_plots, ".pdf"),
    #    width = 10,
    #    height = 10)
    #print(vsrplot)
    #dev.off()

    svg(paste0(path_plots, ".svg"),
        width = 10,
        height = 10)
    print(vsrplot)
    dev.off()

    save(vsrplot, file = paste0(path_plots, ".rda"))

    #png(paste0(path_plots, ".png"),
    #    width = 950,
    #    height = 950)
    #print(vsrplot)
    #dev.off()

    print(paste0("Chemical ", chem, "/", length(chemsplit), " completed..."))

  }

}
