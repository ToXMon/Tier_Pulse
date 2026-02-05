# =============================================================================
# TierPulse – app.R
# Governance layer – Launcher script for Domino compatibility
# Binds to host 0.0.0.0 and port 8888.
# Runs migrations and seeds on startup.
# =============================================================================

# --- Startup: run migrations and seed ---
message("[TierPulse] Starting application...")

tryCatch({
  source("R/migrate.R")
  run_migrations()
}, error = function(e) {
  message("[TierPulse] Migration warning: ", e$message)
})

tryCatch({
  source("R/seed.R")
  seed_metrics_if_empty()
}, error = function(e) {
  message("[TierPulse] Seed warning: ", e$message)
})

# --- Launch Shiny ---
message("[TierPulse] Launching Shiny on 0.0.0.0:8888 ...")
shiny::runApp(
  appDir = "./",
  port   = 8888L,
  host   = "0.0.0.0",
  launch.browser = FALSE
)
