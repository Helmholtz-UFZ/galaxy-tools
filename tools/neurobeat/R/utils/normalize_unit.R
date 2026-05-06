normalize_unit <- function(x) {
  if (is.null(x)) return("")
  x <- trimws(x)

  # treat empty / unitless
  if (tolower(x) %in% c("", "none")) return("")

  # convert ASCII micro prefix to Unicode µ
  x <- gsub("^u(?=[A-Za-z])", "\u00B5", x, perl = TRUE)

  x
}