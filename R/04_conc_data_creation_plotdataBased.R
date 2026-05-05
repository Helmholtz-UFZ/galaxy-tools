#' Create Concentration Data with Color Assignments
#'
#' This function uses pre-processed data to create a dataset with unique
#' chemical-variable combinations to assigns colors for visualization.
#' Results are saved to both RDS and CSV formats.
#'
#' @param pathToExp Character string. Path to the experiment directory containing necessary
#' subdirectories for input and output
#' @param unit_var1 Character string. Unit of measurement for variable 1 (var1).
#' If var1 does not have a unit unit_var1 = NA.
#' @param review_colors Boolean. TRUE if you want to assign specific colors for each var1
#' @param control_var1 Character/Numeric. Control value for var1
#' @param control_var2 Character/Numeric. Control value for var2 (optional, only if var2 varies)
#'
#' @return A data frame containing:
#'   \describe{
#'     \item{chemical}{Factor. Chemical identifier}
#'     \item{var1}{Factor. Variable 1 values (sorted)}
#'     \item{var2}{Character. Variable 2 values}
#'     \item{experiment}{Character. Experiment identifier}
#'     \item{unit}{Character. Unit of measurement for var1}
#'     \item{var1_numeric}{Numeric. Numeric version of var1 for sorting}
#'     \item{color}{Character. Color assignment for plotting (grey for var1=0,
#'                  Set3 palette or hue colors for non-zero values)}
#'   }
#'
#' @details
#' The function performs the following steps:
#' \itemize{
#'   \item Loads the most recent plotdata_timeseries.rda file from result_files
#'   \item Extracts unique combinations of chemical, var1, var2, and experiment
#'   \item Sorts data by chemical and numeric var1 values
#'   \item Assigns colors using RColorBrewer Set3 palette (for <12 combinations)
#'     or scales hue palette (for ≥12 combinations)
#'   \item Sets grey color for zero var1 values
#'   \item Saves results as both RDS and CSV files in the aesthetic_files directory
#' }
#'
#' @note
#' \itemize{
#'   \item The function expects plotdata_timeseries.rda files with YYYYMMDD date
#'     prefixes in the filename
#'   \item Creates 'aesthetic_files' directory if it doesn't exist (through saveRDS/fwrite)
#'   \item Sets scipen option to 999 to avoid scientific notation
#' }
#'
#' @examples
#' # Create concentration data for an experiment
#' conc_data <- conc_data_creation("/path/to/experiment", "\u00B5M")
#'
#' # The function will save files to:
#' # /path/to/experiment/aesthetic_files/conc_data.rds
#' # /path/to/experiment/aesthetic_files/conc_data.csv
#'
#' @seealso
#' \code{\link[RColorBrewer]{brewer.pal}}, \code{\link[scales]{hue_pal}},
#' \code{\link[data.table]{fwrite}}
#'
#' @export


