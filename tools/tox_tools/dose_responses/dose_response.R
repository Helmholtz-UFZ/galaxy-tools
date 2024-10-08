library(drc)
library(ggplot2)

fit_models <- function(data, concentration_col, response_col) {
    models <- list(
        LL.2 = drm(data[[response_col]] ~ data[[concentration_col]], data = data, fct = LL.2(), type = "binomial"),
        LL.3 = drm(data[[response_col]] ~ data[[concentration_col]], data = data, fct = LL.3(), type = "binomial"),
        LL.4 = drm(data[[response_col]] ~ data[[concentration_col]], data = data, fct = LL.4(), type = "binomial"),
        LL.5 = drm(data[[response_col]] ~ data[[concentration_col]], data = data, fct = LL.5(), type = "binomial"),
        W1.4 = drm(data[[response_col]] ~ data[[concentration_col]], data = data, fct = W1.4(), type = "binomial"),
        W2.4 = drm(data[[response_col]] ~ data[[concentration_col]], data = data, fct = W2.4(), type = "binomial")
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

plot_dose_response <- function(model, data, ec_values, concentration_col, response_col, plot_file) {
    concentration_grid <- seq(min(data[[concentration_col]]), max(data[[concentration_col]]), length.out = 100)
    prediction_data <- data.frame(concentration_grid)
    colnames(prediction_data) <- concentration_col
    predicted_values <- predict(model, newdata = prediction_data, type = "response")
    prediction_data$response <- predicted_values
    p <- ggplot(data, aes_string(x = concentration_col, y = response_col)) +
        geom_point(color = "red") +
        geom_line(data = prediction_data, aes_string(x = concentration_col, y = "response"), color = "blue") +
        geom_vline(xintercept = ec_values$EC10[1], color = "green", linetype = "dashed") +
        geom_vline(xintercept = ec_values$EC50[1], color = "purple", linetype = "dashed") +
        labs(title = "Dose-Response Curve", x = "Concentration", y = "Effect") +
        theme_minimal() +
        theme(
            panel.background = element_rect(fill = "white", color = NA),
            plot.background = element_rect(fill = "white", color = NA)
        )

    ggsave(filename = paste0("./test-data/", plot_file), plot = p, device = "jpg")
}

dose_response_analysis <- function(data, concentration_col, response_col, plot_file, ec_file) {
    concentration_col <- colnames(data)[as.integer(concentration_col)]
    response_col <- colnames(data)[as.integer(response_col)]
    models <- fit_models(data, concentration_col, response_col)
    best_model_info <- select_best_model(models)
    ec_values <- calculate_ec_values(best_model_info$model)
    plot_dose_response(best_model_info$model, data, ec_values, concentration_col, response_col, plot_file)

    ec_data <- data.frame(
        EC10 = ec_values$EC10[1],
        EC25 = ec_values$EC25[1],
        EC50 = ec_values$EC50[1]
    )
    write.table(paste0("./test-data/",ec_data), ec_file, sep = "\t", row.names = FALSE, col.names = TRUE, quote = FALSE)

    return(list(best_model = best_model_info$name, ec_values = ec_values))
}

args <- commandArgs(trailingOnly = TRUE)

data_file <- args[1]
concentration_col <- args[2]
response_col <- args[3]
plot_file <- args[4]
ec_file <- args[5]

data <- read.csv(data_file, header = TRUE, sep = "\t")
dose_response_analysis(data, concentration_col, response_col, plot_file, ec_file)
