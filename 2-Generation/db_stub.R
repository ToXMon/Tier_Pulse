# =============================================================================
# TierPulse – 2-Generation/db_stub.R (symlinked from R/db_stub.R)
# In-memory stub for ShinyApps.io deployment (no PostgreSQL)
# Provides the same interface as db.R but uses reactive values for storage
# =============================================================================

library(dplyr)
library(lubridate)

# Global in-memory storage (will be initialized by init_mock_data())
.mock_data <- new.env()

# Special flag and storage for stub mode
.stub_mode <- TRUE
.last_insert_id <- NULL  # Store last inserted ID for RETURNING emulation

#' Initialize mock data storage
init_mock_data <- function() {
  # Metric definitions (from seed.R)
  .mock_data$metric_definitions <- data.frame(
    metric_id       = 1:15,
    tier_level      = c(
      1, 1, 1, 1, 1, 1, 1, 1, 1,
      2, 2, 2, 2, 2, 2
    ),
    sqdcp_category  = c(
      "Delivery", "Delivery", "Delivery", "Delivery", "Delivery", "Delivery",
      "Safety", "Quality", "Quality",
      "Quality", "Quality", "Delivery", "People", "Safety", "Delivery"
    ),
    functional_area = c(
      "OPS", "OPS", "Warehouse", "Warehouse", "Planning", "Planning",
      "Shopfloor", "QA Release", "QA Release",
      "Quality", "Quality", "Delivery", "People", "Safety", "Facilities"
    ),
    metric_name     = c(
      "Production Issues Today", "OPS Daily Status",
      "Pick Schedule On Track", "Shipments Schedule OK",
      "Consumables Coverage 48-72h", "Incoming Buffer Status",
      "Shopfloor Oversights", "Batch Release Coordination",
      "High Priority Doc Corrections",
      "Overdue NCs", "Overdue Actions", "Schedule Attainment",
      "Training Compliance", "Good Saves", "Room/EM Readiness"
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
      "No impact", "All clear", "On track", "On schedule",
      "Covered", "On track", "None", "Coordinated", "None needed",
      "0", "0", ">= 95%", ">= 95%", "Report all", "Ready"
    ),
    active_bool     = rep(TRUE, 15),
    stringsAsFactors = FALSE
  )
  
  # Empty tables for runtime data
  .mock_data$metric_entries <- data.frame(
    entry_id = integer(),
    metric_id = integer(),
    entry_date = as.Date(character()),
    status = character(),
    value_text = character(),
    explanation_text = character(),
    is_escalated_bool = logical(),
    created_by = character(),
    created_at = as.POSIXct(character()),
    stringsAsFactors = FALSE
  )
  
  .mock_data$issues <- data.frame(
    issue_id = integer(),
    issue_type = character(),
    source_tier = integer(),
    target_tier = integer(),
    status = character(),
    functional_area = character(),
    sqdcp_category = character(),
    description = character(),
    owner = character(),
    due_date = as.Date(character()),
    created_by = character(),
    created_at = as.POSIXct(character()),
    linked_entry_id = integer(),
    stringsAsFactors = FALSE
  )
  
  .mock_data$attendance <- data.frame(
    attendance_id = integer(),
    tier_level = integer(),
    meeting_date = as.Date(character()),
    functional_area = character(),
    person_name = character(),
    present_bool = logical(),
    notes = character(),
    stringsAsFactors = FALSE
  )
  
  .mock_data$meetings <- data.frame(
    meeting_id = integer(),
    tier_level = integer(),
    meeting_date = as.Date(character()),
    scheduled_start_time = character(),
    timebox_minutes = integer(),
    facilitator_name = character(),
    stringsAsFactors = FALSE
  )
  
  # Counters for auto-increment IDs
  .mock_data$next_entry_id <- 1L
  .mock_data$next_issue_id <- 1L
  .mock_data$next_attendance_id <- 1L
  .mock_data$next_meeting_id <- 1L
  
  message("[TierPulse] Mock data initialized (ShinyApps.io stub mode)")
}

