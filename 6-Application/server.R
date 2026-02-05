# =============================================================================
# TierPulse – server.R
# Application layer – Main server logic
# Initialises modules and handles home dashboard + admin screens.
# =============================================================================

library(shiny)
library(DT)

server <- function(input, output, session) {

  # =========================================================================
  # Home / Operational Pulse
  # =========================================================================

  output$kpi_not_met <- renderText({
    invalidateLater(30000, session)  # auto-refresh every 30s
    as.character(count_not_met_today())
  })

  output$kpi_open <- renderText({
    invalidateLater(30000, session)
    as.character(count_open_issues())
  })

  output$kpi_overdue <- renderText({
    invalidateLater(30000, session)
    as.character(count_overdue_issues())
  })

  output$kpi_db_status <- renderText({
    if (db_is_available()) "Connected" else "Disconnected"
  })

  output$home_latest_issues <- DT::renderDataTable({
    invalidateLater(30000, session)
    issues <- get_latest_issues(5)
    if (nrow(issues) == 0) {
      return(DT::datatable(data.frame(Message = "No issues yet.")))
    }
    display <- issues[, c("issue_id", "issue_type", "status", "functional_area",
                           "description", "owner", "due_date", "created_at")]
    DT::datatable(display, options = list(pageLength = 5, dom = "t"), rownames = FALSE) |>
      DT::formatStyle(
        "status",
        backgroundColor = DT::styleEqual(
          c("OPEN", "IN_PROGRESS", "RESOLVED", "VERIFIED"),
          c("#f8d7da", "#fff3cd", "#d4edda", "#cce5ff")
        )
      )
  })

  # =========================================================================
  # Tier 1 modules
  # =========================================================================
  mod_board_tier1_server("t1_board")
  mod_input_tier1_server("t1_input")
  mod_attendance_server("t1_attendance", tier_level = 1)

  # =========================================================================
  # Tier 2 modules
  # =========================================================================
  mod_board_tier2_server("t2_board")
  mod_input_tier2_server("t2_input")
  mod_attendance_server("t2_attendance", tier_level = 2)

  # =========================================================================
  # Action Hub module
  # =========================================================================
  mod_action_hub_server("action_hub")

  # =========================================================================
  # Admin / Config
  # =========================================================================

  output$admin_metrics_table <- DT::renderDataTable({
    input$admin_refresh
    input$admin_add_btn
    input$admin_reseed

    metrics <- get_all_metrics()
    if (nrow(metrics) == 0) {
      return(DT::datatable(data.frame(Message = "No metric definitions. Click Re-seed.")))
    }
    DT::datatable(metrics, options = list(pageLength = 25), rownames = FALSE)
  })

  # Re-seed defaults
  observeEvent(input$admin_reseed, {
    source("R/seed.R")
    seed_metrics_if_empty()
    output$admin_feedback <- renderUI(
      div(style = "color:#28a745;", p(strong("Seed operation complete. Refresh to see results.")))
    )
  })

  # Add new metric
  observeEvent(input$admin_add_btn, {
    if (trimws(input$admin_name) == "" || trimws(input$admin_area) == "") {
      output$admin_feedback <- renderUI(
        div(style = "color:#dc3545;", p(strong("Metric Name and Functional Area are required.")))
      )
      return()
    }

    sql <- sprintf(
      "INSERT INTO metric_definitions (tier_level, sqdcp_category, functional_area,
         metric_name, metric_prompt, target_text, active_bool)
       VALUES (%d, %s, %s, %s, %s, %s, %s)",
      as.integer(input$admin_tier),
      sql_quote(input$admin_category),
      sql_quote(input$admin_area),
      sql_quote(input$admin_name),
      sql_quote(input$admin_prompt),
      sql_quote(input$admin_target),
      sql_bool(input$admin_active)
    )
    db_execute(sql)

    output$admin_feedback <- renderUI(
      div(style = "color:#28a745;", p(strong("Metric definition added. Refresh table.")))
    )
  })
}
