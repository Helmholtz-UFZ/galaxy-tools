library(neuroBEAT)

pathToFunctions <- "/home/raabj/PycharmProjects/neurobeat_package/R"
config <- yaml::read_yaml(file.path(pathToFunctions, "../parameters.yaml"))

neuroBEAT::main(
  pathToExp = config$pathToExp,
  exp_name = config$exp_name,
  pathToFunctions = pathToFunctions,
  config = config
)