#' Function for AC50 comparison of VAMR endpoints with available toxcast assays
#'
#' @param vamr_file: outputfile from concnetration-response modeling containing all endpoints of the chemical of interest
#' @param cytotox_lb: This is the value of cytotox
# Make sure the toxcast file is saved in all chemical folders!


Assay_comparison <- function(vamr_file, cytotox_lb, cytotox_median, pathToExp, do_filter) {

  log_message <- function(msg, folder = file.path(pathToExp, "result_plots", "C-R_curves", "CompTox"), log_file = "CompTox_messages.log") {
    print("log_message called")
    log_path <- file.path(folder, log_file)
    print(log_path)
    timestamp <- format(Sys.time(), "[%Y-%m-%d %H:%M:%S]")
    full_msg <- paste0(timestamp, " ", msg, "\n")
    cat(full_msg, file = log_path, append = TRUE)
  }

  vamr_file <- vamr_file %>%
    mutate(endpoint = ifelse(endpoint == "ASR_2_3", "ASR2/3", endpoint),
           endpoint = ifelse(endpoint == "ASH_1_5", "ASH1/5", endpoint))

  vamr_file <- vamr_file %>%
    filter(hitcall > 0.9, ac50 > acc)

  # skip if no rows in vamr_file (endpoints are not hits or acc higher than ac50
  if (nrow(vamr_file) == 0) {
    log_message(msg = paste0("No hitcall > 0.9 or AC50 > ACC for ", exp_name))
    return()
  }

  chemical <- unique(vamr_file$chemical)

  toxcast_file <- list.files(file.path(pathToExp),
                             pattern = "Toxcast.*\\.csv",
                             full.names = TRUE,
                             recursive = FALSE
  )
  if (length(toxcast_file) == 0) stop("No Toxcast file found for ", chemical)

  if (do_filter == TRUE) {
    data <- dnt_ivb_assays(toxcast_file)
    if (nrow(data) == 0) {
      log_message(msg = paste0("No DNT-IVB assays found. Using all available ToxCast assays for comparison assay comparison for ", chemical))
      data <- as.data.frame(data.table::fread(toxcast_file))
      dnt_ivb_empty <- TRUE
    } else {
      dnt_ivb_empty <- FALSE
    }
  } else {
    data <- as.data.frame(data.table::fread(toxcast_file))
    dnt_ivb_empty <- FALSE
  }

  data <- data[data$AC50 != " -  " & data$SCALED_TOP != " -  ",]

  #VAMR_files <- list.files(file.path(pathToExp, "result_files", "C-R_model"),
  #                         pattern = "model.rda",
  #                         full.names = TRUE,
  #                         recursive = FALSE)
  #latest_VAMR_file <- VAMR_files[which.max(as.Date(substr(basename(VAMR_files), 1, 8), "%Y%m%d"))]

  #VAMR_file <- get(load(latest_VAMR_file))

  # Exclude endpoints where the AC50 falls within the noise band (i.e., below the ACC) and where the hit call is below 0.9
  #VAMR_file <- VAMR_file[VAMR_file$ac50 > VAMR_file$acc & VAMR_file$hitcall > 0.9, ]
  #VAMR_file <- VAMR_file[VAMR_file$hitcall > 0.75,]
  #VAMR_file$ac50 <- ifelse(VAMR_file$ac50 < VAMR_file$acc, VAMR_file$acc, VAMR_file$ac50)

  # select necessary/ interesting columns
  #data_short <- data[, c("INTENDED_TARGET_FAMILY", "SCALED_TOP", "CONTINUOUS_HIT_CALL", "AC50", "ACC", "BMD")]
  data_short <- data[, c("NAME", "SCALED_TOP", "CONTINUOUS_HIT_CALL", "AC50", "ACC", "BMD")]
  VAMR_short <- vamr_file[, c("endpoint", "top_over_cutoff", "hitcall", "ac50", "acc", "bmd")]

  # Mark where the data is from
  data_short$source <- "toxcast"
  VAMR_short$source <- "vamr"

  # Adjust the names in both dataframes and merge the VAMR data and the Toxcast data
  names(data_short) <- c("endpoint", "top_over_cutoff", "hitcall", "ac50", "acc", "bmd", "source")
  data_all <- rbind(data_short, VAMR_short)
  data_all$ac50 <- as.numeric(data_all$ac50)
  data_all$top_over_cutoff <- as.numeric(data_all$top_over_cutoff)
  data_all$endpoint <- sub("^[^_]*_[^_]*_(.*)$", "\\1", as.character(data_all$endpoint))

  # Generate vibrant yellow shades for VAMR
  unique_names_VAMR <- unique(data_all$endpoint[data_all$source == "vamr"])
  #yellows <- colorRampPalette(c("gold", "orange", "yellow"))(length(unique_names_VAMR))
  # Generate colors for all data points
  #vamr_color_mapping <- setNames(yellows, unique_names_VAMR)

  # use VAMR assay colors
  endpoint_colors <- assay_colors %>%
    filter(assays %in% unique(vamr_file$endpoint)) %>%
    rename(endpoint = assays)

  # Generate grey colors for toxcast data
  unique_names_data_short <- unique(data_all$endpoint[data_all$source == "toxcast"])
  greys <- colorRampPalette(c("#FFFFFF", "#666666"))(length(unique_names_data_short))
  toxcast_color_mapping <- data.frame(
    endpoint = unique_names_data_short,
    colors = greys
  )
  # Add the grey colors from Toxcast assays to the VAMR endpoint colors
  endpoint_colors <- bind_rows(endpoint_colors, toxcast_color_mapping)

  # Create a named vector out of the data frame
  endpoint_color <- setNames(endpoint_colors$colors, endpoint_colors$endpoint)

  # Ensure `vamr` names are listed at the bottom of the legend
  data_all$endpoint <- factor(data_all$endpoint, levels = c(unique_names_data_short, unique_names_VAMR))

  # Get the wrapped labels for endpoints
  endpoint_levels <- levels(data_all$endpoint)
  wrapped_labels <- sapply(endpoint_levels, function(x) {
    if (nchar(x) > 12) paste(strwrap(x, width = 12), collapse = "\n") else x
  })


  # plot the data
  comparison <- ggplot(data_all, aes(x = ac50, y = top_over_cutoff, fill = endpoint, shape = source #, size = source, color = endpoint
  )) +
    geom_point(size = 4,
               stroke = 0.2) +
    scale_shape_manual(values = c("vamr" = 24, "toxcast" = 21)) +
    scale_color_manual(values = c("black" = "black"), guide = "none") + # black border of the data points and hide an unnecessary color legend
    #scale_size_manual(values = c("vamr" = 5, "toxcast" = 4), guide = "none") +
    #geom_text_repel(aes(label = ifelse(source == "vamr", as.character(endpoint), "")),
    #                size = 3.5, vjust = 2, color = "black", box.padding = 0.23 #, max.overlaps = 100
    #) +
    geom_hline(aes(yintercept = 0), color = "black") +
    geom_vline(aes(xintercept = cytotox_lb), linetype = "dashed", color = "black") +
    annotate("text", x = cytotox_lb, y = max(data_all$top_over_cutoff) + 0.1,
             label = paste0("Cytotox Lower Bound in \u00B5M (", cytotox_lb, ")"), color = "black",
             angle = 270, hjust = 0, vjust = -0.5, size = 5
    ) +
    geom_vline(aes(xintercept = cytotox_median), linetype = "dashed", color = "black") +
    annotate("text", x = cytotox_median, y = max(data_all$top_over_cutoff) + 0.1,
             label = paste0("Cytotox Median in \u00B5M (", cytotox_median, ")"), color = "black",
             angle = 270, hjust = 0, vjust = -0.5, size = 5
    ) +
    scale_x_log10(breaks = c(0.01, 0.1, 1, 10, 100, 1000),
                  labels = scales::label_number(drop0trailing = TRUE)) +
    #scale_y_continuous(
    #  breaks = c(-10, -5, 0, 5, 10, 15, 20, 25)
    #) +
    theme( # Enable a panel border and make it broader
      panel.border = element_rect(color = "black", linewidth = 0.2, fill = NA),
      # Adjust the margins around the plot for a broader frame effect
      plot.margin = margin(20, 20, 20, 20),
      panel.background = element_rect(fill = "white", color = NA),
      plot.background = element_rect(fill = "white", color = NA),
      #panel.grid.major = element_line(color = "grey92", size = 0.5),  # Default major gridlines
      #panel.grid.minor = element_blank(),
      axis.text.y = element_text(size = 20,
                                 colour = "black"),
      axis.text.x = element_text(size = 20,
                                 colour = "black"),
      axis.title = element_text(size = 20,
                                colour = "black",
                                face = "bold"),
      legend.text = element_text(size = 12),
      legend.title = element_text(size = 14, face = "bold"),
      legend.position = "right",
      legend.justification = "top",
      legend.box.just = "top",
      legend.box = "vertical",
      legend.spacing.y = unit(0.4, "cm")
    ) +
    labs(x = "AC50 (\u00B5M)", y = "Scaled Top", fill = "Endpoint", color = "Endpoint", shape = "Assay"
    ) +
    ggtitle(paste0("Assay Comparison ", chemical)) +
    scale_fill_manual(values = endpoint_color,
                      labels = wrapped_labels) +
    guides(fill = guide_legend(ncol = 2, override.aes = list(shape = 21, size = 4, color = "black")))

  if (exists("dnt_ivb_empty") && dnt_ivb_empty) {
    comparison <- comparison +
      annotate(
        "text",
        x = Inf,
        y = Inf,
        label = "No DNT IVB assays found after filtering. \nUsing all ToxCast assays for comparison.",
        hjust = 1, vjust = 1,
        color = "red",
        size = 5,
        fontface = "bold"
      )
  }
  print(comparison)

  if (do_filter == TRUE) {
    assay_name <- "DNT-IVB"
  } else {
    assay_name <- "allToxcastAssays"
  }
  file_name <- paste0(gsub("-", "", Sys.Date()), "_", chemical, "_CompTox_hitcallMin90percent_", assay_name)
  path <- file.path(pathToExp, "result_plots", "C-R_curves", "CompTox", file_name)

  # Save the plot with a larger frame and broader dimensions
  ggsave(paste0(path, ".svg"),
         plot = comparison,
         width = 20,          # Width in inches
         height = 8,          # Height in inches
         dpi = 300)           # High resolution (300 dpi)

  saveRDS(comparison, file = paste0(path, ".rds"))

}

