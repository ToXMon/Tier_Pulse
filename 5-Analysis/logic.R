# =============================================================================
# TierPulse – 5-Analysis/logic.R
# Analysis layer – core business rules, queries, forced issue
# creation, promotion logic.
# Per Data Theory: Analysis code lives here, sourced by 6-Application.
# =============================================================================

source("R/db.R")
library(dplyr)
library(lubridate)

stub_mode <- db_is_stub_mode()
stub_env  <- get_stub_env()

# Helper: join entries with metric definitions in stub mode
stub_join_entries <- function(entries_df, tier_filter = NULL, date_filter = NULL, start_date = NULL, end_date = NULL) {
  if (is.null(stub_env)) return(data.frame())
  defs <- stub_env$metric_definitions
  if (!is.null(tier_filter)) {
    defs <- defs[defs$tier_level == tier_filter, ]
  }
  entries <- entries_df
  if (!is.null(date_filter)) {
    entries <- entries[as.character(entries$entry_date) == as.character(date_filter), ]
  }
  if (!is.null(start_date) && !is.null(end_date)) {
    entries <- entries[entries$entry_date >= as.Date(start_date) & entries$entry_date <= as.Date(end_date), ]
  }
  merged <- merge(entries, defs, by = "metric_id", all.x = TRUE, suffixes = c("", "_md"))
  if (nrow(merged) == 0) return(merged)
  merged <- merged[order(merged$sqdcp_category, merged$functional_area, merged$metric_name, merged$entry_date), ]
  merged
}

# ---------------------------------------------------------------------------
# Metric Definitions
# ---------------------------------------------------------------------------

#' Get active metric definitions for a tier level
get_metrics_for_tier <- function(tier) {
  if (stub_mode && !is.null(stub_env)) {
    res <- stub_env$metric_definitions
    res <- res[res$tier_level == tier & res$active_bool, ]
    return(res[order(res$sqdcp_category, res$functional_area, res$metric_name), ])
  }
  sql <- sprintf(
    "SELECT * FROM metric_definitions WHERE tier_level = %d AND active_bool = TRUE
     ORDER BY sqdcp_category, functional_area, metric_name",
    as.integer(tier)
  )
  db_read(sql)
}

#' Get all metric definitions
get_all_metrics <- function() {
  if (stub_mode && !is.null(stub_env)) {
    return(stub_env$metric_definitions[order(stub_env$metric_definitions$tier_level,
                                             stub_env$metric_definitions$sqdcp_category,
                                             stub_env$metric_definitions$functional_area), ])
  }
  db_read("SELECT * FROM metric_definitions ORDER BY tier_level, sqdcp_category, functional_area")
}

# ---------------------------------------------------------------------------
# Metric Entries
# ---------------------------------------------------------------------------

#' Get entries for a given date and tier
get_entries_for_date <- function(entry_date, tier) {
  if (stub_mode && !is.null(stub_env)) {
    merged <- stub_join_entries(stub_env$metric_entries, tier_filter = tier, date_filter = entry_date)
    return(merged)
  }
  sql <- sprintf(
    "SELECT me.*, md.metric_name, md.metric_prompt, md.sqdcp_category,
            md.functional_area, md.target_text
     FROM metric_entries me
     JOIN metric_definitions md ON me.metric_id = md.metric_id
     WHERE me.entry_date = '%s' AND md.tier_level = %d
     ORDER BY md.sqdcp_category, md.functional_area",
    as.character(entry_date), as.integer(tier)
  )
  db_read(sql)
}

#' Get entries for a date range (for rolling grids)
get_entries_date_range <- function(start_date, end_date, tier) {
  if (stub_mode && !is.null(stub_env)) {
    merged <- stub_join_entries(stub_env$metric_entries, tier_filter = tier,
                                start_date = start_date, end_date = end_date)
    return(merged)
  }
  sql <- sprintf(
    "SELECT me.*, md.metric_name, md.metric_prompt, md.sqdcp_category,
            md.functional_area, md.target_text
     FROM metric_entries me
     JOIN metric_definitions md ON me.metric_id = md.metric_id
     WHERE me.entry_date BETWEEN '%s' AND '%s' AND md.tier_level = %d
     ORDER BY md.functional_area, md.sqdcp_category, me.entry_date",
    as.character(start_date), as.character(end_date), as.integer(tier)
  )
  db_read(sql)
}

