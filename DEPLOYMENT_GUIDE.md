# TierPulse Deployment Guide: Domino Dev Environment with Live Database

**Target audience:** Development team deploying TierPulse to Domino for the first time  
**Goal:** Set up a PostgreSQL database via IRIS and deploy the Shiny app to Domino Dev  
**Date:** February 2026

---

## Overview

This guide walks you through:
1. Provisioning a PostgreSQL database via IRIS
2. Creating and configuring a Domino project
3. Modifying TierPulse code to connect to the live database
4. Publishing the Shiny app on Domino

---

## Phase 1: Provision PostgreSQL Database via IRIS

### Step 1.1 — Submit IRIS Request

1. Open the ServiceNow IRIS request page:
   - **[IRIS Request – Provision a New Database](https://jnj.service-now.com/iris?id=sc_cat_item&sys_id=437e2fea0f75064003dd1b9ff2050ecd)**
   
2. Fill out the request form:
   - **Database Type:** PostgreSQL
   - **Hosting Platform:** Select either:
     - IaaS AWS Cloud, OR
     - IaaS Azure Cloud
   - **Environment:** **Non-Production (Dev/Test)** *(recommended for first iteration)*
   - **Application/Project Name:** TierPulse
   - **Business Justification:** "Tier performance tracking and escalation management application"

3. Submit the request and note the ticket number for tracking.

### Step 1.2 — Record Connection Details

Once your database is provisioned, you'll receive:
- **Host/endpoint** (e.g., `tierpulse-dev.postgres.aws.jnj.com`)
- **Port** (typically `5432`)
- **Database name** (e.g., `tierpulse_dev`)
- **Username** (e.g., `PostgreSA` or app-specific user)
- **Password** (securely stored; may require vault/secrets management)

**Action:** Save these to a secure location. You'll need them in Phase 3.

### Step 1.3 — Troubleshooting Contacts

If you encounter issues during provisioning:

| Issue Type | Contact |
|------------|---------|
| Database provisioning, hosting lane selection | **CloudX Database Team:** [RA-NCSUS-DatabaseSer@its.jnj.com](mailto:RA-NCSUS-DatabaseSer@its.jnj.com) |
| VPCx operational issues (permissions, account association) | **VPCx Ops:** [DL-VPCx-Operation@its.jnj.com](mailto:DL-VPCx-Operation@its.jnj.com) |
| Domino connectivity or Data Source setup | **Submit SAM ticket** under domain "Med.ai – Open Data Science Lab" |

---

## Phase 2: Create and Configure Domino Project

### Step 2.1 — Create Project

1. In Domino, navigate to **Develop > Projects**
2. Click **New Project**
3. Configure:
   - **Name:** `TierPulse`
   - **Visibility:** Private *(adjust based on team needs)*
4. Click **Create Project**

### Step 2.2 — Set Compute Environment

**For initial deployment (recommended):**

1. Go to **Project Settings**
2. Under **Compute Environment**, select:
   - **Domino Standard Environment Py3.8 R4.1**
   
   *(This is a known-good environment with R dependencies pre-installed)*

**After MVP is working:**  
Consider creating a custom environment with TierPulse-specific R packages baked in (see Appendix A).

### Step 2.3 — Create Workspace (Development Environment)

1. In project sidebar, click **Workspaces**
2. Click **+ Create New Workspace**
3. Configure:
   - **Name:** `tierpulse-dev`
   - **Compute Environment:** Domino Standard Environment Py3.8 R4.1
   - **Workspace IDE:** RStudio
   - **Volume Size:** Default (increase later if needed)
   - **Hardware Tier:** Start with smallest available
4. Click **Launch**
5. Wait for workspace to initialize, then click **Open Workspace**

---

## Phase 3: Modify Code for Live Database Connection

### Step 3.1 — Update Database Configuration File

**File to modify:** `6-Application/R/db.R`

1. Open `6-Application/R/db.R` in RStudio/Domino workspace
2. Locate the database connection configuration (typically a function like `get_db_connection()` or config variables)
3. Replace hardcoded/local connection details with your live database credentials:

```r
# OLD (local development):
# db_host <- "localhost"
# db_port <- 5432
# db_name <- "tierpulse_local"
# db_user <- "postgres"
# db_password <- "password"

# NEW (live Domino database):
db_host <- Sys.getenv("DB_HOST", "tierpulse-dev.postgres.aws.jnj.com")
db_port <- as.integer(Sys.getenv("DB_PORT", "5432"))
db_name <- Sys.getenv("DB_NAME", "tierpulse_dev")
db_user <- Sys.getenv("DB_USER", "your_db_username")
db_password <- Sys.getenv("DB_PASSWORD", "your_db_password")
```

**Security Best Practice:** Use Domino environment variables instead of hardcoding credentials (see Step 3.4).

### Step 3.2 — Verify Required R Packages

Ensure these packages are installed in your Domino environment (check at top of `db.R`):

```r
library(DBI)
library(RPostgreSQL)  # or RPostgres
library(pool)  # recommended for connection pooling in Shiny
```

**Installation (if missing):**  
In your Domino workspace terminal:
```r
install.packages(c("DBI", "RPostgreSQL", "pool"))
```

### Step 3.3 — Initialize Database Schema

**File to run:** `6-Application/R/migrate.R`

1. Open `6-Application/R/migrate.R`
2. This script reads `6-Application/sql/001_create_tables.sql` and creates tables in the database
3. In your Domino RStudio console, run:

```r
source("R/migrate.R")
```

**Expected output:** Confirmation that tables were created (check for errors related to permissions or connectivity).

**Troubleshooting:**
- If you get "connection refused," verify network access from Domino to your database host
- If you get "authentication failed," double-check credentials from Phase 1
- Contact ODSL support via SAM ticket if connectivity issues persist

### Step 3.4 — Set Environment Variables in Domino (Secure Credentials)

**Instead of hardcoding passwords in `db.R`:**

1. In Domino Project, go to **Settings > Environment Variables**
2. Add the following variables:
   - `DB_HOST` = `tierpulse-dev.postgres.aws.jnj.com`
   - `DB_PORT` = `5432`
   - `DB_NAME` = `tierpulse_dev`
   - `DB_USER` = `your_username`
   - `DB_PASSWORD` = `your_password` *(mark as "Secret" if option available)*
3. Save changes
4. **Restart your workspace** for environment variables to take effect

### Step 3.5 — Test Database Connection

In your Domino RStudio console:

```r
source("R/db.R")

# Test connection
conn <- get_db_connection()  # or whatever your connection function is named
DBI::dbListTables(conn)
DBI::dbDisconnect(conn)
```

**Expected output:** List of tables (e.g., `tier1_metrics`, `tier2_assessments`, `escalations`, etc.)

---

## Phase 4: Configure App for Domino Deployment

### Step 4.1 — Verify/Update app.R

**File to check:** `6-Application/app.R`

Your `app.R` must run with these Domino-specific parameters:

```r
library(shiny)

# Run the Shiny app with Domino-required settings
shiny::runApp(
  appDir = "./",
  host = "0.0.0.0",  # REQUIRED for Domino
  port = 8888,        # Domino standard port (can be flexible)
  launch.browser = FALSE
)
```

**Action:** Open `6-Application/app.R` and ensure `host = "0.0.0.0"` is set.

### Step 4.2 — Verify server.R and ui.R

Domino will load your app from these files. Check that:

1. **`6-Application/server.R`** contains your Shiny server logic
2. **`6-Application/ui.R`** contains your Shiny UI definition
3. Both files correctly source your modules and database connection:

```r
# At top of server.R
source("R/db.R")
source("5-Analysis/logic.R")
# ... load modules from 5-Analysis/modules/ as needed
```

### Step 4.3 — Upload Files to Domino Project

**Option A: Git Integration (recommended)**
1. If your Domino project is linked to a Git repo, commit and push your changes:
   ```bash
   git add 6-Application/R/db.R 6-Application/app.R
   git commit -m "Configure live database connection for Domino dev"
   git push origin main
   ```
2. In Domino, sync your project to pull latest changes

**Option B: Direct Upload**
1. In Domino project, click **Files**
2. Navigate to `6-Application/`
3. Upload modified files directly via Domino UI

---

## Phase 5: Publish Shiny App in Domino

### Step 5.1 — Create App Deployment

1. In Domino project, navigate to **Deployments > Apps & Agents**
2. Click **New App**
3. Configure the deployment:
   - **App Title:** TierPulse Dev
   - **Description:** Tier performance tracking and escalation management
   - **Permissions:** Set based on team access needs (e.g., "Project Contributors")
   - **Branch/Revision:** Select `main` (or your target branch)
   - **Environment:** Domino Standard Environment Py3.8 R4.1
   - **Hardware Tier:** Start with smallest tier; scale up if needed
   - **Launch File:** Select `6-Application/app.R`

4. **Attach Data Sources (if using Domino Data API):**
   - Click **Add Data Source**
   - Select your PostgreSQL Data Source (if you created one via Data > Data Sources)
   
   *(Optional: If not using Domino Data Source, skip this—your app will connect directly via environment variables)*

5. Click **Publish**

### Step 5.2 — Monitor Deployment

1. Wait for deployment status to change from "Starting" to **"Running"**
   - This may take 2-5 minutes
   - Watch logs for errors (e.g., missing packages, connection failures)

2. **If deployment fails:**
   - Click **View Logs** to see error messages
   - Common issues:
     - Missing R packages → Add to environment (see Appendix A)
     - Database connection timeout → Check network/firewall rules (contact ODSL support)
     - Port binding issues → Verify `host = "0.0.0.0"` in app.R

### Step 5.3 — Access Your App

1. Once status is **Running**, click **View App**
2. Your TierPulse app should load in a new browser tab
3. **Test key functionality:**
   - Navigate through tabs (Tier 1 Input, Tier 2 Input, Board views, Action Hub, Attendance)
   - Submit a test Tier 1 metric entry
   - Verify data is saved to database (check via RStudio query or app's Board view)

---

## Phase 6: Post-Deployment Validation

### Step 6.1 — Verify Data Persistence

1. In the app, create a test Tier 1 entry
2. In Domino workspace RStudio console, query the database:

```r
source("R/db.R")
conn <- get_db_connection()
DBI::dbGetQuery(conn, "SELECT * FROM tier1_metrics ORDER BY created_at DESC LIMIT 5;")
DBI::dbDisconnect(conn)
```

**Expected:** Your test entry appears in results.

### Step 6.2 — Load Seed Data (Optional)

If you have initial/reference data to load:

**File to run:** `6-Application/R/seed.R`

```r
source("R/seed.R")
```

This populates lookup tables, demo data, etc.

### Step 6.3 — Share App URL

1. Copy the app URL from Domino (e.g., `https://domino.jnj.com/.../TierPulse_Dev`)
2. Share with team members who need access
3. Ensure their accounts have appropriate permissions (set in Step 5.1)

---

## Appendix A: Creating a Custom Domino Environment (Advanced)

**When to do this:** After your MVP is working and you want faster, more reliable deployments.

### A.1 — Create Custom Environment

1. In Domino, go to **Environments > Create Environment**
2. Configure:
   - **Name:** `TierPulse-R-Environment`
   - **Base Image:** Domino Standard Environment Py3.8 R4.1
3. Add Dockerfile instructions to install required packages:

```dockerfile
# Install R packages needed for TierPulse
RUN R -e "install.packages(c('shiny', 'DBI', 'RPostgreSQL', 'pool', 'dplyr', 'tidyr', 'ggplot2', 'lubridate', 'shinydashboard'), repos='https://cloud.r-project.org/')"
```

4. Click **Build**
5. Wait for build to complete (may take 10-15 minutes)

### A.2 — Update Project to Use Custom Environment

1. Go to Project Settings > Compute Environment
2. Select your new `TierPulse-R-Environment`
3. Restart workspace and re-publish app with new environment

**Benefit:** Packages are pre-installed, so app starts faster and deployments are more stable.

---

## Appendix B: Domino Data Source Setup (Alternative to Direct Connection)

If you prefer using Domino's Data Source abstraction:

### B.1 — Create PostgreSQL Data Source

1. In Domino, go to **Data > Data Sources**
2. Click **Create a Data Source**
3. Select **PostgreSQL**
4. Fill in connection details from Phase 1:
   - **Account Name:** TierPulse Dev DB
   - **Host:** `tierpulse-dev.postgres.aws.jnj.com`
   - **Port:** `5432`
   - **Database Name:** `tierpulse_dev`
   - **Data Source Name:** `tierpulse_db`
   - **Authentication:** Basic (username/password)
5. Set permissions (who can use this Data Source)
6. Click **Finish Setup**

### B.2 — Generate Connection Code

1. Open your Data Source in Domino
2. Click **Copy Code Snippet** (Domino generates R code)
3. Paste into `6-Application/R/db.R` to replace direct connection logic

**Benefit:** Centralized credential management; easier to rotate passwords without changing code.

---

## Appendix C: Troubleshooting Common Issues

| Issue | Likely Cause | Solution |
|-------|--------------|----------|
| App fails to start: "could not connect to server" | Database host unreachable from Domino | Check network/firewall rules; contact ODSL support via SAM ticket |
| App fails: "package 'X' is not available" | Missing R package in environment | Install package in workspace; add to custom environment (Appendix A) |
| App starts but data doesn't save | Database permissions issue | Verify `DB_USER` has INSERT/UPDATE/DELETE grants; check with CloudX Database Team |
| "Error: Can't bind to 0.0.0.0:8888" | Port already in use or incorrect binding | Ensure `app.R` uses `host = "0.0.0.0"` and `port = 8888` |
| Environment variables not loading | Workspace not restarted after setting vars | Restart workspace after changing environment variables in Project Settings |

---

## Quick Reference: File Checklist Before Deployment

- [ ] `6-Application/R/db.R` — Updated with live database credentials (via environment variables)
- [ ] `6-Application/R/migrate.R` — Tested to create schema successfully
- [ ] `6-Application/app.R` — Configured with `host = "0.0.0.0"`, `port = 8888`
- [ ] `6-Application/server.R` — Sources modules and db.R correctly
- [ ] `6-Application/ui.R` — UI definition complete
- [ ] Environment variables set in Domino Project Settings
- [ ] All required R packages installed or baked into custom environment

---

## Support Contacts Quick Reference

| Need | Contact |
|------|---------|
| Database provisioning/access | [RA-NCSUS-DatabaseSer@its.jnj.com](mailto:RA-NCSUS-DatabaseSer@its.jnj.com) |
| VPCx operational issues | [DL-VPCx-Operation@its.jnj.com](mailto:DL-VPCx-Operation@its.jnj.com) |
| Domino/ODSL support | Submit SAM ticket under "Med.ai – Open Data Science Lab" |

---

## Summary: Your Deployment Workflow

1. ✅ **Provision database** via IRIS → Get credentials
2. ✅ **Create Domino project** → Set environment → Launch workspace
3. ✅ **Modify code** → Update `db.R` with live credentials → Set env vars → Test connection
4. ✅ **Configure app** → Verify `app.R` Domino settings → Upload files
5. ✅ **Publish app** → Create deployment → Monitor logs → Access URL
6. ✅ **Validate** → Test data persistence → Share with team

**You're done!** TierPulse is now running on Domino Dev with a live PostgreSQL database.

---

*Version: 1.0 | Last Updated: February 2026*
