library("drc")

data = read.csv(file.choose(), header = TRUE)

# Define a function to fit different dose-response models
fit_models <- function(data) {
  models <- list(
    LL.2 = drm(lethal ~ concentration, data = data, fct = LL.2(), type = "binomial"),
    LL.3 = drm(lethal ~ concentration, data = data, fct = LL.3(), type = "binomial"),
    LL.4 = drm(lethal ~ concentration, data = data, fct = LL.4(), type = "binomial"),
    LL.5 = drm(lethal ~ concentration, data = data, fct = LL.5(), type = "binomial"),
    W1.4 = drm(lethal ~ concentration, data = data, fct = W1.4(), type = "binomial"),
    W2.4 = drm(lethal ~ concentration, data = data, fct = W2.4(), type = "binomial")
  )
  return(models)
}

# Define a function to calculate AIC and select the best model
select_best_model <- function(models) {
  aic_values <- sapply(models, AIC)
  best_model_name <- names(which.min(aic_values))
  best_model <- models[[best_model_name]]
  return(list(name = best_model_name, model = best_model))
}

# Define a function to calculate EC values for a given model
calculate_ec_values <- function(model) {
  ec50 <- ED(model, 50, type = "relative")
  ec25 <- ED(model, 25, type = "relative")
  ec10 <- ED(model, 10, type = "relative")
  return(list(EC50 = ec50, EC25 = ec25, EC10 = ec10))
}

# Define a function to plot dose-response curve using base R
plot_dose_response <- function(model, data, ec_values) {
  # Generate a fine grid of concentration values for smooth curve
  concentration_grid <- seq(min(data$concentration), max(data$concentration), length.out = 100)
  predicted_values <- predict(model, newdata = data.frame(concentration = concentration_grid), type = "response")
  
  # Plot the observed data points
  plot(data$concentration, data$lethal, col = "red", pch = 16, xlab = "Concentration", ylab = "Effect", main = "Dose-Response Curve")
  
  # Plot the fitted dose-response curve
  lines(concentration_grid, predicted_values, col = "blue")
  
  # Add vertical lines for EC10 and EC50
  abline(v = ec_values$EC10[1], col = "green", lty = 2)
  abline(v = ec_values$EC50[1], col = "purple", lty = 2)
}

# Main analysis function
dose_response_analysis <- function(data) {
  models <- fit_models(data)
  best_model_info <- select_best_model(models)
  ec_values <- calculate_ec_values(best_model_info$model)
  plot_dose_response(best_model_info$model, data, ec_values)
  
  return(list(best_model = best_model_info$name, ec_values = ec_values))
}

# Example usage
# Assuming 'data' is your dataframe with 'concentration' and 'lethal' columns
result <- dose_response_analysis(data)
print(result$best_model)
print(result$ec_values)

