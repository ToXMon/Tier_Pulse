# ShinyApps.io Deployment Guide

This guide explains how to deploy TierPulse to ShinyApps.io without requiring a PostgreSQL database.

## Overview

The ShinyApps.io deployment uses an in-memory stub for all database operations, allowing you to explore the frontend functionality without needing to set up a database server.

## Files for ShinyApps.io Deployment

- **app_shinyapps.R** - Main launcher that uses the stub database
- **ui.R** - User interface (symlink to 6-Application/ui.R)
- **server.R** - Server logic (symlink to 6-Application/server.R)
- **R/** - Directory containing all R modules and logic
  - **db_stub.R** - In-memory database stub
  - **logic.R** - Business logic (works with stub)
  - **modules/** - All UI modules

## Quick Deployment Steps

### 1. Install rsconnect package (if not already installed)

```r
install.packages("rsconnect")
```

### 2. Set up your ShinyApps.io account

Go to https://www.shinyapps.io/ and create an account (free tier available).

Then configure your account in R:

```r
rsconnect::setAccountInfo(
  name = "your-account-name",
  token = "your-token",
  secret = "your-secret"
)
```

You can find your token and secret at: https://www.shinyapps.io/admin/#/tokens

### 3. Deploy to ShinyApps.io

```r
# Option 1: Deploy with app_shinyapps.R as the entry point
rsconnect::deployApp(
  appName = "tierpulse",
  appTitle = "TierPulse - SQDCP Performance Management",
  appFiles = c(
    "app_shinyapps.R",
    "ui.R",
    "server.R",
    "R/",
    "requirements_shinyapps.R"
  ),
  appPrimaryDoc = "app_shinyapps.R",
  launch.browser = TRUE
)

# Option 2: Rename app_shinyapps.R to app.R first, then deploy
file.rename("app_shinyapps.R", "app.R")
rsconnect::deployApp(
  appName = "tierpulse",
  appTitle = "TierPulse - SQDCP Performance Management",
  launch.browser = TRUE
)
```

## What Gets Stubbed Out

The in-memory stub (`R/db_stub.R`) provides mock implementations for:

- ✅ Metric definitions (pre-loaded with seed data)
- ✅ Metric entries (created in-memory when you submit data)
- ✅ Issues/Actions/Escalations (created in-memory)
- ✅ Attendance tracking
- ✅ Meeting records
- ✅ All queries and filters

## Limitations

Since this is a stub deployment:

- ⚠️ **Data is not persistent** - All data resets when the app restarts
- ⚠️ **Single session only** - Each user gets their own isolated data
- ⚠️ **No real database** - This is for frontend exploration only

## Testing Locally Before Deployment

You can test the stub version locally:

```bash
# Install dependencies (without PostgreSQL)
Rscript requirements_shinyapps.R

# Run the app
Rscript app_shinyapps.R
```

The app will be available at http://localhost:3838 (or the port shown in the console).

## Migration to Production

When you're ready to deploy with a real database:

1. Use the original `6-Application/app.R` instead
2. Set up a PostgreSQL database
3. Configure environment variables for database connection
4. Consider deploying to a platform that supports databases:
   - Heroku (with PostgreSQL add-on)
   - AWS/GCP/Azure with managed PostgreSQL
   - RStudio Connect
   - Posit Cloud

## Troubleshooting

### Error: "Cannot find app.R"

Make sure you're deploying with `appPrimaryDoc = "app_shinyapps.R"` or rename the file to `app.R`.

### Error: "Package 'RPostgreSQL' not available"

Make sure you're using `requirements_shinyapps.R` which doesn't include PostgreSQL dependencies.

### App works locally but fails on ShinyApps.io

Check the logs at https://www.shinyapps.io/admin/#/applications and ensure all required packages are listed in the deployment.

## Support

For issues with the stub implementation, check:
- `R/db_stub.R` - Mock database implementation
- `R/logic.R` - Business logic that should work with both real and stub databases
