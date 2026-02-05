#!/usr/bin/env Rscript
# =============================================================================
# TierPulse – deploy_to_shinyapps.R
# Deployment script for ShinyApps.io
# 
# Prerequisites:
# 1. Create account at https://www.shinyapps.io/
# 2. Install rsconnect: install.packages("rsconnect")
# 3. Configure credentials: 
#    rsconnect::setAccountInfo(name="your-account", token="...", secret="...")
# 
# Usage:
#   Rscript deploy_to_shinyapps.R
# =============================================================================

# Check if rsconnect is installed
if (!requireNamespace("rsconnect", quietly = TRUE)) {
  stop("Please install rsconnect package first: install.packages('rsconnect')")
}

library(rsconnect)

# Check if account is configured
accounts <- rsconnect::accounts()
if (nrow(accounts) == 0) {
  stop("No ShinyApps.io account configured. Please run:
  rsconnect::setAccountInfo(name='your-account', token='your-token', secret='your-secret')
  
  Get your credentials from: https://www.shinyapps.io/admin/#/tokens")
}

cat("Deploying TierPulse to ShinyApps.io...\n")
cat("Using account:", accounts$name[1], "\n\n")

# Deploy the app
rsconnect::deployApp(
  appName = "tierpulse",
  appTitle = "TierPulse - SQDCP Performance Management",
  appFiles = c(
    "app_shinyapps.R",
    "ui.R",
    "server.R",
    "R/db_stub.R",
    "R/logic.R",
    "R/modules/"
  ),
  appPrimaryDoc = "app_shinyapps.R",
  launch.browser = TRUE,
  forceUpdate = TRUE
)

cat("\n✓ Deployment complete!\n")
cat("Your app should now be available at: https://", accounts$name[1], ".shinyapps.io/tierpulse\n", sep = "")
