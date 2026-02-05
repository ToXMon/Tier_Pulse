# TierPulse

**Tiered Performance Management for GMP Operations**

TierPulse supports Tier 1 (Daily) and Tier 2 (2x/week) standups using SQDCP
(Safety, Quality, Delivery, Cost, People) with exception-based management.

## Repository Structure

Following **Data Theory** conventions, the code is organized by data process
activity while maintaining the standard Shiny two-file structure required
by Domino:

```
/
  app.R                 # Launcher – binds 0.0.0.0:8888 (Domino)
  ui.R                  # UI definition
  server.R              # Server logic
  requirements.R        # Package installer
  R/
    db.R                # [Generation] DB connect + helpers
    migrate.R           # [Governance] Table migrations
    seed.R              # [Governance] Seed default metrics
    logic.R             # [Aggregation/Analysis] Business rules & queries
    modules/
      mod_board_tier1.R   # [Application] Tier 1 Board view
      mod_input_tier1.R   # [Application] Tier 1 Input view
      mod_board_tier2.R   # [Application] Tier 2 Board view
      mod_input_tier2.R   # [Application] Tier 2 Input view
      mod_action_hub.R    # [Application] Unified Action Hub
      mod_attendance.R    # [Application] Attendance tracking
  sql/
    001_create_tables.sql # PostgreSQL schema
  img/                    # Reference images
  README.md
  .gitignore
```

## Environment Variables (Required)

Set these before running the app:

| Variable            | Description                    | Default      |
|---------------------|--------------------------------|--------------|
| `POSTGRES_HOST`     | PostgreSQL host                | `localhost`  |
| `POSTGRES_PORT`     | PostgreSQL port                | `5432`       |
| `POSTGRES_DB`       | Database name                  | `tierpulse`  |
| `POSTGRES_USER`     | Database user                  | `postgres`   |
| `POSTGRES_PASSWORD` | Database password              | *(empty)*    |

**Never commit credentials to code.**

## Quick Start (Local)

```bash
# 1. Install R packages
Rscript requirements.R

# 2. Set environment variables
export POSTGRES_HOST=localhost
export POSTGRES_PORT=5432
export POSTGRES_DB=tierpulse
export POSTGRES_USER=postgres
export POSTGRES_PASSWORD=yourpassword

# 3. Create the database (if needed)
createdb tierpulse

# 4. Launch application
Rscript app.R
```

The app will be available at `http://localhost:8888`.

## Domino Deployment

1. **Create a Domino App** pointing to this repository.
2. Set **environment variables** in the Domino project settings.
3. Domino will execute `Rscript app.R` which binds to `0.0.0.0:8888`.
4. On first start, migrations run automatically (CREATE IF NOT EXISTS).
5. Seed metrics are loaded if `metric_definitions` is empty.

## Features

### Screens
- **Operational Pulse** – KPI cards (NOT_MET today, open issues, overdue)
- **Tier 1** – Board (status tiles, 6-day grid, timer) | Input | Attendance
- **Tier 2** – Board (rollup, 14-day trend, timer) | Input | Attendance
- **Action Hub** – Unified issues with filters, promote-to-escalation
- **Admin** – Metric definitions management, seed defaults

### Core Business Rules
- **NOT_MET → forced issue**: Marking any metric NOT_MET automatically
  creates an Issue record (ACTION or ESCALATION)
- **Tier integration**: Tier 2 board pulls all OPEN issues where
  `target_tier = 2`
- **Promote**: ACTIONs can be promoted to ESCALATIONs (target_tier
  increments)
- **Meeting timer**: Visual "danger" state when timebox exceeded

### Visual System
- MET = green + check icon
- TBD = yellow + question icon
- NOT_MET = red + x icon
- Exception-only mode hides MET items
- Board mode uses large typography for at-a-distance readability

## Data Model

Five PostgreSQL tables: `metric_definitions`, `metric_entries`, `issues`,
`attendance`, `meetings`. See `sql/001_create_tables.sql` for full schema.

## Packages

- `shiny`, `bslib` – UI framework
- `DT` – Interactive tables
- `DBI`, `RPostgreSQL` – PostgreSQL connectivity
- `lubridate` – Date manipulation
- `dplyr` – Data wrangling

## Acceptance Criteria

1. User sets env vars → runs `Rscript app.R` → sees UI → can create entries
2. NOT_MET entry → OPEN Issue auto-created → visible in Action Hub
3. Tier 1 escalation targeting Tier 2 → appears on Tier 2 Board
4. Timer expires → UI shows "danger" state
