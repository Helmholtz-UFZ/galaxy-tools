library(drc)
library(ggplot2)

fit_models <- function(data, concentration_col, response_col) {
    models <- list(
        LL.2 = drm(data[[response_col]] ~ data[[concentration_col]], data = data, fct = LL.2(), type = "binomial"),
        LL.4 = drm(data[[response_col]] ~ data[[concentration_col]], data = data, fct = LL.4(), type = "binomial"),
        W1.4 = drm(data[[response_col]] ~ data[[concentration_col]], data = data, fct = W1.4(), type = "binomial"),
        W2.4 = drm(data[[response_col]] ~ data[[concentration_col]], data = data, fct = W2.4(), type = "binomial"),
        BC.5 = drm(data[[response_col]] ~ data[[concentration_col]], data = data, fct = BC.5(), type = "binomial")
    )
    return(models)
}

select_best_model <- function(models) {
    aic_values <- sapply(models, AIC)
    best_model_name <- names(which.min(aic_values))
    best_model <- models[[best_model_name]]
    return(list(name = best_model_name, model = best_model))
}

calculate_ec_values <- function(model) {
    ec50 <- ED(model, 50, type = "relative")
    ec25 <- ED(model, 25, type = "relative")
    ec10 <- ED(model, 10, type = "relative")
    return(list(EC50 = ec50, EC25 = ec25, EC10 = ec10))
}

plot_dose_response <- function(model, data, ec_values, concentration_col, response_col, replicate_col, plot_file, compound_name, concentration_unit) {
    # Generate a grid of concentration values for predictions
    concentration_grid <- seq(min(data[[concentration_col]]), max(data[[concentration_col]]), length.out = 100)
    prediction_data <- data.frame(concentration_grid)
    colnames(prediction_data) <- concentration_col

    # Compute predictions with confidence intervals
    predictions <- predict(model, newdata = prediction_data, type = "response", interval = "confidence")
    prediction_data$resp <- predictions[, 1]
    prediction_data$lower <- predictions[, 2]
    prediction_data$upper <- predictions[, 3]

    print(prediction_data)

    # Ensure replicate_col is treated as a factor
    data[[replicate_col]] <- factor(data[[replicate_col]])

    # Create the plot
    p <- ggplot(data, aes_string(x = concentration_col, y = response_col)) +
        geom_point(aes_string(colour = replicate_col)) + # Original data points
        geom_line(data = prediction_data, aes_string(x = concentration_col, y = response_col), color = "blue") + # Predicted curve
        geom_ribbon(data = prediction_data, aes_string(x = concentration_col, ymin = "lower", ymax = "upper"), alpha = 0.2, fill = "blue") + # Confidence intervals
        geom_vline(xintercept = ec_values$EC10[1], color = "green", linetype = "dashed") +
        geom_vline(xintercept = ec_values$EC50[1], color = "red", linetype = "dashed") +
        labs(
            title = paste(compound_name, "- Dose-Response Curve"),
            x = paste("Dose [", concentration_unit, "]"),
            y = "Response %",
            colour = "Replicates"
        ) +
        theme_minimal() +
        theme(
            panel.background = element_rect(fill = "white", color = NA),
            plot.background = element_rect(fill = "white", color = NA)
        )

    # Save the plot to a file
    jpeg(filename = plot_file, width = 480, height = 480, res = 72)
    print(p)
    dev.off()
}

dose_response_analysis <- function(data, concentration_col, response_col, replicate_col, plot_file, ec_file, compound_name, concentration_unit) {
    # Ensure column names are correctly selected
    concentration_col <- colnames(data)[as.integer(concentration_col)]
    response_col <- colnames(data)[as.integer(response_col)]
    replicate_col <- colnames(data)[as.integer(replicate_col)]

    # Fit models and select the best one
    models <- fit_models(data, concentration_col, response_col)
    best_model_info <- select_best_model(models)
    best_model <- best_model_info$model
    best_model_name <- best_model_info$name

    # Calculate EC values
    ec_values <- calculate_ec_values(best_model)

    # Plot the dose-response curve
    plot_dose_response(best_model, data, ec_values, concentration_col, response_col, replicate_col, plot_file, compound_name, concentration_unit)

    # Get model summary and AIC value
    model_summary <- summary(best_model)
    model_aic <- AIC(best_model)

    # Prepare EC values data frame with additional information
    ec_data <- data.frame(
        Metric = c("chemical_name", "EC10", "EC25", "EC50", "AIC"),
        Value = c(compound_name, ec_values$EC10[1], ec_values$EC25[1], ec_values$EC50[1], model_aic)
    )

    # Write EC values, AIC, and model summary to the output file
    write.table(ec_data, ec_file, sep = "\t", row.names = FALSE, col.names = TRUE, quote = FALSE)

    # Append the model summary to the file
    cat("\nModel Summary:\n", file = ec_file, append = TRUE)
    capture.output(model_summary, file = ec_file, append = TRUE)

    return(list(best_model = best_model_name, ec_values = ec_values))
}

args <- commandArgs(trailingOnly = TRUE)

data_file <- args[1]
concentration_col <- args[2]
response_col <- args[3]
replicate_col <- args[4]
plot_file <- args[5]
ec_file <- args[6]
compound_name <- args[7]
concentration_unit <- args[8]

data <- read.csv(data_file, header = TRUE, sep = "\t")
print(data)
dose_response_analysis(data, concentration_col, response_col, replicate_col, plot_file, ec_file, compound_name, concentration_unit)
