#' Fit linear model and save results
#'
#' Fits a linear model to experimental data, generates predictions, and saves
#' model objects and augmented data. Includes an interaction with `var2` when
#' multiple `var2` levels are present.
#'
#' @param data Data frame containing columns `value`, `var1`, `var2`, `endpoint`, `chemical`, and `experiment`.
#' @param pathToExp Character string. Path to the experiment directory containing necessary subdirectories for input and output.
#'
#' @return A list of length two: the fitted `lm` model and the augmented data frame with predictions and metadata.
#'
#' @examples
#' \dontrun{
#' sample_data <- data.frame(
#'   value = c(10, 15, 12, 18, 20, 25),
#'   var1 = c("A", "B", "A", "B", "A", "B"),
#'   var2 = c("X", "X", "Y", "Y", "Z", "Z"),
#'   endpoint = "growth",
#'   chemical = "compound1",
#'   experiment = "exp001"
#' )
#'
#' results <- lm_func(sample_data, "/path/to/experiment")
#' summary(results[[1]])
#' head(results[[2]])
#' }
#'
#' @export


lm_func <- function(data, pathToExp) {
  # Check and convert individual variables
  if (!is.factor(data$var1)) {
    data$var1 <- factor(data$var1)
  }
  if (!is.factor(data$var2)) {
    data$var2 <- factor(data$var2)
  }

  # LM
  if (length(unique(data$var2)) > 1) {
    lm_model <- lm(value ~ var1 + var2 + var1:var2, data = data)
  } else {
    lm_model <- lm(value ~ var1, data = data)
  }

  # save the model
  endpoint <- unique(data$endpoint)
  endpoint <- ifelse(endpoint == "ASR2/3", "ASR_2_3", endpoint)
  endpoint <- ifelse(endpoint == "ASH1/5", "ASH_1_5", endpoint)

  filename_lmModel <- file.path(pathToExp, "result_files", "LM",
                                paste0(gsub("-", "", Sys.Date()), "_",
                                       unique(data$chemical), "_", endpoint, "_", unique(data$experiment), "_model.rds"))
  saveRDS(lm_model, filename_lmModel)

  # save model summary
  filename_model_summary <- file.path(pathToExp, "result_files", "LM",
                                      paste0(gsub("-", "", Sys.Date()), "_",
                                             unique(data$chemical), "_", endpoint, "_", unique(data$experiment), "_LM_summary.txt"))
  sink(filename_model_summary)
  print(summary(lm_model))
  sink()


  # predict
  lm_pred <- predict(lm_model, newdata = data)

  data$prediction <- lm_pred
  data$model <- "LM"
  data$AIC <- AIC(lm_model)

  # save the data with predictions (data)
  filename_lm_df <- file.path(pathToExp, "result_files", "LM",
                              paste0(gsub("-", "", Sys.Date()), "_",
                                     unique(data$chemical), "_", endpoint, "_", unique(data$experiment), "_LM_DATA"))
  saveRDS(data, paste0(filename_lm_df, ".rds"))
  data.table::fwrite(x = data,
                     file = paste0(filename_lm_df, ".csv"),
                     sep = ",")

  output_list <- list(lm_model, data)
  return(output_list)
}
