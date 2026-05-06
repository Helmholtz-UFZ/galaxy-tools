#' Standardize logsheets
#'
#' This function can transform old logsheets to the new standardized logsheet format.
#'
#' @param pathToExp Character string. Path to the experiment directory containing necessary subdirectories for input and output
#'
#' @export


logsheet_adapt <- function(pathToExp){
  # avoid scientific notation
  options(scipen = 999)

  pathToLogsheetFolder <- file.path(pathToExp, "logsheets")

  if (!dir.exists(pathToLogsheetFolder)){
    stop("folder doesn't exist")
  }
  
  logsheet_list <- list.files(path = pathToLogsheetFolder, full.names = TRUE)
  print(paste("Number of files: ", length(logsheet_list)))
  
  for (i in seq_along(logsheet_list)) {
    #i <- 4
    file_path <- logsheet_list[i]
    
    if(!file.exists(file_path)){
      warning(paste("file doesn't exist"))
    }

    #Read file
    logsheet <- data.table::fread(file_path)
    logsheet <- as.data.frame(lapply(logsheet, function(x) {
      if (all(grepl("^-?[0-9.]+(e-?[0-9]+)?$", x, ignore.case = TRUE))) { # Check for numeric values and scientific notation
      # if the values are numeric and in scientific notation, convert them to decimal notation
        sapply(x, function(value) {
          num <- as.numeric(value)
          # only extract exponent if it is in scientific notation
          if (grepl("e-", value, ignore.case = TRUE)) {
            exponent <- as.numeric(sub(".*e-", "", value, ignore.case = TRUE))
            sprintf(paste0("%.", exponent, "f"), num)
          } else {
            num
          }
        })
      } else {
        x
      }
    }))


    # If well column has values A1,A2,.. insert 0 -> A01, A02,..
    for (j in seq_len(nrow(logsheet))) {
      if (grepl("^[A-Z][1-9]$", logsheet[j, "well"])) {
        # add 0 between first and second captured group from the regex
        logsheet[j, "well"] <- sub("^([A-Z])([1-9])$", "\\10\\2", logsheet[j, "well"])
      }
    }


    #unify format
    # Check if csv or txt file
    if (grepl("\\.csv$", file_path)){
      logsheet_sub <- logsheet

      # change names of specific columns
      colnames(logsheet_sub)[colnames(logsheet_sub) == "conc"] <- "var1"
      colnames(logsheet_sub)[colnames(logsheet_sub) == "usability_animal"] <- "phenotype"
      colnames(logsheet_sub)[colnames(logsheet_sub) == "plateID"] <- "plate_ID"

      # delete uM in cells
      logsheet_sub$var1 <- sub("uM", "", logsheet_sub$var1)

      # add columns
      logsheet_sub <- add_column(logsheet_sub, var2 = "var2"#, var3 = "var3"
      )

      # determine sequence of columns
      logsheet_sub <- logsheet_sub %>% dplyr::select(exp_ID, plate_ID, chemical, well,location, var1, var2, # var3,
                                                     phenotype)

      # save as csv file
      output_folder <- file.path(pathToExp, "result_logsheets_for_animallist_creation")
      #experiment_folder <- file.path(output_folder, exp.name)
      if (!dir.exists(output_folder)) {   # changed experiment_folder to output_folder
        dir.create(output_folder, recursive = TRUE)
      }
      file_name <- paste0(sub("\\.txt$", "", basename(file_path)), "_adapted.csv")
      file_name2 <- paste0(sub("\\.txt$", "", basename(file_path)), "_adapted.rda")
      print(file_name)
      output_file <- file.path(output_folder, file_name)
      print(output_file)
      output_file2 <- file.path(output_folder, file_name2)
      print(output_file2)
      fwrite(logsheet_sub, output_file)
      save(logsheet_sub, file = output_file2)

      print(paste("adapted logsheet created: ", i, " of ", length(logsheet_list)))

    }else if (grepl("\\.txt$", file_path)){

      # delete not needed columns
      logsheet_sub <- subset(logsheet, select = -c(CASRN, DTXSID, VAST))


      # change names of specific columns
      colnames(logsheet_sub)[colnames(logsheet_sub) == "phenotype_0.normal_1.no_swim_bladder_2.abnormal_3.1.2_4.dead_5.other"] <- "phenotype"
      logsheet_sub$plate_ID <- logsheet_sub$experiment_ID
      #colnames(logsheet_sub)[colnames(logsheet_sub) == "experiment_ID"] <- "plate_ID"
      colnames(logsheet_sub)[colnames(logsheet_sub) == "experiment_ID"] <- "experiment"
      colnames(logsheet_sub)[colnames(logsheet_sub) == "L_number"] <- "exp_ID"
      colnames(logsheet_sub)[colnames(logsheet_sub) == "concentration_uM"] <- "var1"

      # if concentrations are not numeric
      logsheet_sub <- logsheet_sub %>%
        mutate(var1 = as.numeric(gsub(",", ".", var1)))

      # add letter to experiment_ID to transform it into plate_ID
      logsheet_sub$plate_ID <- paste0(logsheet_sub$plate_ID, LETTERS[i])

      # add columns var2, var2 and sequential location identifiers
      logsheet_sub <- add_column(logsheet_sub, var2 = "var2", #var3 = "var3",
                                 location = sprintf("Loc%02d", seq_len(nrow(logsheet_sub))))

      # determine sequence of columns
      logsheet_sub <- logsheet_sub %>% dplyr::select(exp_ID, plate_ID, chemical, well,location, var1, var2, # var3,
                                                     phenotype, experiment)

      # save as csv file
      output_folder <- file.path(pathToExp, "result_logsheets_for_animallist_creation")
      #experiment_folder <- file.path(output_folder, exp.name)
      if (!dir.exists(output_folder)) {   # changed experiment_folder to output_folder
        dir.create(output_folder, recursive = TRUE)
      }
      file_name <- paste0(sub("\\.txt$", "", basename(file_path)), "_adapted.csv")
      file_name2 <- paste0(sub("\\.txt$", "", basename(file_path)), "_adapted.rda")
      print(file_name)
      output_file <- file.path(output_folder, file_name)
      print(output_file)
      output_file2 <- file.path(output_folder, file_name2)
      print(output_file2)
      fwrite(logsheet_sub, output_file)
      save(logsheet_sub, file = output_file2)

      print(paste("adapted logsheet created: ", i, " of ", length(logsheet_list)))

    }else{
      print("any format")
    }

  }
}