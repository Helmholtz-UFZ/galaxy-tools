#' Calculate and plot the GAMM
#'
#' Fits generalized additive mixed models to time series data and creates
#' predictions and diagnostic outputs for visualization and post hoc analysis.
#'
#' @param plot_xlimits Numeric vector with x axis limits used for the plot range.
#' @param plot_xbreaks Numeric vector with x axis tick positions. Can differ from the limits.
#' @param plot_ylimits Numeric vector with y axis limits used for the plot range.
#' @param plot_ybreaks Numeric vector with y axis tick positions. Can differ from the limits.
#' @param x_axis_title Character string for the x axis title.
#' @param y_axis_title Character string for the y axis title.
#' @param ref_grid_size Integer. Reference grid size used by emmeans calculations.
#' @param phase_name Character string used in output filenames to identify the
#'   endpoint set (e.g., "BSL1_VMR5" or "PhaseSums").
#' @param exp_name Character string specifying the experiment name, used in input and output file naming.
#' @param pathToExp Character string. Path to the experiment directory containing necessary subdirectories for input and output.
#' @param conc_data Data frame that assigns colors to the groups of var1, var2, and experiment for each chemical.
#'
#' @return No return value. Writes model objects, predictions, diagnostics, and plots to `pathToExp/result_files/gam` and `pathToExp/result_plots/gam`.
#'
#' @examples
#' \dontrun{
#' model_fit_byPlate(
#'   plot_xlimits = c(10, 3200),
#'   plot_xbreaks = c(0, 600, 1200, 1800, 2400, 3000),
#'   plot_ylimits = c(0, 80000),
#'   plot_ybreaks = seq(0, 80000, by = 20000),
#'   x_axis_title = "Time (s)",
#'   y_axis_title = "Summed distance moved (px/min)",
#'   ref_grid_size = 23240,
#'   phase_name = "BSL1_VMR5",
#'   exp_name = "my_experiment",
#'   pathToExp = "/path/to/experiment",
#'   conc_data = conc_data
#' )
#' }
#'
#' @export

#plot_xlimits = c(100, 3100)
#plot_xbreaks = c(120, 1100, 2100, 3100)
#plot_ylimits = c(0, 80000)
#plot_ybreaks = seq(0, 50000, by = 10000)
#x_axis_title = "Time (s)"
#y_axis_title = "Summed distance moved\n(px/min)"
#ref_grid_size = 23240
#phase_name = "VMR1_VMR5"

#plot_xlimits = c(10, 3200)
#plot_xbreaks = c(0, 600, 1200, 1800, 2400, 3000)
#plot_ylimits = c(0, 50000)
#plot_ybreaks = seq(0, 50000, by = 10000)
#x_axis_title = "Time (s)"
#y_axis_title = "Summed distance moved\n(px/min)"
##ref_grid_size = 23240
#ref_grid_size = 10000
#phase_name = "BSL1_VMR5"
#exp_name = exp_name
#pathToExp = pathToExp
#conc_data = conc_data

