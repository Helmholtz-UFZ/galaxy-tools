# Helper function to get latest file by date in name
get_latest_file <- function(files) {
    dates <- as.Date(substr(basename(files), 1, 8), "%Y%m%d")
    files[which.max(dates)]
  }

# Function to load the respsective data and to format variables
loadData <- function(pathToExp) {
  # Avoid scientific notation
  options(scipen = 999)

  # Load and scale the data
  seconds_data_files <- list.files(path = file.path(pathToExp, "result_files"),
                                   pattern = "*raw_data_seconds.*\\.rda", # oder files are named raw_data_seconds_for_use
                                   full.names = TRUE,
                                   recursive = FALSE
  )
  loaded_objects <- load(file = get_latest_file(seconds_data_files))
  alldata <- get(loaded_objects[1])

  if ("assay_name" %in% colnames(alldata)) {
    alldata <- alldata[!is.na(alldata$assay_name),]
    alldata$endpoint <- alldata$assay_name
  } else if ("endpoint" %in% colnames(alldata)) {
    alldata <- alldata[!is.na(alldata$endpoint),]
  }

  # Format columns
  alldata$endpoint <- factor(alldata$endpoint)

  alldata$value <- as.numeric(alldata$value)

  alldata$var1 <- factor(alldata$var1)

  alldata$var2 <- factor(alldata$var2)

  alldata$animalID <- factor(alldata$animalID)

  alldata <- alldata %>%
    dplyr::filter(endpoint != "Acclimation_1")

  return(alldata)
}