conc_data_creation <- function(pathToExp, unit_var1, review_colors = FALSE, control_var1 = 0, control_var2 = NULL) {

  # avoid scientific notation
  options(scipen = 999)

  if (file.exists(file.path(pathToExp, "aesthetic_files", "conc_data.csv"))) {
    cat("Reading conc_data file \n")
    conc_data <- as.data.frame(data.table::fread(file.path(pathToExp, "aesthetic_files", "conc_data.csv"),
                                                 check.names = FALSE))

    plotdata_files <- list.files(file.path(pathToExp, "result_files"),
                                 full.names = TRUE, pattern = "plotdata_timeseries.rda")
    plotdata_file <- plotdata_files[which.max(as.Date(substr(basename(plotdata_files), 1, 8), "%Y%m%d"))]
    plotdata <- get(load(plotdata_file))
    plotdata$var1 <- factor(plotdata$var1)
    plotdata$var2 <- factor(plotdata$var2)

    conc_data <- file_correct(conc_data, plotdata)

    return(conc_data)

  } else {
    cat("Creating conc_data file")
    plotdata_files <- list.files(file.path(pathToExp, "result_files"),
                                 full.names = TRUE, pattern = "plotdata_timeseries.rda")
    plotdata_file <- plotdata_files[which.max(as.Date(substr(basename(plotdata_files), 1, 8), "%Y%m%d"))]
    plotdata <- get(load(plotdata_file))
    plotdata$var1 <- factor(plotdata$var1)
    plotdata$var2 <- factor(plotdata$var2)

    # Avoid scientific notation
    options(scipen = 999)

    # Get unique combinations of chemical and var1
    unique_combinations <- unique(plotdata[, c("chemical", "var1", "var2", "experiment")])

    # Check if var2 has multiple values
    unique_var2_count <- length(unique(unique_combinations$var2))
    if (unique_var2_count > 1 && !is.null(control_var2)) {
      message(paste0("Found ", unique_var2_count, "unique var2 values. Using control_var2 = ", control_var2))
    } else if (unique_var2_count > 1 && is.null(control_var2)) {
      message(paste0("Found ", unique_var2_count, " unique var2 values, but no control_var2 specified.\n"))
      message("var2 values will be sorted alphabetically.\n")
    } else {
      message("var2 has constant value: ", unique(unique_combinations$var2)[1], "\n")
    }

    # Check if var1 is numeric
    var1_is_numeric <- tryCatch({
      as.numeric(as.character(unique_combinations$var1))
      TRUE
    }, warning = function(w) FALSE, error = function(e) FALSE)

    if (var1_is_numeric) {
      # for numeric var1, sort numerically
      unique_combinations$var1_numeric <- as.numeric(as.character(unique_combinations$var1))
      unique_combinations$var1_order <- unique_combinations$var1_numeric
    } else {
      # for non-numeric var1 values create custom ordering with control first
      unique_var1 <- unique(unique_combinations$var1)

      if (control_var1 %in% unique_var1) {
        # put control first, then sort others alphabetically
        other_var1 <- sort(unique_var1[unique_var1 != control_var1])
        var1_levels <- c(control_var1, other_var1)
      } else {
        # No contorl found, sort alphabetically
        var1_levels <- sort(unique_var1)
        warning("Control value for var1 not found in data \n")
      }
      unique_combinations$var1 <- factor(unique_combinations$var1, levels = var1_levels)
      unique_combinations$var1_numeric <- NA
      unique_combinations$var1_order <- as.character(unique_combinations$var1)
    }

    # Handle var2 ordering (only if it varies)
    if (unique_var2_count > 1) {
      if (!is.null(control_var2)) {
        unique_var2 <- unique(unique_combinations$var2)

        if (control_var2 %in% unique_var2) {
          # Put control first, then sort others alphabetically
          other_var2 <- sort(unique_var2[unique_var2 != control_var2])
          var2_levels <- c(control_var2, other_var2)
          unique_combinations$var2 <- factor(unique_combinations$var2, levels = var2_levels)
          unique_combinations$var2_order <- as.numeric(unique_combinations$var2)
        } else {
          warning("Control value for var2 not found in data \n")
          unique_combinations$var2_order <- match(unique_combinations$var2, sort(unique(unique_combinations$var2)))
        }
      } else {
        # No var2 control specified, sort alphabetically
        unique_combinations$var2_order <- match(unique_combinations$var2, sort(unique(unique_combinations$var2)))
      }
    } else {
      # var2 is constant, no need to order
      unique_combinations$var2_order <- 1
    }

    # Sort data: chemical, then var1, then var2 (if it varies)
    if (var1_is_numeric) {
      if (unique_var2_count > 1) {
        unique_combinations <- unique_combinations[order(unique_combinations$chemical,
                                                         unique_combinations$var1_numeric,
                                                         unique_combinations$var2_order),]
      } else {
        unique_combinations <- unique_combinations[order(unique_combinations$chemical,
                                                         unique_combinations$var1_numeric),]
      }
    } else {
      if (unique_var2_count > 1) {
        unique_combinations <- unique_combinations[order(unique_combinations$chemical,
                                                         unique_combinations$var1_order,
                                                         unique_combinations$var2_order),]
      } else {
        unique_combinations <- unique_combinations[order(unique_combinations$chemical,
                                                         unique_combinations$var1_order),]
      }
    }

    # Create conc_data
    conc_data <- unique_combinations %>%
      dplyr::mutate(unit = unit_var1,
                    var1 = if (var1_is_numeric) factor(var1_numeric) else var1)


    nonControl_combos <- unique_combinations %>%
      dplyr::select(-experiment) %>%
      distinct() %>%
      dplyr::filter(var1 != control_var1)

    ## Formatting function for matching
    #format_var1 <- function(x) sprintf("%.7f", x)

    # Build color palette
    if (nrow(nonControl_combos) < 12) {
      colors_other <- RColorBrewer::brewer.pal(nrow(nonControl_combos), "Set3")
    } else {
      colors_other <- scales::hue_pal()(nrow(nonControl_combos))
    }

    nonControl_combos$color <- colors_other

    # Join colors back to data
    join_cols <- c("chemical", "var1", "var2")
    if (var1_is_numeric) {
      join_cols <- c("chemical", "var1", "var1_numeric", "var2")
    }
    conc_data <- conc_data %>%
      left_join(nonControl_combos %>% dplyr::select(all_of(join_cols), color),
                by = join_cols) %>%
      dplyr::select(-c(var1_order, var2_order))

    conc_data$color <- ifelse(conc_data$var1 == control_var1, "grey", conc_data$color)

    # Convert to factors (preserves existing order)
    conc_data$var1 <- factor(conc_data$var1)
    conc_data$var2 <- factor(conc_data$var2)

    print(conc_data)

    if (interactive() && review_colors) {
      valid_answer <- FALSE
      while (!valid_answer) {
        answer <- readline("Do you want to assign specific colors to each var1? (y/n): ")
        answer <- tolower(answer)

        if (answer %in% c("y", "n")) {
          valid_answer <- TRUE
        } else {
          message("Please enter 'y' or 'n'.")
        }
      }

      if (answer == "y") {
        message("Writing conc_data.csv for editing at:")
        message(file.path(pathToExp, "aesthetic_files", "conc_data.csv"))
        data.table::fwrite(conc_data, file.path(pathToExp, "aesthetic_files", "conc_data.csv"),
                           row.names = FALSE, quote = FALSE, sep = ",")

        readline("Press ENTER to continue once you are done editing \n")

        # Read the edited file
        conc_data <- as.data.frame(data.table::fread(file.path(pathToExp, "aesthetic_files", "conc_data.csv"),
                                                     check.names = FALSE))

        conc_data <- file_correct(conc_data = conc_data,
                                  plotdata = plotdata)

        cat("Saving adapted conc_data file.\n")

      } else {
        cat("Saving conc_data with random colors. \n")
      }
    }
    # Save final conc_data versions as rds and csv
    saveRDS(object = conc_data, file = file.path(pathToExp, "aesthetic_files", "conc_data.rds"))
    data.table::fwrite(conc_data, file.path(pathToExp, "aesthetic_files", "conc_data.csv"),
                       row.names = FALSE, quote = FALSE, sep = ",")

    cat("File created and saved. \n")
    return(conc_data)
    # return(conc_data, "\u00B5M")
  }
}


