\name{neuroBEAT-package}
\alias{neuroBEAT-package}
\alias{neuroBEAT}
\docType{package}
\title{
\packageTitle{neuroBEAT}
}
\description{
\packageDescription{neuroBEAT}
}
\details{
%%  ~~ An overview of how to use the package, ~~
%%  ~~ including the most important functions ~~
}
\author{
\packageAuthor{neuroBEAT}

Maintainer: \packageMaintainer{neuroBEAT}
}
\references{
%%  ~~ Literature or other references for background information ~~
}
\keyword{package}

%% Uncomment below to imitate parts of library(help = neuroBEAT)
%\section{The \file{DESCRIPTION} File}{\packageDESCRIPTION{neuroBEAT}}
%\section{Documentation Index}{\packageIndices{neuroBEAT}}

\seealso{
%%  ~~ Optional links to other man pages, e.g. ~~
%%  ~~ \code{\link[<pkg>:<pkg>-package]{<pkg>}} ~~
}
\examples{

  # simple examples of the most important functions

  \dontrun{
  library(neuroBEAT)

  pathToExp <- "/path/to/experiment"
  exp_name  <- "my_experiment"

  # 1) Preprocess raw data and logsheets
  data_preprocessing(pathToExp = pathToExp, exp_name = exp_name, healthyAnimalScore = 0)

  # 2) Create/inspect concentration table
  conc_data <- conc_data_creation(pathToExp = pathToExp, unit_var1 = "\u00B5M", review_colors
  = FALSE)

  # 3) Timeseries plots (median with MAD)
  doubleVar_timeseries_plotting_median(
  control_var1 = "0", unit_var1 = "\u00B5M", pathToExp = pathToExp, exp_name = exp_name, y_max
  = 8
  )

  # 4) Prepare binned phase data
  phase_data_prep(
  endpoint_list = c("BSL1","BSL2","BSL3","BSL4","VMR1","VMR2","VMR3","VMR4","VMR5"),
  binsize = 60, phase_name = "BSL1_VMR5", exp_name = exp_name, pathToExp = pathToExp
  )

  # 5) Fit GAMM and plot
  model_fit(
  x_axis_title = "Time (s)", y_axis_title = "Summed distance moved (px/min)",
  phase_name = "BSL1_VMR5", exp_name = exp_name, pathToExp = pathToExp, unit_var1 = "\u00B5M"
  )

  # 6) Derive concentration–response metrics
  # a) for time-series endpoints
  CRC_model_phases(phase_name = "BSL1_VMR5", exp_name = exp_name, pathToExp = pathToExp, unit_var1 = "\u00B5M")
  # b) for single-value endpoints
  CRC_LM_double_var(pathToExp = pathToExp, unit_var1 = "\u00B5M", exp_name = exp_name)

  # 7) Box/violin plots
  # a) for time-series endopints
  phase_boxplot_plotting_split_exp(phase_name = "BSL1_VMR5",
                                   y_axis_title = "Motor activity (px/min)",
                                   pathToExp = pathToExp,
                                   unit_var1 = "\u00B5M",
                                   conc_data = conc_data,
                                   var1_def = "c" # for concentration
  )
  # b) with LM statistics for single-value endpoints
  boxplots_LM(pathToExp = pathToExp, unit_var1 = "\u00B5M", exp_name = exp_name)
  }
  }