# Stub functions matching db.R interface

get_db_connection <- function() {
  # Always return NULL in stub mode
  return(NULL)
}

disconnect_db <- function(con) {
  # No-op
  invisible(NULL)
}

db_read <- function(sql, params = NULL) {
  # Handle RETURNING clause in INSERT statements
  if (grepl("^INSERT INTO", sql, ignore.case = TRUE) && grepl("RETURNING", sql, ignore.case = TRUE)) {
    # This is an INSERT...RETURNING query
    # Execute the insert and return the ID
    
    if (grepl("INSERT INTO metric_entries", sql, ignore.case = TRUE)) {
      entry_id <- .mock_data$next_entry_id
      .mock_data$next_entry_id <- .mock_data$next_entry_id + 1L
      
      # Parse values
      metric_id <- as.integer(gsub(".*VALUES \\(([0-9]+),.*", "\\1", sql))
      entry_date <- as.Date(gsub(".*'([0-9]{4}-[0-9]{2}-[0-9]{2})'.*", "\\1", sql))
      
      status_match <- regmatches(sql, gregexpr("'(MET|TBD|NOT_MET)'", sql))[[1]]
      status <- if (length(status_match) > 0) gsub("'", "", status_match[1]) else "TBD"
      
      new_entry <- data.frame(
        entry_id = entry_id,
        metric_id = metric_id,
        entry_date = entry_date,
        status = status,
        value_text = NA_character_,
        explanation_text = NA_character_,
        is_escalated_bool = FALSE,
        created_by = "system",
        created_at = Sys.time(),
        stringsAsFactors = FALSE
      )
      
      .mock_data$metric_entries <- rbind(.mock_data$metric_entries, new_entry)
      return(data.frame(entry_id = entry_id))
    }
  }
  
  # Parse SQL and return mock data
  # This is a simplified parser - handles the most common queries
  
  if (grepl("FROM metric_definitions", sql, ignore.case = TRUE)) {
    data <- .mock_data$metric_definitions
    
    # Apply WHERE clauses
    if (grepl("WHERE tier_level = ([0-9]+)", sql, ignore.case = TRUE)) {
      tier <- as.integer(gsub(".*WHERE tier_level = ([0-9]+).*", "\\1", sql))
      data <- data[data$tier_level == tier, ]
    }
    
    if (grepl("active_bool = TRUE", sql, ignore.case = TRUE)) {
      data <- data[data$active_bool == TRUE, ]
    }
    
    return(data)
    
  } else if (grepl("FROM metric_entries", sql, ignore.case = TRUE)) {
    # Join with metric_definitions
    entries <- .mock_data$metric_entries
    
    if (nrow(entries) == 0) return(data.frame())
    
    # Perform join
    metrics <- .mock_data$metric_definitions
    data <- merge(entries, metrics, by = "metric_id", all.x = TRUE)
    
    # Apply WHERE clauses
    if (grepl("entry_date = '([^']+)'", sql)) {
      date_str <- gsub(".*entry_date = '([^']+)'.*", "\\1", sql)
      data <- data[as.character(data$entry_date) == date_str, ]
    }
    
    if (grepl("entry_date BETWEEN '([^']+)' AND '([^']+)'", sql)) {
      dates <- gsub(".*entry_date BETWEEN '([^']+)' AND '([^']+)'.*", "\\1,\\2", sql)
      start_date <- as.Date(strsplit(dates, ",")[[1]][1])
      end_date <- as.Date(strsplit(dates, ",")[[1]][2])
      data <- data[data$entry_date >= start_date & data$entry_date <= end_date, ]
    }
    
    if (grepl("status = 'NOT_MET'", sql)) {
      data <- data[data$status == "NOT_MET", ]
    }
    
    return(data)
    
  } else if (grepl("FROM issues", sql, ignore.case = TRUE)) {
    data <- .mock_data$issues
    
    # Apply WHERE clauses
    if (grepl("status IN \\('OPEN', 'IN_PROGRESS'\\)", sql, ignore.case = TRUE)) {
      data <- data[data$status %in% c("OPEN", "IN_PROGRESS"), ]
    }
    
    if (grepl("target_tier = ([0-9]+)", sql)) {
      tier <- as.integer(gsub(".*target_tier = ([0-9]+).*", "\\1", sql))
      data <- data[data$target_tier == tier, ]
    }
    
    if (grepl("linked_entry_id = ([0-9]+)", sql)) {
      entry_id <- as.integer(gsub(".*linked_entry_id = ([0-9]+).*", "\\1", sql))
      data <- data[data$linked_entry_id == entry_id, ]
    }
    
    if (grepl("due_date < '([^']+)'", sql)) {
      date_str <- gsub(".*due_date < '([^']+)'.*", "\\1", sql)
      data <- data[!is.na(data$due_date) & data$due_date < as.Date(date_str), ]
    }
    
    # Apply LIMIT
    if (grepl("LIMIT ([0-9]+)", sql, ignore.case = TRUE)) {
      limit <- as.integer(gsub(".*LIMIT ([0-9]+).*", "\\1", sql))
      if (nrow(data) > limit) {
        data <- head(data, limit)
      }
    }
    
    return(data)
    
  } else if (grepl("FROM attendance", sql, ignore.case = TRUE)) {
    data <- .mock_data$attendance
    
    if (grepl("tier_level = ([0-9]+)", sql)) {
      tier <- as.integer(gsub(".*tier_level = ([0-9]+).*", "\\1", sql))
      data <- data[data$tier_level == tier, ]
    }
    
    if (grepl("meeting_date = '([^']+)'", sql)) {
      date_str <- gsub(".*meeting_date = '([^']+)'.*", "\\1", sql)
      data <- data[as.character(data$meeting_date) == date_str, ]
    }
    
    return(data)
    
  } else if (grepl("COUNT\\(\\*\\)", sql, ignore.case = TRUE)) {
    # Handle COUNT queries
    count_result <- 0
    
    if (grepl("FROM metric_entries", sql, ignore.case = TRUE)) {
      data <- .mock_data$metric_entries
      
      if (grepl("status = 'NOT_MET'", sql)) {
        data <- data[data$status == "NOT_MET", ]
      }
      
      if (grepl("entry_date = '([^']+)'", sql)) {
        date_str <- gsub(".*entry_date = '([^']+)'.*", "\\1", sql)
        data <- data[as.character(data$entry_date) == date_str, ]
      }
      
      count_result <- nrow(data)
      
    } else if (grepl("FROM issues", sql, ignore.case = TRUE)) {
      data <- .mock_data$issues
      
      if (grepl("status IN \\('OPEN', 'IN_PROGRESS'\\)", sql, ignore.case = TRUE)) {
        data <- data[data$status %in% c("OPEN", "IN_PROGRESS"), ]
      }
      
      if (grepl("due_date < '([^']+)'", sql)) {
        date_str <- gsub(".*due_date < '([^']+)'.*", "\\1", sql)
        data <- data[!is.na(data$due_date) & data$due_date < as.Date(date_str), ]
      }
      
      count_result <- nrow(data)
    }
    
    return(data.frame(n = count_result))
  }
  
  # Default: return empty data frame
  return(data.frame())
}

