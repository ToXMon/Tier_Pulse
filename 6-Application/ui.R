# =============================================================================
# TierPulse – ui.R
# Application layer – Main UI definition (orchestrator per Data Theory)
# Sources analysis modules from 5-Analysis per repository structure guidance.
# Uses bslib for lightweight Bootstrap 5 styling with navbar layout.
# =============================================================================

library(shiny)
library(bslib)
library(DT)

# Source database layer first (from R/ for Shiny working directory compatibility)
source("R/db.R")

# Source analysis logic and modules from 5-Analysis (per Data Theory structure)
source("../5-Analysis/logic.R")
source("../5-Analysis/modules/mod_board_tier1.R")
source("../5-Analysis/modules/mod_input_tier1.R")
source("../5-Analysis/modules/mod_board_tier2.R")
source("../5-Analysis/modules/mod_input_tier2.R")
source("../5-Analysis/modules/mod_action_hub.R")
source("../5-Analysis/modules/mod_attendance.R")

# ---------------------------------------------------------------------------
# UI Definition
# ---------------------------------------------------------------------------

ui <- page_navbar(
  title = "TierPulse",
  theme = bs_theme(
    version   = 5,
    bootswatch = "flatly",
    primary   = "#2c3e50",
    success   = "#28a745",
    warning   = "#ffc107",
    danger    = "#dc3545"
  ),
  header = tags$head(
    tags$style(HTML("
      .board-mode-tile { min-height: 120px; }
      .status-met     { background-color: #28a745 !important; color: white; }
      .status-tbd     { background-color: #ffc107 !important; color: black; }
      .status-not-met { background-color: #dc3545 !important; color: white; }
      .timer-danger   { background-color: #dc3545 !important; color: white; }
      .card-body      { padding: 15px; }
      body            { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; }
    "))
  ),

  # =========================================================================
  # Tab 1: Home / Operational Pulse
  # =========================================================================
  nav_panel(
    "Operational Pulse",
    icon = icon("heartbeat"),
    div(
      class = "container-fluid",
      style = "padding-top: 15px;",
      h2("Operational Pulse Dashboard"),
      hr(),

      # KPI cards
      fluidRow(
        column(3,
          div(class = "card text-white bg-danger mb-3",
            div(class = "card-body",
              h5(class = "card-title", "NOT MET Today"),
              h2(class = "card-text", textOutput("kpi_not_met", inline = TRUE))
            )
          )
        ),
        column(3,
          div(class = "card text-white bg-warning mb-3",
            div(class = "card-body",
              h5(class = "card-title", "Open Issues"),
              h2(class = "card-text", textOutput("kpi_open", inline = TRUE))
            )
          )
        ),
        column(3,
          div(class = "card text-white bg-dark mb-3",
            div(class = "card-body",
              h5(class = "card-title", "Overdue Issues"),
              h2(class = "card-text", textOutput("kpi_overdue", inline = TRUE))
            )
          )
        ),
        column(3,
          div(class = "card text-white bg-info mb-3",
            div(class = "card-body",
              h5(class = "card-title", "DB Status"),
              h2(class = "card-text", textOutput("kpi_db_status", inline = TRUE))
            )
          )
        )
      ),

      hr(),
      h4("Latest Issues"),
      DT::dataTableOutput("home_latest_issues")
    )
  ),

  # =========================================================================
  # Tab 2: Tier 1
  # =========================================================================
  nav_panel(
    "Tier 1",
    icon = icon("clipboard-list"),
    navset_tab(
      nav_panel("Board",   mod_board_tier1_ui("t1_board")),
      nav_panel("Input",   mod_input_tier1_ui("t1_input")),
      nav_panel("Attendance", mod_attendance_ui("t1_attendance"))
    )
  ),

  # =========================================================================
  # Tab 3: Tier 2
  # =========================================================================
  nav_panel(
    "Tier 2",
    icon = icon("layer-group"),
    navset_tab(
      nav_panel("Board",   mod_board_tier2_ui("t2_board")),
      nav_panel("Input",   mod_input_tier2_ui("t2_input")),
      nav_panel("Attendance", mod_attendance_ui("t2_attendance"))
    )
  ),

  # =========================================================================
  # Tab 4: Action Hub
  # =========================================================================
  nav_panel(
    "Action Hub",
    icon = icon("tasks"),
    mod_action_hub_ui("action_hub")
  ),

  # =========================================================================
  # Tab 5: Admin / Config
  # =========================================================================
  nav_panel(
    "Admin",
    icon = icon("cog"),
    div(
      class = "container-fluid",
      style = "padding-top: 15px;",
      h3("Admin – Metric Definitions"),
      p("Below are the currently configured metric definitions. Seed defaults are loaded on first run."),
      actionButton("admin_refresh", "Refresh", icon = icon("sync"), class = "btn-primary"),
      actionButton("admin_reseed", "Re-seed Defaults (if empty)", icon = icon("database"),
                   class = "btn-warning"),
      hr(),
      DT::dataTableOutput("admin_metrics_table"),

      hr(),
      h4("Add New Metric Definition"),
      wellPanel(
        fluidRow(
          column(2, selectInput("admin_tier", "Tier", choices = c(1, 2))),
          column(2, selectInput("admin_category", "SQDCP", choices = SQDCP_CATEGORIES)),
          column(2, textInput("admin_area", "Functional Area", value = "")),
          column(3, textInput("admin_name", "Metric Name", value = "")),
          column(3, textInput("admin_prompt", "Prompt", value = ""))
        ),
        fluidRow(
          column(4, textInput("admin_target", "Target Text", value = "")),
          column(4, checkboxInput("admin_active", "Active?", value = TRUE)),
          column(4, actionButton("admin_add_btn", "Add Metric", icon = icon("plus"),
                                 class = "btn-success"))
        )
      ),
      uiOutput("admin_feedback")
    )
  )
)
