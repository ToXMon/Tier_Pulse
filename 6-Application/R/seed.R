# =============================================================================
# TierPulse – R/seed.R
# Governance / Generation layer – seed default metric definitions on first run.
# =============================================================================

source("R/db.R")

#' Returns the default seed metrics as a data.frame.
#' Easy to edit – just add/remove rows.
get_seed_metrics <- function() {

  data.frame(
    tier_level      = c(
      # ---- Tier 1 – Daily prompts ----
      1, 1,
      1, 1,
      1, 1,
      1,
      1, 1,
      # ---- Tier 2 – Weekly / high-level ----
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

#' Seed metric_definitions table if it is empty.
seed_metrics_if_empty <- function() {

  con <- get_db_connection()
  if (is.null(con)) {
    warning("[TierPulse] Cannot seed metrics – database unreachable.")
    return(invisible(FALSE))
  }
  on.exit(disconnect_db(con))

  count <- tryCatch(
    dbGetQuery(con, "SELECT COUNT(*) AS n FROM metric_definitions")$n,
    error = function(e) {
      warning(paste0("[TierPulse] Could not check metric_definitions: ", e$message))
      return(-1)
    }
  )

  if (count != 0) {
    message("[TierPulse] metric_definitions already populated (", count, " rows). Skipping seed.")
    return(invisible(FALSE))
  }

  seeds <- get_seed_metrics()
  message("[TierPulse] Seeding ", nrow(seeds), " default metric definitions...")

  for (i in seq_len(nrow(seeds))) {
    row <- seeds[i, ]
    sql <- sprintf(
      "INSERT INTO metric_definitions (tier_level, sqdcp_category, functional_area,
         metric_name, metric_prompt, target_text, active_bool)
       VALUES (%d, %s, %s, %s, %s, %s, %s)",
      row$tier_level,
      sql_quote(row$sqdcp_category),
      sql_quote(row$functional_area),
      sql_quote(row$metric_name),
      sql_quote(row$metric_prompt),
      sql_quote(row$target_text),
      sql_bool(row$active_bool)
    )
    tryCatch(
      dbExecute(con, sql),
      error = function(e) warning(paste0("[TierPulse] Seed insert error row ", i, ": ", e$message))
    )
  }

  message("[TierPulse] Seeding complete.")
  return(invisible(TRUE))
}
