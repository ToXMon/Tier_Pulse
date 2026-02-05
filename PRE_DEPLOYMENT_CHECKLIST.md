# Pre-Deployment Checklist for ShinyApps.io

Use this checklist to ensure everything is ready before deploying to ShinyApps.io.

## ✅ Prerequisites

- [ ] R installed (version 4.0 or higher recommended)
- [ ] RStudio installed (optional but recommended)
- [ ] ShinyApps.io account created (free tier available at https://www.shinyapps.io/)
- [ ] Internet connection available

## ✅ Package Installation

```bash
# Install required packages
Rscript requirements_shinyapps.R
```

Verify the following packages are installed:
- [ ] shiny
- [ ] bslib
- [ ] DT
- [ ] lubridate
- [ ] dplyr
- [ ] rsconnect (for deployment)

## ✅ Account Configuration

1. Go to https://www.shinyapps.io/admin/#/tokens
2. Copy your account name, token, and secret
3. Configure in R:

```r
rsconnect::setAccountInfo(
  name = "YOUR_ACCOUNT_NAME",
  token = "YOUR_TOKEN",
  secret = "YOUR_SECRET"
)
```

Verify:
```r
rsconnect::accounts()  # Should show your account
```

- [ ] Account configured successfully

## ✅ File Structure Verification

Check that these files exist:

Core files:
- [ ] `app_shinyapps.R` - Entry point
- [ ] `ui.R` - UI symlink
- [ ] `server.R` - Server symlink

R directory:
- [ ] `R/db_stub.R` - Database stub
- [ ] `R/logic.R` - Business logic
- [ ] `R/modules/` - All module files

Documentation:
- [ ] `DEPLOYMENT_SHINYAPPS.md` - Deployment guide
- [ ] `QUICK_START_SHINYAPPS.md` - Quick reference
- [ ] `README.md` - Updated with ShinyApps.io section

Scripts:
- [ ] `deploy_to_shinyapps.R` - Deployment script
- [ ] `requirements_shinyapps.R` - Package list

## ✅ Local Testing (Optional)

If you want to test locally before deploying:

```bash
# Option 1: Run in R console
R
> source("app_shinyapps.R")

# Option 2: Run from command line
Rscript app_shinyapps.R
```

- [ ] App launches without errors
- [ ] Can access at http://localhost:3838 (or displayed port)
- [ ] "Stub mode" message appears in console
- [ ] UI loads successfully
- [ ] Can navigate between tabs

Test basic functionality:
- [ ] Operational Pulse shows 0s initially
- [ ] Can access Tier 1 Input tab
- [ ] Can access Tier 2 Input tab
- [ ] Can access Action Hub tab
- [ ] Admin tab shows metric definitions

## ✅ Deployment

### Option A: Using Automated Script (Recommended)

```bash
Rscript deploy_to_shinyapps.R
```

- [ ] Deployment starts successfully
- [ ] No errors during file upload
- [ ] Browser opens automatically with deployed app
- [ ] App loads on ShinyApps.io

### Option B: Manual Deployment

```r
library(rsconnect)

deployApp(
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
  launch.browser = TRUE
)
```

- [ ] Deployment completes successfully
- [ ] App URL provided
- [ ] Browser opens to deployed app

## ✅ Post-Deployment Verification

Access your app at: `https://YOUR_ACCOUNT_NAME.shinyapps.io/tierpulse`

### Basic Functionality Tests

**Operational Pulse:**
- [ ] Dashboard loads
- [ ] KPI cards show (0, 0, 0 initially)
- [ ] Database status shows "Connected"
- [ ] No errors in browser console

**Tier 1 Input:**
- [ ] Tab opens successfully
- [ ] Metric selection dropdown works
- [ ] Can create entry for today
- [ ] Status buttons work (MET/TBD/NOT_MET)
- [ ] Can submit entry
- [ ] Success message appears

**Tier 1 Board:**
- [ ] Board view loads
- [ ] Today's date shown
- [ ] Entries appear as colored tiles
- [ ] 6-day grid displays
- [ ] Exception mode toggle works
- [ ] Meeting timer visible

**Action Hub:**
- [ ] Tab loads successfully
- [ ] Issues table appears (empty initially)
- [ ] Create NOT_MET entry in Tier 1
- [ ] Issue appears automatically in Action Hub
- [ ] Can filter issues
- [ ] Can update issue status

**Tier 2:**
- [ ] Tier 2 Input tab works
- [ ] Tier 2 Board displays
- [ ] 14-day trend grid shows
- [ ] Escalated issues appear

**Attendance:**
- [ ] Can add attendance record
- [ ] Table displays records

**Admin:**
- [ ] Metric definitions table loads
- [ ] Shows 15 seed metrics
- [ ] Table is sortable/searchable

### Data Persistence Test

- [ ] Create some entries
- [ ] Navigate between tabs
- [ ] Data persists within session
- [ ] Refresh page (Ctrl+R)
- [ ] Data resets (expected in stub mode)

### Multi-User Test (Optional)

- [ ] Open app in incognito/private window
- [ ] Each session has isolated data (expected)

## ✅ Monitoring & Logs

Access your ShinyApps.io dashboard:
1. Go to https://www.shinyapps.io/admin/#/applications
2. Click on "tierpulse" app
3. Check logs for any errors

- [ ] No errors in application logs
- [ ] "Stub mode" startup message visible
- [ ] No warnings about missing packages

## ✅ Share & Collect Feedback

- [ ] Share app URL with team
- [ ] Gather feedback on UI/UX
- [ ] Document any issues found
- [ ] Plan production deployment if needed

## 🔧 Troubleshooting

### Common Issues

**"Error: Cannot find app.R"**
- Ensure `appPrimaryDoc = "app_shinyapps.R"` is set
- Or rename `app_shinyapps.R` to `app.R`

**"Package 'RPostgreSQL' not available"**
- Verify using `requirements_shinyapps.R`, not `requirements.R`
- Re-run package installation

**"Application failed to start"**
- Check logs at shinyapps.io dashboard
- Verify all required files are in deployment
- Ensure R/ directory is included

**Data disappears after refresh**
- This is expected in stub mode
- Data is in-memory only

**Symlinks not working on Windows**
- Copy actual files instead of symlinks
- Or deploy from Linux/Mac environment

## 📝 Notes

- Stub mode is for frontend exploration only
- Data is not persistent across sessions
- For production use, deploy with real PostgreSQL database
- See DEPLOYMENT_SHINYAPPS.md for detailed troubleshooting

## ✅ Success!

If all items are checked, you're ready to use TierPulse on ShinyApps.io!

Your app URL: `https://YOUR_ACCOUNT_NAME.shinyapps.io/tierpulse`

Share this URL with stakeholders to get feedback on the frontend before setting up the production database.
