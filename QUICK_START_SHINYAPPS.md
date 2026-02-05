# Quick Start for ShinyApps.io Deployment

## What This Is

This deployment configuration allows you to run TierPulse on ShinyApps.io **without** requiring a PostgreSQL database. All data is stored in-memory during your session.

## Files You Need

For ShinyApps.io deployment, these files are required:

- `app_shinyapps.R` - Entry point (rename to `app.R` or specify as primary doc)
- `ui.R` - User interface (symlink to 6-Application/ui.R)
- `server.R` - Server logic (symlink to 6-Application/server.R)
- `R/db_stub.R` - In-memory database stub
- `R/logic.R` - Business logic
- `R/modules/` - All UI modules

## Deployment Options

### Option 1: Using the Deployment Script (Easiest)

```bash
Rscript deploy_to_shinyapps.R
```

### Option 2: Manual Deployment

```r
library(rsconnect)

# Configure account (one-time)
setAccountInfo(name="your-account", token="...", secret="...")

# Deploy
deployApp(
  appName = "tierpulse",
  appFiles = c("app_shinyapps.R", "ui.R", "server.R", "R/"),
  appPrimaryDoc = "app_shinyapps.R",
  launch.browser = TRUE
)
```

### Option 3: Rename and Deploy

```bash
# Rename app_shinyapps.R to app.R
mv app_shinyapps.R app.R

# Deploy normally
R -e "rsconnect::deployApp()"
```

## What Works in Stub Mode

✅ All UI screens work normally:
- Operational Pulse dashboard
- Tier 1 Board, Input, and Attendance
- Tier 2 Board, Input, and Attendance
- Action Hub with filters
- Admin screen (metric definitions are pre-loaded)

✅ Core functionality works:
- Create metric entries
- Mark metrics as MET/TBD/NOT_MET
- Automatic issue creation for NOT_MET entries
- Issue promotion (ACTION → ESCALATION)
- Issue filtering and status updates
- Attendance tracking
- Meeting timers

## Limitations in Stub Mode

⚠️ Data is **not persistent**:
- All data resets when the app restarts
- Each user session is isolated (no shared data)
- This is for **frontend exploration only**, not production use

⚠️ No real database:
- No PostgreSQL connection
- No data migrations
- No seed data loading (pre-loaded in stub)

## Migrating to Production

When ready for production with real PostgreSQL:

1. Use `6-Application/app.R` instead of `app_shinyapps.R`
2. Set up PostgreSQL database
3. Configure environment variables
4. Deploy to a platform that supports databases:
   - RStudio Connect
   - Posit Cloud
   - Heroku + PostgreSQL
   - AWS/GCP/Azure + managed PostgreSQL

## Troubleshooting

**Q: I get "Cannot find app.R"**  
A: Either rename `app_shinyapps.R` to `app.R` or deploy with `appPrimaryDoc = "app_shinyapps.R"`

**Q: Package RPostgreSQL error**  
A: Make sure you're using `requirements_shinyapps.R` which doesn't include PostgreSQL

**Q: Data disappears**  
A: This is expected in stub mode - data is in-memory only

**Q: App works locally but fails on ShinyApps.io**  
A: Check logs at shinyapps.io and verify all files are included in deployment

## Support

For detailed documentation, see:
- `DEPLOYMENT_SHINYAPPS.md` - Complete deployment guide
- `README.md` - General app documentation