#' Save or update a single metric entry.
#' Returns the entry_id (existing or new).
#' CORE RULE: if status == NOT_MET, forces issue creation.
save_metric_entry <- function(metric_id, entry_date, status,
                              value_text = NULL, explanation_text = NULL,
                              is_escalated = FALSE, created_by = "system") {

  if (stub_mode && !is.null(stub_env)) {
    existing <- stub_env$metric_entries[
      stub_env$metric_entries$metric_id == metric_id &
        as.character(stub_env$metric_entries$entry_date) == as.character(entry_date),
      , drop = FALSE
    ]

    if (nrow(existing) > 0) {
      idx <- rownames(existing)[1]
      row_idx <- as.integer(idx)
      stub_env$metric_entries$status[row_idx]            <- status
      stub_env$metric_entries$value_text[row_idx]        <- value_text
      stub_env$metric_entries$explanation_text[row_idx]  <- explanation_text
      stub_env$metric_entries$is_escalated_bool[row_idx] <- is_escalated
      stub_env$metric_entries$created_by[row_idx]        <- created_by
      entry_id <- stub_env$metric_entries$entry_id[row_idx]
    } else {
      entry_id <- stub_env$counters$entry_id
      stub_env$counters$entry_id <- stub_env$counters$entry_id + 1L
      stub_env$metric_entries <- rbind(
        stub_env$metric_entries,
        data.frame(
          entry_id = entry_id,
          metric_id = metric_id,
          entry_date = as.Date(entry_date),
          status = status,
          value_text = value_text,
          explanation_text = explanation_text,
          is_escalated_bool = isTRUE(is_escalated),
          created_at = Sys.time(),
          created_by = created_by,
          stringsAsFactors = FALSE
        )
      )
    }

    if (status == "NOT_MET" && !is.na(entry_id)) {
      metric_info <- stub_env$metric_definitions[stub_env$metric_definitions$metric_id == metric_id, ]
      if (nrow(metric_info) > 0) {
        mi <- metric_info[1, ]
        issue_type  <- if (isTRUE(is_escalated)) "ESCALATION" else "ACTION"
        target_tier <- if (issue_type == "ESCALATION") mi$tier_level + 1 else mi$tier_level
        existing_issue <- stub_env$issues[stub_env$issues$linked_entry_id == entry_id, ]
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
    # Insert new entry
    sql <- sprintf(
      "INSERT INTO metric_entries (metric_id, entry_date, status, value_text,
         explanation_text, is_escalated_bool, created_by)
       VALUES (%d, '%s', %s, %s, %s, %s, %s)
       RETURNING entry_id",
      as.integer(metric_id),
      as.character(entry_date),
      sql_quote(status),
      sql_quote(value_text),
      sql_quote(explanation_text),
      sql_bool(is_escalated),
      sql_quote(created_by)
    )
    con <- get_db_connection()
    if (!is.null(con)) {
      result <- tryCatch(dbGetQuery(con, sql), error = function(e) data.frame())
      disconnect_db(con)
      entry_id <- if (nrow(result) > 0) result$entry_id[1] else NA
    } else {
      entry_id <- NA
    }
  }

  # FORCED ISSUE CREATION for NOT_MET

  if (status == "NOT_MET" && !is.na(entry_id)) {
    # Get metric info for issue description
    metric_info <- db_read(sprintf(
      "SELECT * FROM metric_definitions WHERE metric_id = %d", as.integer(metric_id)
    ))
    if (nrow(metric_info) > 0) {
      mi <- metric_info[1, ]
      # Business rule: if is_escalated == TRUE (default for NOT_MET in Tier 1 UI),
      # create ESCALATION targeting next tier. If user unchecks → ACTION (local).
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

# ---------------------------------------------------------------------------
# Issues (Actions & Escalations)
# ---------------------------------------------------------------------------

#' Create a new issue
create_issue <- function(issue_type, source_tier, target_tier,
                         functional_area, sqdcp_category, description,
                         owner = NULL, due_date = NULL, created_by = "system",
                         linked_entry_id = NULL) {

  if (stub_mode && !is.null(stub_env)) {
    issue_id <- stub_env$counters$issue_id
    stub_env$counters$issue_id <- stub_env$counters$issue_id + 1L
    stub_env$issues <- rbind(
      stub_env$issues,
      data.frame(
        issue_id = issue_id,
        issue_type = issue_type,
        source_tier = source_tier,
        target_tier = target_tier,
        status = "OPEN",
        functional_area = functional_area,
        sqdcp_category = sqdcp_category,
        description = description,
        owner = owner,
        due_date = if (is.null(due_date) || is.na(due_date)) as.Date(NA) else as.Date(due_date),
        created_at = Sys.time(),
        created_by = created_by,
        linked_entry_id = if (is.null(linked_entry_id)) NA_integer_ else linked_entry_id,
        stringsAsFactors = FALSE
      )
    )
    return(invisible(TRUE))
  }

  sql <- sprintf(
    "INSERT INTO issues (issue_type, source_tier, target_tier, status,
       functional_area, sqdcp_category, description, owner, due_date,
       created_by, linked_entry_id)
     VALUES (%s, %d, %d, 'OPEN', %s, %s, %s, %s, %s, %s, %s)",
    sql_quote(issue_type),
    as.integer(source_tier),
    as.integer(target_tier),
    sql_quote(functional_area),
    sql_quote(sqdcp_category),
    sql_quote(description),
    sql_quote(owner),
    if (is.null(due_date) || is.na(due_date)) "NULL" else paste0("'", due_date, "'"),
    sql_quote(created_by),
    if (is.null(linked_entry_id) || is.na(linked_entry_id)) "NULL" else as.character(linked_entry_id)
  )
  db_execute(sql)
}

#' Get all issues (with optional filters)
get_issues <- function(status_filter = NULL, type_filter = NULL,
                       tier_filter = NULL, target_tier_filter = NULL,
                       area_filter = NULL) {
  if (stub_mode && !is.null(stub_env)) {
    issues <- stub_env$issues
    if (!is.null(status_filter) && status_filter != "All") {
      issues <- issues[issues$status == status_filter, ]
    }
    if (!is.null(type_filter) && type_filter != "All") {
      issues <- issues[issues$issue_type == type_filter, ]
    }
    if (!is.null(tier_filter) && tier_filter != "All") {
      issues <- issues[issues$source_tier == tier_filter, ]
    }
    if (!is.null(target_tier_filter)) {
      issues <- issues[issues$target_tier == target_tier_filter, ]
    }
    if (!is.null(area_filter) && area_filter != "All") {
      issues <- issues[issues$functional_area == area_filter, ]
    }
    issues <- issues[order(issues$created_at, decreasing = TRUE), ]
    return(issues)
  }
  where_clauses <- c()

  if (!is.null(status_filter) && status_filter != "All") {
    where_clauses <- c(where_clauses, sprintf("i.status = %s", sql_quote(status_filter)))
  }
  if (!is.null(type_filter) && type_filter != "All") {
    where_clauses <- c(where_clauses, sprintf("i.issue_type = %s", sql_quote(type_filter)))
  }
  if (!is.null(tier_filter) && tier_filter != "All") {
    where_clauses <- c(where_clauses, sprintf("i.source_tier = %d", as.integer(tier_filter)))
  }
  if (!is.null(target_tier_filter)) {
    where_clauses <- c(where_clauses, sprintf("i.target_tier = %d", as.integer(target_tier_filter)))
  }
  if (!is.null(area_filter) && area_filter != "All") {
    where_clauses <- c(where_clauses, sprintf("i.functional_area = %s", sql_quote(area_filter)))
  }

  where_sql <- if (length(where_clauses) > 0) {
    paste("WHERE", paste(where_clauses, collapse = " AND "))
  } else {
    ""
  }

  sql <- paste0(
    "SELECT i.* FROM issues i ", where_sql,
    " ORDER BY i.created_at DESC"
  )
  db_read(sql)
}

#' Get open issues for a target tier
get_open_issues_for_tier <- function(target_tier) {
  if (stub_mode && !is.null(stub_env)) {
    issues <- stub_env$issues
    issues <- issues[issues$target_tier == target_tier & issues$status %in% c("OPEN", "IN_PROGRESS"), ]
    return(issues[order(issues$created_at, decreasing = TRUE), ])
  }
  sql <- sprintf(
    "SELECT * FROM issues WHERE target_tier = %d AND status IN ('OPEN', 'IN_PROGRESS')
     ORDER BY created_at DESC",
    as.integer(target_tier)
  )
  db_read(sql)
}

#' Promote an ACTION to an ESCALATION – increments target_tier
promote_to_escalation <- function(issue_id) {
  if (stub_mode && !is.null(stub_env)) {
    idx <- which(stub_env$issues$issue_id == issue_id & stub_env$issues$issue_type == "ACTION")
    if (length(idx) > 0) {
      stub_env$issues$issue_type[idx] <- "ESCALATION"
      stub_env$issues$target_tier[idx] <- stub_env$issues$target_tier[idx] + 1L
    }
    return(invisible(TRUE))
  }
  sql <- sprintf(
    "UPDATE issues SET issue_type = 'ESCALATION', target_tier = target_tier + 1
     WHERE issue_id = %d AND issue_type = 'ACTION'",
    as.integer(issue_id)
  )
  db_execute(sql)
}

#' Update issue status
update_issue_status <- function(issue_id, new_status) {
  if (stub_mode && !is.null(stub_env)) {
    idx <- which(stub_env$issues$issue_id == issue_id)
    if (length(idx) > 0) {
      stub_env$issues$status[idx] <- new_status
    }
    return(invisible(TRUE))
  }
  sql <- sprintf(
    "UPDATE issues SET status = %s WHERE issue_id = %d",
    sql_quote(new_status), as.integer(issue_id)
  )
  db_execute(sql)
}

# ---------------------------------------------------------------------------
# Dashboard / Home aggregates
# ---------------------------------------------------------------------------

#' Count of NOT_MET entries for today
count_not_met_today <- function() {
  if (stub_mode && !is.null(stub_env)) {
    today <- Sys.Date()
    return(sum(stub_env$metric_entries$entry_date == today & stub_env$metric_entries$status == "NOT_MET"))
  }
  sql <- sprintf(
    "SELECT COUNT(*) AS n FROM metric_entries WHERE entry_date = '%s' AND status = 'NOT_MET'",
    as.character(Sys.Date())
  )
  result <- db_read(sql)
  if (nrow(result) > 0) result$n[1] else 0
}

#' Count of open issues
count_open_issues <- function() {
  if (stub_mode && !is.null(stub_env)) {
    return(sum(stub_env$issues$status %in% c("OPEN", "IN_PROGRESS")))
  }
  result <- db_read("SELECT COUNT(*) AS n FROM issues WHERE status IN ('OPEN', 'IN_PROGRESS')")
  if (nrow(result) > 0) result$n[1] else 0
}

#' Count of overdue issues
count_overdue_issues <- function() {
  if (stub_mode && !is.null(stub_env)) {
    today <- Sys.Date()
    return(sum(stub_env$issues$status %in% c("OPEN", "IN_PROGRESS") & !is.na(stub_env$issues$due_date) & stub_env$issues$due_date < today))
  }
  sql <- sprintf(
    "SELECT COUNT(*) AS n FROM issues
     WHERE status IN ('OPEN', 'IN_PROGRESS') AND due_date < '%s'",
    as.character(Sys.Date())
  )
  result <- db_read(sql)
  if (nrow(result) > 0) result$n[1] else 0
}

#' Latest N issues
get_latest_issues <- function(n = 5) {
  if (stub_mode && !is.null(stub_env)) {
    issues <- stub_env$issues[order(stub_env$issues$created_at, decreasing = TRUE), ]
    if (nrow(issues) == 0) return(issues)
    return(utils::head(issues, n))
  }
  sql <- sprintf("SELECT * FROM issues ORDER BY created_at DESC LIMIT %d", as.integer(n))
  db_read(sql)
}

# ---------------------------------------------------------------------------
# Attendance
# ---------------------------------------------------------------------------

#' Save attendance record
save_attendance <- function(tier_level, meeting_date, functional_area,
                            person_name, present_bool, notes = NULL) {
  if (stub_mode && !is.null(stub_env)) {
    attendance_id <- stub_env$counters$attendance_id
    stub_env$counters$attendance_id <- stub_env$counters$attendance_id + 1L
    stub_env$attendance <- rbind(
      stub_env$attendance,
      data.frame(
        attendance_id = attendance_id,
        tier_level = tier_level,
        meeting_date = as.Date(meeting_date),
        functional_area = functional_area,
        person_name = person_name,
        present_bool = isTRUE(present_bool),
        notes = notes,
        stringsAsFactors = FALSE
      )
    )
    return(invisible(TRUE))
  }
  sql <- sprintf(
    "INSERT INTO attendance (tier_level, meeting_date, functional_area, person_name, present_bool, notes)
     VALUES (%d, '%s', %s, %s, %s, %s)",
    as.integer(tier_level),
    as.character(meeting_date),
    sql_quote(functional_area),
    sql_quote(person_name),
    sql_bool(present_bool),
    sql_quote(notes)
  )
  db_execute(sql)
}

#' Get attendance for a meeting
get_attendance <- function(tier_level, meeting_date) {
  if (stub_mode && !is.null(stub_env)) {
    att <- stub_env$attendance
    att <- att[att$tier_level == tier_level & att$meeting_date == as.Date(meeting_date), ]
    return(att[order(att$functional_area, att$person_name), ])
  }
  sql <- sprintf(
    "SELECT * FROM attendance WHERE tier_level = %d AND meeting_date = '%s'
     ORDER BY functional_area, person_name",
    as.integer(tier_level), as.character(meeting_date)
  )
  db_read(sql)
}

# ---------------------------------------------------------------------------
# Meetings
# ---------------------------------------------------------------------------

#' Save meeting record
save_meeting <- function(tier_level, meeting_date, scheduled_start_time = NULL,
                         timebox_minutes = 8, facilitator_name = NULL) {
  if (stub_mode && !is.null(stub_env)) {
    meeting_id <- stub_env$counters$meeting_id
    stub_env$counters$meeting_id <- stub_env$counters$meeting_id + 1L
    stub_env$meetings <- rbind(
      stub_env$meetings,
      data.frame(
        meeting_id = meeting_id,
        tier_level = tier_level,
        meeting_date = as.Date(meeting_date),
        scheduled_start_time = if (is.null(scheduled_start_time)) as.POSIXct(NA) else as.POSIXct(scheduled_start_time),
        timebox_minutes = timebox_minutes,
        facilitator_name = facilitator_name,
        created_at = Sys.time(),
        stringsAsFactors = FALSE
      )
    )
    return(invisible(TRUE))
  }
  sql <- sprintf(
    "INSERT INTO meetings (tier_level, meeting_date, scheduled_start_time, timebox_minutes, facilitator_name)
     VALUES (%d, '%s', %s, %d, %s)",
    as.integer(tier_level),
    as.character(meeting_date),
    if (is.null(scheduled_start_time)) "NULL" else paste0("'", scheduled_start_time, "'"),
    as.integer(timebox_minutes),
    sql_quote(facilitator_name)
  )
  db_execute(sql)
}

# ---------------------------------------------------------------------------
# Functional areas list (used across UI)
# ---------------------------------------------------------------------------

FUNCTIONAL_AREAS_TIER1 <- c("OPS", "Warehouse", "Planning", "Shopfloor", "QA Release")
FUNCTIONAL_AREAS_TIER2 <- c("Quality", "Delivery", "People", "Safety", "Facilities")
SQDCP_CATEGORIES <- c("Safety", "Quality", "Delivery", "Cost", "People")

# Status color / icon mapping
STATUS_COLORS <- list(
  MET     = list(color = "#28a745", icon = "check-circle",  label = "MET"),
  TBD     = list(color = "#ffc107", icon = "question-circle", label = "TBD"),
  NOT_MET = list(color = "#dc3545", icon = "times-circle",  label = "NOT MET")
)