#pathToChems <- "/run/user/1001/gvfs/smb-share:server=isa.intranet.ufz.de,share=extra/tallab/Experiments_new/neuroBEAT/neuroBEAT_pyCharm/chemicals_VAMR4"
#vamr_file <- readRDS("/run/user/1001/gvfs/smb-share:server=isa.intranet.ufz.de,share=extra/tallab/Experiments_new/neuroBEAT/neuroBEAT_pyCharm/chemicals_VAMR4/results/20250903_allEndpoints_allChemicals_newCutoff.rds")

toxcast_summary <- function(pathToChems, vamr_file) {
  # cytotox lower bound in µM
  cytotox_tbl <- data.frame(chemical = c("BDE-99", "Chlorpyrifos", "5,5-Diphenylhydantoin", "Haloperidol", "Hexachlorophene", "Ketamine", "Maneb", "Nicotine", "PFOA", "Tebuconazole", "Trichlorfon", "Triethyltin bromide"),
                            lower_bound = c(10.401, 24.064, 1000, 11.154, 5.889, NA, 1000, 1000, 1000, 18.786, 1000, 1.078),
                            median = c(31.346, 72.526, NA, 33.618, 17.748, NA, NA, NA, NA, 56.618, NA, 3.249)
  )

  exp_list <- list.dirs(path = pathToChems, recursive = FALSE, full.names = FALSE)
  #exp_list <- exp_list[-c(2, 5)]

  for (exp_name in exp_list) {
    pathToExp <- file.path(pathToChems, exp_name)

    startUpFunction(pathToFunctions = "/home/raabj/PycharmProjects/neurobeat_package/R",
                    pathToExp = file.path("/run/user/1001/gvfs/smb-share:server=isa.intranet.ufz.de,share=extra/tallab/Experiments_new/neuroBEAT/neuroBEAT_pyCharm/developmental/POSITIVES", exp_name)
    )

    vamr_file_allEndp <- list.files(path = file.path(pathToExp, "result_files", "C-R_model"),
                                    pattern = "concentration_response_metrics_allEndpoints.rds",
                                    full.names = TRUE)

    if (length(vamr_file_allEndp) != 0 && file.exists(vamr_file_allEndp)) {
      vamr_file <- readRDS(vamr_file_allEndp)
      if ("chemical" %in% colnames(vamr_file)) {
        if ("name" %in% colnames(vamr_file)) {
          vamr_file <- vamr_file %>%
            mutate(chemical = ifelse(is.na(chemical) & !is.na(name), name, chemical))
        }
      } else if ("name" %in% colnames(vamr_file)) {
        # If only 'name' exists, rename it to 'chemical'
        vamr_file <- vamr_file %>%
          rename(chemical = name)
      }
    } else {
      timeseries_file <- get(load(list.files(path = file.path(pathToExp, "result_files", "C-R_model"),
                                             pattern = ".*phase_C-R_model.rda",
                                             full.names = TRUE)[1]))
      timeseries_file <- timeseries_file %>%
        rename(chemical = name)
      singleValue_file <- readRDS(list.files(path = file.path(pathToExp, "result_files", "C-R_model"),
                                             pattern = "*C-R_model_allSVendpoints.rds",
                                             full.names = TRUE)[1])
      vamr_file <- bind_rows(timeseries_file, singleValue_file) %>%
        mutate(endpoint = ifelse(endpoint == "ASR_2_3", "ASR2/3", endpoint),
               endpoint = ifelse(endpoint == "ASH_1_5", "ASH1/5", endpoint))
      # Save dataframe for all endpoints
      filename <- file.path(pathToExp, "result_files", "C-R_model", "concentration_response_metrics_allEndpoints")
      saveRDS(vamr_file, paste0(filename, ".rds"))
      data.table::fwrite(x = vamr_file,
                         file = paste0(filename, ".csv"))
    }

    #exp_file <- vamr_file %>%
    #  #  filter(chemical == exp_name) %>%
    #  filter(hitcall > 0.75, ac50 > acc)

    # skip if no rows in vamr_file (endpoints are not hits or acc higher than ac50
    #if (nrow(exp_file) == 0) next


    cytotox_lb <- cytotox_tbl %>%
      filter(chemical == unique(vamr_file$chemical)) %>%
      pull(lower_bound)

    cytotox_median <- cytotox_tbl %>%
      filter(chemical == unique(vamr_file$chemical)) %>%
      pull(median)

    Assay_comparison(vamr_file = vamr_file, cytotox_lb = cytotox_lb, cytotox_median = cytotox_median, pathToExp = pathToExp, do_filter = TRUE)

  }
}