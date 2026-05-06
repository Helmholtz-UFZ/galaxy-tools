#' Function to load the required packages
#'
#'

load_packages <- function() {
  # updated packages
   listOfPackages <- c("scales","ggplot2", "RColorBrewer", "dplyr", "data.table",
                      "emmeans", "mgcv", "tibble", "stats", "argparse", "stringr",
                      "svglite", "tcplfit2", "longitudinalData", "tidyr", "purrr", "cowplot", "gridExtra", "ggh4x"
  )

  #listOfPackages <- c("reshape2", "scales", "ggrepel", "ggplot2", "RColorBrewer", "car", "dplyr", "data.table",
  #                    "multcompView", "lme4", "emmeans", "tidyverse", "mgcv", "tibble", "roxygen2", "longitudinalData",
  #                    "tcpl", "tcplfit2", "performance", "reformulas", "betareg"#, "argparse", "reticulate"
  #)
  #listOfPackages <- c("reshape2", "ggplot2", "car", "dplyr", "data.table", "readxl",
  #                    "openxlsx", "multcompView", "lme4", "emmeans", "tidyverse",
  #                    "mgcv", "readxl", "tibble", "roxygen2", "longitudinalData", "tcpl"#, "argparse" , "reticulate"
  #)

  ## Now load or install&load all
  package.check <- lapply(
    listOfPackages,
    FUN = function(x) {
      if (!require(x, character.only = TRUE)) {
        #install.packages(x, dependencies = TRUE)
        library(x, character.only = TRUE)
      }
    }
  )
}