file_correct <- function(conc_data, plotdata) {
  # Check if var1 values still match between conc_data and plotdata
  conc_var1 <- sort(unique(as.character(conc_data$var1)))
  plot_var1 <- sort(unique(as.character(plotdata$var1)))


  if (!identical(conc_var1, plot_var1)) {
    missing_in_conc_data <- setdiff(plot_var1, conc_var1)
    extra_in_conc_data <- setdiff(conc_var1, plot_var1)

    message("var1 in conc_data is different from var1 in the plotdata file. \n")
    message("Check conc_data.csv and make sure you did not change var1 values. \n")
    message("The var1 values must be the same as in the logsheets / plotdata. \n")

    if (length(missing_in_conc_data) > 0) {
      message("Values present in plotdata but missing in conc_data: ",
              paste(missing_in_conc_data, collapse = ", "), "\n")
    }

    if (length(extra_in_conc_data) > 0) {
      message("Values present in conc_data but not in plotdata: ",
              paste(extra_in_conc_data, collapse = ", "), "\n")
    }

    stop("Invalid conc_data: var1 values do not match plotdata. \n")
  }

  # Check if var2 values still match between conc_data and plotdata
  conc_var2 <- sort(unique(as.character(conc_data$var2)))
  plot_var2 <- sort(unique(as.character(plotdata$var2)))


  if (!identical(conc_var2, plot_var2)) {
    missing_in_conc_data_var2 <- setdiff(plot_var2, conc_var2)
    extra_in_conc_data_var2 <- setdiff(conc_var2, plot_var2)

    message("var2 in conc_data is different from var2 in the plotdata file. \n")
    message("Check conc_data.csv and make sure you did not change var2 values. \n")
    message("The var2 values must be the same as in the logsheets / plotdata. \n")

    if (length(missing_in_conc_data_var2) > 0) {
      message("Values present in plotdata but missing in conc_data: ",
              paste(missing_in_conc_data_var2, collapse = ", "), "\n")
    }

    if (length(extra_in_conc_data_var2) > 0) {
      message("Values present in conc_data but not in plotdata: ",
              paste(extra_in_conc_data_var2, collapse = ", "), "\n")
    }

    stop("Invalid conc_data: var2 values do not match plotdata. \n")
  }

  #  If values match, make sure var1 and var2 are factors again
  if (!is.factor(conc_data$var1)) {
    conc_data$var1 <- factor(conc_data$var1)
  }
  if (!is.factor(conc_data$var2)) {
    conc_data$var2 <- factor(conc_data$var2)
  }

  return(conc_data)
}
