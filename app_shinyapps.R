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

# Override save_metric_entry to work with stub mode
save_metric_entry <- function(metric_id, entry_date, status,
                              value_text = NULL, explanation_text = NULL,
                              is_escalated = FALSE, created_by = "system") {
  
  # Check if entry already exists for this metric + date
  existing <- db_read(sprintf(
    "SELECT entry_id FROM metric_entries WHERE metric_id = %d AND entry_date = '%s'",
    as.integer(metric_id), as.character(entry_date)
  ))
  
  if (nrow(existing) > 0) {
    # Update existing entry
    entry_id <- existing$entry_id[1]
    sql <- sprintf(
      "UPDATE metric_entries SET status = %s, value_text = %s,
         explanation_text = %s, is_escalated_bool = %s, created_by = %s
       WHERE entry_id = %d",
      sql_quote(status),
      sql_quote(value_text),
      sql_quote(explanation_text),
      sql_bool(is_escalated),
      sql_quote(created_by),
      entry_id
    )
    db_execute(sql)
  } else {
    # Insert new entry - stub mode uses special INSERT handling
    entry_id <- .mock_data$next_entry_id
    .mock_data$next_entry_id <- .mock_data$next_entry_id + 1L
    
    new_entry <- data.frame(
      entry_id = entry_id,
      metric_id = as.integer(metric_id),
      entry_date = as.Date(entry_date),
      status = status,
      value_text = ifelse(is.null(value_text), NA_character_, value_text),
      explanation_text = ifelse(is.null(explanation_text), NA_character_, explanation_text),
      is_escalated_bool = is_escalated,
      created_by = created_by,
      created_at = Sys.time(),
      stringsAsFactors = FALSE
    )
    
    .mock_data$metric_entries <- rbind(.mock_data$metric_entries, new_entry)
  }
  
  # FORCED ISSUE CREATION for NOT_MET
  if (status == "NOT_MET" && !is.na(entry_id)) {
    # Get metric info for issue description
    metric_info <- db_read(sprintf(
      "SELECT * FROM metric_definitions WHERE metric_id = %d", as.integer(metric_id)
    ))
    if (nrow(metric_info) > 0) {
      mi <- metric_info[1, ]
      issue_type  <- if (isTRUE(is_escalated)) "ESCALATION" else "ACTION"
      target_tier <- if (issue_type == "ESCALATION") mi$tier_level + 1 else mi$tier_level
      
      # Check if issue already linked to this entry
      existing_issue <- db_read(sprintf(
        "SELECT issue_id FROM issues WHERE linked_entry_id = %d", entry_id
      ))
      
      if (nrow(existing_issue) == 0) {
        desc <- paste0("[", mi$functional_area, " / ", mi$sqdcp_category, "] ",
                        mi$metric_name, " – NOT MET on ", as.character(entry_date),
                        ". ", ifelse(is.null(explanation_text), "", explanation_text))
        
        create_issue(
          issue_type      = issue_type,
          source_tier     = mi$tier_level,
          target_tier     = target_tier,
          functional_area = mi$functional_area,
          sqdcp_category  = mi$sqdcp_category,
          description     = desc,
          owner           = created_by,
          due_date        = as.character(Sys.Date() + 7),
          created_by      = created_by,
          linked_entry_id = entry_id
        )
      }
    }
  }
  
  return(entry_id)
}

# Launch Shiny
message("[TierPulse] Launching Shiny app...")
shiny::runApp(
  appDir = ".",
  launch.browser = FALSE
)
