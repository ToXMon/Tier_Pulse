# =============================================================================
# TierPulse – R/migrate.R
# Governance layer – runs SQL migrations to create tables if they do not exist.
# =============================================================================

source("R/db.R")

#' Run all SQL migration scripts found in ./sql/ (in alphabetical order).
#' Each script is expected to be idempotent (CREATE TABLE IF NOT EXISTS).
run_migrations <- function() {

  sql_dir <- file.path("sql")
  if (!dir.exists(sql_dir)) {
    message("[TierPulse] sql/ directory not found – skipping migrations.")
    return(invisible(FALSE))
  }


  sql_files <- sort(list.files(sql_dir, pattern = "\\.sql$", full.names = TRUE))
  if (length(sql_files) == 0) {
    message("[TierPulse] No SQL migration files found.")
    return(invisible(FALSE))
  }

  con <- get_db_connection()
  if (is.null(con)) {
    warning("[TierPulse] Cannot run migrations – database unreachable.")
    return(invisible(FALSE))
  }
  on.exit(disconnect_db(con))

  for (f in sql_files) {
    message(paste0("[TierPulse] Running migration: ", basename(f)))
    sql_text <- paste(readLines(f, warn = FALSE), collapse = "\n")

    # Split on semicolons to execute individual statements
    statements <- strsplit(sql_text, ";")[[1]]
    statements <- trimws(statements)
    statements <- statements[nchar(statements) > 0]

    for (stmt in statements) {
      tryCatch(
        dbExecute(con, stmt),
        error = function(e) {
          warning(paste0("[TierPulse] Migration statement error: ", e$message,
                         "\n  Statement: ", substr(stmt, 1, 120)))
        }
      )
    }
  }

  message("[TierPulse] Migrations complete.")
  return(invisible(TRUE))
}
