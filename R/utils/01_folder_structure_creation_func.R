#' Create Folder Structure
#'
#' This function creates subfolders to organize the storage locations for input and output files,
#' ensuring a structured file system environment.
#'
#' @param path.to.exp
#' A character string variable specifying the path where the subfolders should be crated.
#'
#' @export


folder_struct <- function(pathToExp) {
# NOTE: works only in R studio
  #pathToExp <- pathToExp

  cat("Creating folder structure at: ", pathToExp, "\n")

  if(!dir.exists(pathToExp)){
    dir.create(pathToExp)
  }

  # create new plot folders using R
  
  # IF the folder does not exist yet, create it
  # if it exists, do nothing
  if(!file.exists(file.path(pathToExp, "data_for_analysis"))){
    
    dir.create(file.path(pathToExp, "data_for_analysis"))
  }
  
  if(!file.exists(file.path(pathToExp, "logsheets"))){
    
    dir.create(file.path(pathToExp, "logsheets"))
  }
  
  if(!file.exists(file.path(pathToExp, "aesthetic_files"))){
    
    dir.create(file.path(pathToExp, "aesthetic_files"))
  }


  if(!file.exists(file.path(pathToExp, "raw_data_ZebraBox"))){
    dir.create(file.path(pathToExp, "raw_data_ZebraBox"))
  }
  
  if(!file.exists(file.path(pathToExp, "ZebraBox_output"))){
    dir.create(file.path(pathToExp, "ZebraBox_output"))
  }

  if(!file.exists(file.path(pathToExp, "result_files"))){
    dir.create(file.path(pathToExp, "result_files"))
    dir.create(file.path(pathToExp, "result_files", "gam"))
   # dir.create(file.path(pathToExp, "result_files", "mixed_models"))
   # dir.create(file.path(pathToExp, "result_files", "ASR"))
   # dir.create(file.path(pathToExp, "result_files", "VSR"))
    dir.create(file.path(pathToExp, "result_files", "C-R_model"))
    dir.create(file.path(pathToExp, "result_files", "timeseries_plot_df_per_var1"))
    dir.create(file.path(pathToExp, "result_files", "intervals"))
    dir.create(file.path(pathToExp, "result_files", "LM"))
  }
  
  if(!file.exists(file.path(pathToExp, "result_logsheets_for_animallist_creation"))){
    dir.create(file.path(pathToExp, "result_logsheets_for_animallist_creation"))
  }
  
  if(!file.exists(file.path(pathToExp, "result_plots"))){
    dir.create(file.path(pathToExp, "result_plots"))
    dir.create(file.path(pathToExp, "result_plots", "gam"))
    dir.create(file.path(pathToExp, "result_plots", "phase_boxplots"))
    dir.create(file.path(pathToExp, "result_plots", "timeseries"))
    #dir.create(file.path(pathToExp, "result_plots", "VSR"))
    #dir.create(file.path(pathToExp, "result_plots", "ASR"))
    #dir.create(file.path(pathToExp, "result_plots", "survival"))
    dir.create(file.path(pathToExp, "result_plots", "individual_assays_timeseries"))
    dir.create(file.path(pathToExp, "result_plots", "LM"))
    dir.create(file.path(pathToExp, "result_plots", "C-R_curves"))
    #dir.create(file.path(pathToExp, "result_plots", "C-R_curves", "Frechet_plots"))
    dir.create(file.path(pathToExp, "result_plots", "C-R_curves", "CompTox"))
    #dir.create(file.path(pathToExp, "result_plots", "intervals"))
  }
}