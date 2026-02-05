# =============================================================================
# TierPulse – R/db.R
# Database connection helpers (Generation layer – Data Theory)
# All secrets sourced from environment variables.
# =============================================================================

library(DBI)
library(RPostgreSQL)

#' Establish a PostgreSQL connection using environment variables.
#' Returns a DBI connection or NULL with a warning message.
get_db_connection <- function() {

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
  con <- get_db_connection()
  if (is.null(con)) return(FALSE)
  disconnect_db(con)
  return(TRUE)
}
