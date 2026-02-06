# =============================================================================
# TierPulse – R/db.R
# Database connection helpers (Generation layer – Data Theory)
# All secrets sourced from environment variables.
# =============================================================================

library(DBI)
library(RPostgreSQL)

# Stub mode toggle (set TIERPULSE_STUB_DB=1 to bypass Postgres for local testing)
.tierpulse_stub_mode <- Sys.getenv("TIERPULSE_STUB_DB") %in% c("1", "true", "TRUE", "yes")
.tierpulse_stub_env <- NULL

#' Return TRUE if running with stubbed data instead of a real database
db_is_stub_mode <- function() {
  isTRUE(.tierpulse_stub_mode)
}

#' Seed metrics for stub mode (mirrors seed.R defaults)
.stub_seed_metrics <- function() {
  data.frame(
    metric_id       = seq_len(15),
    tier_level      = c(
      1, 1,
      1, 1,
      1, 1,
      1,
      1, 1,
      2, 2,
      2,
      2,
      2,
      2
    ),
    sqdcp_category  = c(
      "Delivery", "Delivery",
      "Delivery", "Delivery",
      "Delivery", "Delivery",
      "Safety",
      "Quality", "Quality",
      "Quality", "Quality",
      "Delivery",
      "People",
      "Safety",
      "Delivery"
    ),
    functional_area = c(
      "OPS", "OPS",
      "Warehouse", "Warehouse",
      "Planning", "Planning",
      "Shopfloor",
      "QA Release", "QA Release",
      "Quality", "Quality",
      "Delivery",
      "People",
      "Safety",
      "Facilities"
    ),
    metric_name     = c(
      "Production Issues Today",
      "OPS Daily Status",
      "Pick Schedule On Track",
      "Shipments Schedule OK",
      "Consumables Coverage 48-72h",
      "Incoming Buffer Status",
      "Shopfloor Oversights",
      "Batch Release Coordination",
      "High Priority Doc Corrections",
      "Overdue NCs",
      "Overdue Actions",
      "Schedule Attainment",
      "Training Compliance",
      "Good Saves",
      "Room/EM Readiness"
    ),
    metric_prompt   = c(
      "Production yesterday - issues impacting today?",
      "Any operational issues to flag for today?",
      "On track for pick schedule?",
      "Shipments schedule for day/yesterday OK?",
      "Critical consumables coverage next 48-72 hours?",
      "Incoming buffer status on track?",
      "General oversights from prior day - items to raise?",
      "Planned batch release today/yesterday - coordinate?",
      "High priority docs need corrections today?",
      "Number of overdue non-conformances (target 0)",
      "Number of overdue actions (target 0)",
      "Weekly schedule attainment percentage",
      "Training compliance percentage",
      "Number of good saves reported",
      "Room/EM readiness status"
    ),
    target_text     = c(
      "No impact", "All clear",
      "On track", "On schedule",
      "Covered", "On track",
      "None",
      "Coordinated", "None needed",
      "0", "0",
      ">= 95%",
      ">= 95%",
      "Report all",
      "Ready"
    ),
    active_bool     = rep(TRUE, 15),
    stringsAsFactors = FALSE
  )
}

#' Initialise in-memory stub storage
.init_stub_env <- function() {
  env <- new.env(parent = emptyenv())
  env$metric_definitions <- .stub_seed_metrics()
  env$metric_entries     <- data.frame(
    entry_id = integer(), metric_id = integer(), entry_date = as.Date(character()),
    status = character(), value_text = character(), explanation_text = character(),
    is_escalated_bool = logical(), created_at = as.POSIXct(character()),
    created_by = character(), stringsAsFactors = FALSE
  )
  env$issues <- data.frame(
    issue_id = integer(), issue_type = character(), source_tier = integer(),
    target_tier = integer(), status = character(), functional_area = character(),
    sqdcp_category = character(), description = character(), owner = character(),
    due_date = as.Date(character()), created_at = as.POSIXct(character()),
    created_by = character(), linked_entry_id = integer(), stringsAsFactors = FALSE
  )
  env$attendance <- data.frame(
    attendance_id = integer(), tier_level = integer(), meeting_date = as.Date(character()),
    functional_area = character(), person_name = character(), present_bool = logical(),
    notes = character(), stringsAsFactors = FALSE
  )
  env$meetings <- data.frame(
    meeting_id = integer(), tier_level = integer(), meeting_date = as.Date(character()),
    scheduled_start_time = as.POSIXct(character()), timebox_minutes = integer(),
    facilitator_name = character(), created_at = as.POSIXct(character()),
    stringsAsFactors = FALSE
  )
  env$counters <- list(entry_id = 1L, issue_id = 1L, attendance_id = 1L, meeting_id = 1L)
  env
}

