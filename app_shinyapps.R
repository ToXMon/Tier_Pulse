# =============================================================================
# TierPulse – app_shinyapps.R
# Launcher script for ShinyApps.io deployment (no PostgreSQL)
# Uses in-memory stub data instead of database connection
# 
# To deploy to ShinyApps.io:
# 1. Make sure you have the rsconnect package: install.packages("rsconnect")
# 2. Set up your ShinyApps.io account: rsconnect::setAccountInfo(...)
# 3. Deploy: rsconnect::deployApp(appName = "tierpulse", appFiles = c("app_shinyapps.R", "ui.R", "server.R", "R/"))
# 
# Or rename this file to app.R and deploy normally
# =============================================================================

message("[TierPulse] Starting application in ShinyApps.io stub mode...")

# Use stub database functions instead of real PostgreSQL
source("R/db_stub.R")

# Initialize mock data
init_mock_data()

# Source the logic layer (which uses db.R interface)
source("R/logic.R")

# Launch Shiny
message("[TierPulse] Launching Shiny app...")
shiny::runApp(
  appDir = ".",
  launch.browser = FALSE
)