db_execute <- function(sql) {
  # Parse SQL and modify mock data
  
  if (grepl("^INSERT INTO metric_entries", sql, ignore.case = TRUE)) {
    # Extract values
    if (grepl("VALUES \\(([^)]+)\\)", sql)) {
      # Create new entry
      entry_id <- .mock_data$next_entry_id
      .mock_data$next_entry_id <- .mock_data$next_entry_id + 1L
      
      # Parse values (simplified)
      values_str <- gsub(".*VALUES \\(([^)]+)\\).*", "\\1", sql)
      
      # Extract metric_id
      metric_id <- as.integer(gsub("^([0-9]+),.*", "\\1", values_str))
      
      # Extract entry_date
      entry_date <- as.Date(gsub(".*'([0-9]{4}-[0-9]{2}-[0-9]{2})'.*", "\\1", sql))
      
      # Extract status
      status_match <- regmatches(sql, gregexpr("'(MET|TBD|NOT_MET)'", sql))[[1]][1]
      status <- gsub("'", "", status_match)
      
      new_entry <- data.frame(
        entry_id = entry_id,
        metric_id = metric_id,
        entry_date = entry_date,
        status = status,
        value_text = NA_character_,
        explanation_text = NA_character_,
        is_escalated_bool = FALSE,
        created_by = "system",
        created_at = Sys.time(),
        stringsAsFactors = FALSE
      )
      
      .mock_data$metric_entries <- rbind(.mock_data$metric_entries, new_entry)
      return(invisible(TRUE))
    }
    
  } else if (grepl("^UPDATE metric_entries", sql, ignore.case = TRUE)) {
    # Extract entry_id
    if (grepl("WHERE entry_id = ([0-9]+)", sql)) {
      entry_id <- as.integer(gsub(".*WHERE entry_id = ([0-9]+).*", "\\1", sql))
      
      idx <- which(.mock_data$metric_entries$entry_id == entry_id)
      if (length(idx) > 0) {
        # Update status if present
        if (grepl("status = '([^']+)'", sql)) {
          status <- gsub(".*status = '([^']+)'.*", "\\1", sql)
          .mock_data$metric_entries$status[idx] <- status
        }
      }
      return(invisible(TRUE))
    }
    
  } else if (grepl("^INSERT INTO issues", sql, ignore.case = TRUE)) {
    issue_id <- .mock_data$next_issue_id
    .mock_data$next_issue_id <- .mock_data$next_issue_id + 1L
    
    # Extract values from SQL
    # Parse issue_type
    issue_type <- if (grepl("'(ACTION|ESCALATION)'", sql)) {
      gsub(".*'(ACTION|ESCALATION)'.*", "\\1", sql)
    } else {
      "ACTION"
    }
    
    # Parse tiers
    tier_matches <- regmatches(sql, gregexpr("[0-9]+", sql))[[1]]
    source_tier <- if (length(tier_matches) >= 1) as.integer(tier_matches[1]) else 1L
    target_tier <- if (length(tier_matches) >= 2) as.integer(tier_matches[2]) else 1L
    
    # Parse functional_area
    func_area <- if (grepl("functional_area, .*'([^']+)'", sql)) {
      areas <- regmatches(sql, gregexpr("'[^']+'", sql))[[1]]
      # Get the area (usually 4th or 5th string)
      if (length(areas) >= 3) gsub("'", "", areas[3]) else "OPS"
    } else {
      "OPS"
    }
    
    # Parse sqdcp_category
    sqdcp_cat <- if (grepl("sqdcp_category.*'([^']+)'", sql)) {
      areas <- regmatches(sql, gregexpr("'[^']+'", sql))[[1]]
      if (length(areas) >= 4) gsub("'", "", areas[4]) else "Delivery"
    } else {
      "Delivery"
    }
    
    # Parse description
    desc <- if (grepl("description.*'([^']+)'", sql)) {
      # Find all quoted strings and get the description (usually 5th)
      strings <- regmatches(sql, gregexpr("'[^']+'", sql))[[1]]
      if (length(strings) >= 5) gsub("'", "", strings[5]) else "Mock issue"
    } else {
      "Mock issue"
    }
    
    # Parse owner
    owner <- if (grepl("owner.*'([^']+)'", sql)) {
      strings <- regmatches(sql, gregexpr("'[^']+'", sql))[[1]]
      # Owner is typically 6th
      if (length(strings) >= 6) gsub("'", "", strings[6]) else "system"
    } else {
      "system"
    }
    
    # Parse due_date
    due_date <- if (grepl("due_date.*'([0-9]{4}-[0-9]{2}-[0-9]{2})'", sql)) {
      as.Date(gsub(".*due_date.*'([0-9]{4}-[0-9]{2}-[0-9]{2})'.*", "\\1", sql))
    } else {
      Sys.Date() + 7
    }
    
    # Parse linked_entry_id
    linked_entry_id <- if (grepl("linked_entry_id.*([0-9]+)[^0-9]*\\)", sql)) {
      as.integer(gsub(".*linked_entry_id.*?([0-9]+)[^0-9]*\\).*", "\\1", sql))
    } else {
      NA_integer_
    }
    
    new_issue <- data.frame(
      issue_id = issue_id,
      issue_type = issue_type,
      source_tier = source_tier,
      target_tier = target_tier,
      status = "OPEN",
      functional_area = func_area,
      sqdcp_category = sqdcp_cat,
      description = desc,
      owner = owner,
      due_date = due_date,
      created_by = owner,
      created_at = Sys.time(),
      linked_entry_id = linked_entry_id,
      stringsAsFactors = FALSE
    )
    
    .mock_data$issues <- rbind(.mock_data$issues, new_issue)
    return(invisible(TRUE))
    
  } else if (grepl("^UPDATE issues", sql, ignore.case = TRUE)) {
    # Update issue
    if (grepl("WHERE issue_id = ([0-9]+)", sql)) {
      issue_id <- as.integer(gsub(".*WHERE issue_id = ([0-9]+).*", "\\1", sql))
      
      idx <- which(.mock_data$issues$issue_id == issue_id)
      if (length(idx) > 0) {
        # Update status if present
        if (grepl("status = '([^']+)'", sql)) {
          status <- gsub(".*status = '([^']+)'.*", "\\1", sql)
          .mock_data$issues$status[idx] <- status
        }
        
        # Update issue_type if present
        if (grepl("issue_type = '([^']+)'", sql)) {
          issue_type <- gsub(".*issue_type = '([^']+)'.*", "\\1", sql)
          .mock_data$issues$issue_type[idx] <- issue_type
        }
        
        # Increment target_tier if present
        if (grepl("target_tier = target_tier \\+ 1", sql)) {
          .mock_data$issues$target_tier[idx] <- .mock_data$issues$target_tier[idx] + 1L
        }
      }
      return(invisible(TRUE))
    }
    
  } else if (grepl("^INSERT INTO attendance", sql, ignore.case = TRUE)) {
    attendance_id <- .mock_data$next_attendance_id
    .mock_data$next_attendance_id <- .mock_data$next_attendance_id + 1L
    
    new_attendance <- data.frame(
      attendance_id = attendance_id,
      tier_level = 1L,
      meeting_date = Sys.Date(),
      functional_area = "OPS",
      person_name = "User",
      present_bool = TRUE,
      notes = NA_character_,
      stringsAsFactors = FALSE
    )
    
    .mock_data$attendance <- rbind(.mock_data$attendance, new_attendance)
    return(invisible(TRUE))
    
  } else if (grepl("^INSERT INTO meetings", sql, ignore.case = TRUE)) {
    meeting_id <- .mock_data$next_meeting_id
    .mock_data$next_meeting_id <- .mock_data$next_meeting_id + 1L
    
    new_meeting <- data.frame(
      meeting_id = meeting_id,
      tier_level = 1L,
      meeting_date = Sys.Date(),
      scheduled_start_time = NA_character_,
      timebox_minutes = 8L,
      facilitator_name = NA_character_,
      stringsAsFactors = FALSE
    )
    
    .mock_data$meetings <- rbind(.mock_data$meetings, new_meeting)
    return(invisible(TRUE))
  }
  
  # Default: success
  return(invisible(TRUE))
}

# Helper functions from db.R

sql_quote <- function(x) {
  if (is.null(x) || is.na(x) || x == "") return("NULL")
  paste0("'", gsub("'", "''", as.character(x)), "'")
}

sql_bool <- function(x) {
  if (isTRUE(x)) return("TRUE")
  return("FALSE")
}

db_is_available <- function() {
  # Always return TRUE in stub mode (mock data is "available")
  return(TRUE)
}