#' Accessor for stub environment
get_stub_env <- function() {
  if (!db_is_stub_mode()) return(NULL)
  if (is.null(.tierpulse_stub_env)) {
    .tierpulse_stub_env <<- .init_stub_env()
  }
  .tierpulse_stub_env
}

#' Establish a PostgreSQL connection using environment variables.
#' Returns a DBI connection or NULL with a warning message.
get_db_connection <- function() {

  if (db_is_stub_mode()) {
    return(NULL)
  }

  host <- Sys.getenv("POSTGRES_HOST", unset = "localhost")
  port <- Sys.getenv("POSTGRES_PORT", unset = "5432")
  db   <- Sys.getenv("POSTGRES_DB",   unset = "tierpulse")
  user <- Sys.getenv("POSTGRES_USER", unset = "postgres")
  pw   <- Sys.getenv("POSTGRES_PASSWORD", unset = "")

  tryCatch(
    {
      con <- dbConnect(
        PostgreSQL(),
        host     = host,
        port     = as.integer(port),
        dbname   = db,
        user     = user,
        password = pw
      )
      return(con)
    },
    error = function(e) {
      warning(paste0(
        "[TierPulse] Database connection failed: ", e$message,
        "\n  Host=", host, " Port=", port, " DB=", db, " User=", user
      ))
      return(NULL)
    }
  )
}

#' Safely disconnect
disconnect_db <- function(con) {
  if (!is.null(con)) {
    tryCatch(dbDisconnect(con), error = function(e) NULL)
  }
}

#' Run a parameterised read query; returns a data.frame (may be empty)
db_read <- function(sql, params = NULL) {
  if (db_is_stub_mode()) {
    # Stubbed reads are handled directly in logic layer; return empty for safety
    return(data.frame())
  }
  con <- get_db_connection()
  if (is.null(con)) return(data.frame())
  on.exit(disconnect_db(con))

  tryCatch(
    {
      if (is.null(params)) {
        dbGetQuery(con, sql)
      } else {
        # RPostgreSQL doesn't support parameterised queries natively –
        # we use interpolation via sprintf-safe helper below.
        dbGetQuery(con, sql)
      }
    },
    error = function(e) {
      warning(paste0("[TierPulse] Query error: ", e$message))
      data.frame()
    }
  )
}

#' Run a write statement (INSERT / UPDATE / DELETE)
db_execute <- function(sql) {
  if (db_is_stub_mode()) {
    # Stubbed writes are handled directly in logic layer; no-op success
    return(invisible(TRUE))
  }
  con <- get_db_connection()
  if (is.null(con)) return(invisible(FALSE))
  on.exit(disconnect_db(con))

  tryCatch(
    {
      dbExecute(con, sql)
      invisible(TRUE)
    },
    error = function(e) {
      warning(paste0("[TierPulse] Execute error: ", e$message))
      invisible(FALSE)
    }
  )
}

#' Escape a string value for safe SQL interpolation
sql_quote <- function(x) {
  if (is.null(x) || is.na(x) || x == "") return("NULL")
  paste0("'", gsub("'", "''", as.character(x)), "'")
}

#' Escape for boolean
sql_bool <- function(x) {
  if (isTRUE(x)) return("TRUE")
  return("FALSE")
}

#' Check if database is reachable (returns TRUE / FALSE)
db_is_available <- function() {
  if (db_is_stub_mode()) return(TRUE)
  con <- get_db_connection()
  if (is.null(con)) return(FALSE)
  disconnect_db(con)
  return(TRUE)
}
