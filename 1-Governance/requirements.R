# =============================================================================
# TierPulse – requirements.R
# Governance layer – Install required R packages
# Run this script once before launching the app:
#   Rscript requirements.R
# =============================================================================

packages <- c(
  "shiny",
  "bslib",
  "DT",
  "DBI",
  "RPostgreSQL",
  "lubridate",
  "dplyr"
)

install_if_missing <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    message(paste0("Installing: ", pkg))
    install.packages(pkg, repos = "https://cran.r-project.org")
  } else {
    message(paste0("Already installed: ", pkg))
  }
}

invisible(lapply(packages, install_if_missing))
message("All required packages are installed.")
