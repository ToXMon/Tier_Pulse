# =============================================================================
# TierPulse – requirements_shinyapps.R
# Install required R packages for ShinyApps.io deployment
# Excludes PostgreSQL packages (using stub mode)
# =============================================================================

packages <- c(
  "shiny",
  "bslib",
  "DT",
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
message("All required packages for ShinyApps.io are installed.")