model_fit_byPlate <- function(plot_xlimits,
                              plot_xbreaks,
                              plot_ylimits,
                              plot_ybreaks,
                              x_axis_title,
                              y_axis_title,
                              ref_grid_size,
                              phase_name, exp_name, pathToExp, conc_data) {


  # set the max number of printed rows high to save the whole model output
  options(max.print = 10000)
  # avoid scientific notation
  options(scipen = 999)

  # import the data
  phase_data_files <- list.files(file.path(pathToExp, "result_files", "gam"),
                                 pattern = paste0(exp_name, "_", phase_name, "_results\\.rda$"),
                                 full.names = TRUE,
                                 recursive = FALSE
  )
  phase_data <- phase_data_files[which.max(as.Date(substr(basename(phase_data_files), 1, 8), "%Y%m%d"))]
  loaded_objects <- load(file = phase_data)
  OneMinBinData <- get(loaded_objects[1])

  # Format all columns to avoid scientific notation
  # OneMinBinData <- as.data.frame(lapply(OneMinBinData, function(x) {
  #   if (all(grepl("^-?[0-9.]+(e-?[0-9]+)?$", x))) {  # Check for numeric values and scientific notation
  #     # if the values are numeric and in scientific notation, convert them to decimal notation
  #     as.numeric(sprintf("%.6f", as.numeric(x)))
  #   } else {
  #     x
  #   }
  # }))


  # get separate tables by chemicals, as plotting will be done per chemical
  aes_list <- split(conc_data, conc_data$chemical)

  aes_list <- aes_list[order(names(aes_list))]

  # get separate tables by chemicals, as plotting will be done per chemical
  chemsplit <- split(OneMinBinData, OneMinBinData$chemical)

  chemsplit <- chemsplit[order(names(chemsplit))]

  chemicals <- names(chemsplit)

  ###########

  modellist <- list()

  for (chem in chemicals) {
    #chem <- 1 # for testing for loop -> delete when executing function!!!!

    # extract info for respective chemical
    aes_data <- aes_list[[chem]]

    mod_var1scale <- gsub(" uM", "", aes_data$var1)

    # extract info for respective chemical
    plotdata <- chemsplit[[chem]]

    # set the factor order according to the aesthetic data input to
    # ensure correct order in the plot
    plotdata$var1 <- factor(plotdata$var1
                            #, levels = unique(mod_var1scale)
    )

    # set the factor order according to the aesthetic data input to
    # ensure correct order in the plot
    plotdata$endpoint <- factor(plotdata$endpoint)

    plotdata$animalID <- factor(plotdata$animalID,
                                levels = unique(plotdata$animalID))

    plotdata$var2 <- factor(plotdata$var2 #,
                            #levels = unique(aes_data$var2)
    )
    plotdata$plate_ID <- factor(plotdata$plate_ID)

    # set the max dist, necessary to use the beta distribution which is from 0-1
    # multiplication with 1.001 ensures that the data are below 1
    maxDist <- max(plotdata$sums) * 1.0001

    # normalize data by calculated maxDist
    plotdata$scaled_values <- plotdata$sums / maxDist

    fitdistrplus::descdist(plotdata$sums, boot = 500)

    # save plotdata
    filename <- paste0(gsub("-", "", Sys.Date()), "_plotdata_before_model")
    file_path <- file.path(pathToExp, "result_files", "gam", filename)
    data.table::fwrite(plotdata, paste0(file_path, ".csv"),
                       sep = ",")
    saveRDS(plotdata, paste0(file_path, ".rds"))

    # model calculation, two models available,
    # depending on the number of variables used  !!!!!!!!!!!!!!!!!!!!!!!!!
    # we also could have a third variable ?????????????????????????????????????????
    if (length(unique(plotdata$var2)) > 1) {
      if (length(unique(plotdata$endpoint)) > 1) {
        beta_gam <- bam(scaled_values ~ s(time, k = 20, bs = "gp") +
          var1 +
          var2 +
          var1:var2 +
          var1:endpoint +
          s(animalID, bs = "re"),
                        data = plotdata,
                        family = betar(link = "logit"), # beta distribution
                        select = TRUE,
                        nthreads = 4
        )
      } else {
        beta_gam <- bam(scaled_values ~ s(time, k = 20, bs = "gp") +
          var1 +
          var2 +
          var1:var2 +
          s(animalID, bs = "re"),
                        data = plotdata,
                        family = betar(link = "logit"), # beta distribution
                        select = TRUE,
                        nthreads = 4
        )
      }


    } else {
      if (length(unique(plotdata$endpoint)) > 1) {
        beta_gam <- bam(scaled_values ~ s(time, k = 20, bs = "gp") +
          factor(var1) +
          endpoint +
          var1:endpoint +
          s(animalID, bs = "re") +
          s(plate_ID, bs = "re"),
                                   data = plotdata,
                                   family = betar(link = "logit"),
                                   select = TRUE,
                                   nthreads = 4,
                                   control = gam.control(trace = TRUE)
        )

       # beta_gam_plateID_fixed <- bam(scaled_values ~ s(time, k = 20, bs = "gp") +
       #   factor(var1) +
       #   endpoint +
       #   var1:endpoint +
       #   plate_ID +
       #   s(animalID, bs = "re"),
       #                               data = plotdata,
       #                               family = betar(link = "logit"),
       #                               select = TRUE,
       #                               nthreads = 4,
       #                               control = gam.control(trace = TRUE)
       # )

      }

      # save the model and model summary
      file_name_gam <- paste0(gsub("-", "", Sys.Date()), "_gamm_beta_", chemicals[chem], "_", phase_name, "_plateID_randEff.rds")
      saveRDS(beta_gam_plateID_fixed, file.path(pathToExp, "result_files", "gam", file_name_gam))

      file_name_bins <- paste0(gsub("-", "", Sys.Date()),
                               "_Bins_GAM_beta_results_", phase_name, collapse = "")
      sink(paste0(file.path(pathToExp, "result_files", "gam", file_name_bins
      ), "_", names(chemsplit[chem]), ".txt"))
      print(summary(beta_gam_plateID_fixed))
      sink()

      ###########

      # use the model to predict data based on the original data
      # INCL random effects
      # plate_ID fixed effect
      pred_randEff <- predict(beta_gam_plateID_fixed,
                              type = "response",
                              newdata = plotdata,
                              se.fit = TRUE,
                              n.threads = 4
      )

      # plate_ID random effect
      pred_randEff <- predict(beta_gam,
                              type = "response",
                              newdata = plotdata,
                              se.fit = TRUE,
                              n.threads = 4
      )

      # calcuate the fit values used for the visualization
      plotdata$fit <- pred_randEff$fit * maxDist

      # get the lower confidence interval for plotting
      plotdata$lwrCI <- pred_randEff$fit - 2 * pred_randEff$se.fit * maxDist

      # get the upper confidence interval for plotting
      plotdata$uprCI <- pred_randEff$fit + 2 * pred_randEff$se.fit * maxDist


      # use the model to predict data based on the original data
      # EXCL random effects
      pred_NOrandEff <- predict(beta_gam,
                                type = "response",
                                newdata = plotdata,
                                se.fit = TRUE, # standard errors are returned
                                exclude = "s(animalID)"
      )

      # calculate the fit values used for the visualization
      plotdata$fit2 <- pred_NOrandEff$fit * maxDist

      # get the lower confidence interval for plotting (with se.fit)
      plotdata$lwrCI2 <- (pred_NOrandEff$fit - 2 * pred_NOrandEff$se.fit) * maxDist

      # get the upper confidence interval for plotting
      plotdata$uprCI2 <- (pred_NOrandEff$fit + 2 * pred_NOrandEff$se.fit) * maxDist

      # print the model's AIC in the plotdata file
      # plate_ID fixed effect
      plotdata$AIC <- AIC(beta_gam_plateID_fixed)
      plotdata$AIC <- AIC(beta_gam)

      # combine the two variables to a unique ID, necessary to avoid
      # confusion of colors
      aes_data$plot_cols <- paste0(mod_var1scale, "@",
                                   aes_data$var2)


      colscale <- setNames(aes_data$color,
                           aes_data$plot_cols)

      plotdata$plot_cols <- factor(paste0(plotdata$var1, "@",
                                          plotdata$var2),
                                   levels = names(colscale))

      # define the legend label. "\U03BC" is the unicode for
      # the mikro sign. As the mikro sign is not available on
      # non-german keyboards, the user can use "uM" as a synonym for
      # mikro molar in the aesthetic file.
      # These lines recognize the "uM" pattern and transform
      # it to "µM".
      leg_unit <- gsub("uM", "\U03BCM", unique(aes_data$unit))


      # if you want the unit to appear in the plot legend,
      # you fill out the "unit" column in the aesthetic_file.
      # Depending on the unit you entered, it appears in brackets.
      # If you do not test concentrations with a unit
      # (e.g. when comparing fish lines), or do not want them to appear,
      # you write "nounit" column in the aesthetic_file.
      if (leg_unit == "nounit") {

        leg_title <- unique(plotdata$chemical)

      } else {

        leg_title <- paste0(unique(plotdata$chemical),
                            " (", leg_unit, ")")
      }

      # Get endpoint boxes in the plot only for endpoints needed
      filtered_assays <- assay_data_whole_timeseries[assay_data_whole_timeseries$assays %in% unique(plotdata$endpoint),]
      filtered_assays$y_pos <- -2000
      # Shift the assay labels slightly to the right as the timepoint where the points are plotted is the end of the 60s bin
      # -> points in the plot would appear between two boxes even though they belong to the previous box
      filtered_assays$end <- filtered_assays$end + 20
      filtered_assays$start <- min(plotdata$time)
      filtered_assays$label_pos <- filtered_assays$label_pos + 20

      # generater a plot object from the observation data as the basis
      fitplot <- ggplot2::ggplot(plotdata,
                                 aes(x = time,
                                     y = sums,
                                     color = plot_cols
                                 )
      ) +

        geom_jitter(
          aes(fill = plot_cols),
          width = 0.1,
          alpha = 0.5,
          size = 1,
          shape = 21,
          color = "black"
        ) +
        geom_rect(aes(xmin = start, xmax = end,
                      ymin = y_pos - 3000,
                      ymax = y_pos + 1000,
                      fill = colors),
                  color = "white",
                  linewidth = 0.15,
                  inherit.aes = FALSE,
                  show.legend = FALSE,
                  data = filtered_assays) +
        scale_fill_identity() +
        geom_text(data = filtered_assays,
                  aes(x = label_pos,
                      y = -3000,
                      label = gsub("\\\\n", " \n", assays)
                  ),
                  lineheight = 1,
                  color = "black",
                  size = 3,
                  inherit.aes = FALSE) +
        scale_color_manual(
          values = colscale
        ) +
        #scale_fill_manual(
        #  values = colscale
        #) +
        scale_y_continuous(
          limits = plot_ylimits,
          breaks = plot_ybreaks
        ) +
        scale_x_continuous(
          limits = plot_xlimits,
          breaks = plot_xbreaks,
        ) +
        labs(title = leg_title,
             x = x_axis_title,
             y = y_axis_title
        ) +
        theme_bw() +
        theme(
          legend.position = "none",
          plot.title = element_text(hjust = 0.5,
                                    face = "bold"),
          axis.line = element_line(linewidth = 1),
          axis.ticks = element_line(linewidth = 1),
          axis.text = element_text(size = 12,
                                   colour = "black",
                                   #face = "bold"
          ),
          axis.title = element_text(size = 12,
                                    colour = "black",
                                    face = "bold"),
          strip.text.x = element_text(size = 12,
                                      face = "bold"),
          legend.title = element_text(size = 12,
                                      colour = "black",
                                      face = "bold"),
          legend.text = element_text(size = 12,
                                     face = "bold")
        )

      # based on the variable input by the user, the model data
      # is added to the basis plot
      if (length(unique(plotdata$var2)) > 1) {

        fitplot_noRandEff <- fitplot +
          facet_grid(var2 ~ var1
          ) +
          geom_ribbon(aes(x = time,
                          ymin = lwrCI2,
                          ymax = uprCI2
          ),
                      fill = "grey",
                      alpha = 0.5,
                      colour = NA
          ) +
          geom_line(aes(x = time,
                        y = fit2
          ),
                    colour = "black")


        fitplot_RandEff <- fitplot +
          facet_grid(var2 ~ var1
          ) +
          geom_ribbon(aes(x = time,
                          ymin = lwrCI,
                          ymax = uprCI,
                          group = animalID),
                      fill = "grey",
                      alpha = 0.5,
                      colour = NA
          ) +
          geom_line(aes(x = time,
                        y = fit,
                        group = animalID),
                    colour = "black"
          )

      } else {

        fitplot_noRandEff <- fitplot +
          facet_wrap(~var1,
                     # nrow = 2,
                     ncol = 3
          ) +
          geom_ribbon(aes(x = time,
                          ymin = lwrCI2,
                          ymax = uprCI2
          ),
                      fill = "grey",
                      alpha = 0.5,
                      colour = NA
          ) +
          geom_line(aes(x = time,
                        y = fit2
          ),
                    colour = "black"
          )


        fitplot_RandEff <- fitplot +
          facet_wrap(~var1,
                     #nrow = 2,
                     ncol = 3
          ) +
          geom_ribbon(aes(x = time,
                          ymin = lwrCI,
                          ymax = uprCI,
                          group = animalID),
                      fill = "grey",
                      alpha = 0.5,
                      colour = NA
          ) +
          geom_line(aes(x = time,
                        y = fit,
                        group = animalID),
                    colour = "black"
          )


      }

      print(fitplot_noRandEff)

      # get the pairwise comparisons using emmeans, again with respect to
      # the variable input by the user
      if (length(unique(plotdata$var2)) > 1) {
        if (length(unique(plotdata$endpoint)) > 1) {
          # emmeans calculates the estimated means for all combinations of the predictors (var1, var2, endpoint)
          posthocraw <- emmeans::emmeans(beta_gam,
                                         pairwise ~ var1 * var2 * endpoint,
                                         adjust = "tukey", # Tukey correction is applied -> avoids Type 1 errors (false positives)
                                         rg.limit = ref_grid_size
                                         #, pbkrtest.limit = 4767
          )
        } else {
          posthocraw <- emmeans::emmeans(beta_gam,
                                         pairwise ~ var1 * var2,
                                         adjust = "tukey",
                                         rg.limit = ref_grid_size
                                         #, pbkrtest.limit = 4767
          )
        }

      } else {
        if (length(unique(plotdata$endpoint)) > 1) {
          posthocraw <- emmeans::emmeans(beta_gam,
                                         pairwise ~ var1 * endpoint,
                                         adjust = "tukey",
                                         rg.limit = ref_grid_size
                                         #, pbkrtest.limit = 4767
          )
        } else {
          posthocraw <- emmeans::emmeans(beta_gam,
                                         pairwise ~ var1,
                                         adjust = "tukey",
                                         rg.limit = ref_grid_size
                                         #, pbkrtest.limit = 4767
          )
        }
      }

      # summary used because it returns a df
      posthoc <- summary(posthocraw)

      # select only the first six columns of the pairwise comparisons
      posthoc <- posthoc$contrasts[, 1:6]

      posthoc$contrast <- gsub("\\(", "", posthoc$contrast)

      posthoc$contrast <- gsub("\\)", "", posthoc$contrast)

      # pairwise comp mod #####

      contrastsplit <- strsplit(posthoc[, 1], " - ")

      #converting the output list to a data frame
      contrastdata <- as.data.frame(do.call("rbind", contrastsplit))

      posthocmod <- cbind(contrastdata, posthoc)

      modellist[[chem]] <- posthocmod

      ################
      print("Printing figures and writing files...")

      # save plotdata dataframe
      filename_plotdata <- paste0(gsub("-", "", Sys.Date()), "_predictions_plotdata_beta_plateID_randomEff", phase_name)
      filepath_plotdata <- file.path(pathToExp, "result_files", "gam", filename_plotdata)
      save(plotdata, file = paste0(filepath_plotdata, ".rda"))
      data.table::fwrite(plotdata, paste0(filepath_plotdata, ".csv"),
                         sep = ",")

      file_name_diagnostics <- paste0(gsub("-", "", Sys.Date()),
                                      "_gam_", unique(plotdata$chemical), "_", phase_name, "_diagnostics_plateID_randomEff")
      full_path_diagnostics <- file.path(pathToExp, "result_plots", "gam", file_name_diagnostics)
      pdf(paste0(full_path_diagnostics, ".pdf"))
      layout(matrix(1:6,
                    #nrow = 2,
                    ncol = 3
      ))
      print(gam.check(beta_gam, rep = 500)) # greift auf Model zu und plottet diagnostics
      dev.off()

      png(paste0(full_path_diagnostics, ".png"))
      layout(matrix(1:4,
                    nrow = 2
                    #ncol = 3
      ))
      print(gam.check(beta_gam, rep = 500))
      dev.off()

      ################
      file_name_fit <- paste0(gsub("-", "", Sys.Date()),
                              "_gam_", unique(plotdata$chemical), "_", phase_name, "_fit_plateID_randomEff")
      full_path_fit <- file.path(pathToExp, "result_plots", "gam", file_name_fit)
      pdf(paste0(full_path_fit, ".pdf"))
      layout(matrix(1:4,
                    #nrow = 2,
                    ncol = 3))
      print(plot(beta_gam_plateID_fixed, pages = 1, scheme = 2, shade = TRUE))
      dev.off()

      png(paste0(full_path_fit, ".png"))
      layout(matrix(1:4,
                    #nrow = 2,
                    ncol = 3
      ))
      print(plot(beta_gam_plateID_fixed, pages = 1, scheme = 2, shade = TRUE))
      dev.off()

      #############
      file_name_NoRandEff <- paste0(gsub("-", "", Sys.Date()),
                                    "_gam_", unique(plotdata$chemical), "_", phase_name, "_fit_NO_rand_effects_plotted_plateID_randomEff")
      path_model_NoRandEff <- file.path(pathToExp, "result_plots", "gam", file_name_NoRandEff)
      svg(paste0(path_model_NoRandEff, ".svg"))
      print(fitplot_noRandEff)
      dev.off()

      save(fitplot_noRandEff, file = paste0(path_model_NoRandEff, ".rda"))

      #tiff(paste0(path_model_NoRandEff, ".tif"))
      #print(fitplot_noRandEff)
      #dev.off()

      #pdf(paste0(path_model_NoRandEff, ".pdf"))
      #print(fitplot_noRandEff)
      #dev.off()

      ##################
      file_name_randEff <- paste0(gsub("-", "", Sys.Date()),
                                  "_gam_", unique(plotdata$chemical), "_", phase_name, "_fit_rand_effects_plotted_plateID_ranodmEff")
      path_model_randEff <- file.path(pathToExp, "result_plots", "gam", file_name_randEff)
      svg(paste0(path_model_randEff, ".svg"))
      print(fitplot_RandEff)
      dev.off()

      save(fitplot_RandEff, file = paste0(path_model_randEff, ".rda"))

      #tiff(paste0(path_model_randEff, ".tif"))
      #print(fitplot_RandEff)
      #dev.off()

      #pdf(paste0(path_model_randEff, ".pdf"))
      #print(fitplot_RandEff)
      #dev.off()

      ##################

      file_name_Tukey <- paste0(gsub("-", "", Sys.Date()), "_", phase_name,
                                "_Bins_GAM_beta_TukeyHSD_pairwise_results_plateID_randomEff",
                                paste(as.character(unique(plotdata$endpoint)), collapse = ""),
                                "_", unique(plotdata$chemical), ".txt")
      sink(file.path(pathToExp, "result_files", "gam", file_name_Tukey
      ))
      print(summary(posthocraw))
      sink()

      print("Files written!")
    }

    file_name_modellist <- paste0(gsub("-", "", Sys.Date()), "_", exp_name, "_", phase_name, "_gamm_beta_modellist_plateID_randomEff.rds")
    saveRDS(modellist, file.path(pathToExp, "result_files", "gam", file_name_modellist))

    return(modellist)

  }
}
