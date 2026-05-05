#' Read all aesthetic files
#'
#' This function reads all aesthetic files that are needed in later functions to create plots
#'
#' @param conc_data This is a character string with the filepath to the file, which sets colors for each concentration
#' @param assay_data This is a character string with the filepath to the file, that defines the start and end of the
#'                   individual assays, the colors and positions of the assay labels and the scale of the boxplots of
#'                   the individual assays
#' @param acoustic_stimuli  This is a character string with the filepath to the file for creating coloured lines and
#'                          boxes for applied stimuli
#' @param stimuli_classes Character string specifying the file path to the file containing the stimuli classes for the legend
#' @param stimuli_info Character string containing the file path to the file with assay and stimuli info per second
#'
#' @export

read_aesthetics <- function(#conc_data,
                            assay_data_indiv,
                            assay_data,
                            acoustic_stimuli,
                            acoustic_stimuli_indiv,
                            stimuli_classes,
                            stimuli_info,
                            assay_colors) {

 # assign('conc_data', as.data.frame(data.table::fread(conc_data,
 #                                                     check.names = FALSE)),
 #        envir = .GlobalEnv)

  assign('assay_data', as.data.frame(data.table::fread(assay_data_indiv,
                                                       check.names = FALSE)),
         envir = .GlobalEnv)

  assign('assay_data_whole_timeseries', as.data.frame(data.table::fread(assay_data,
                                                                        check.names = FALSE)),
         envir = .GlobalEnv)

  assign('acoustic_stimuli', as.data.frame(data.table::fread(acoustic_stimuli,
                                                             check.names = FALSE)),
         envir = .GlobalEnv)

  assign('acoustic_stimuli_indiv', as.data.frame(data.table::fread(acoustic_stimuli_indiv,
                                                                   check.names = FALSE)),
         envir = .GlobalEnv)

  assign('stimuli_classes', as.data.frame(data.table::fread(stimuli_classes,
                                                            check.names = FALSE)),
         envir = .GlobalEnv)

  assign('stimuli_info', as.data.frame(data.table::fread(stimuli_info,
                                                         check.names = FALSE)),
         envir = .GlobalEnv)

  assign('assay_colors', as.data.frame(data.table::fread(assay_colors,
                                                         check.names = FALSE)),
         envir = .GlobalEnv)
}
