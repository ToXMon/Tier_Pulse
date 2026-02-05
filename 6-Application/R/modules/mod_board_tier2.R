# =============================================================================
# TierPulse – R/modules/mod_board_tier2.R
# Application layer – Tier 2 Board view module
# Functional rollup + 14-day trend grid + open escalations + meeting timer
# =============================================================================

# UI ---
mod_board_tier2_ui <- function(id) {

  ns <- shiny::NS(id)

  tagList(
    fluidRow(
      column(3,
        checkboxInput(ns("board_mode"), "Board Mode (large)", value = TRUE)
      ),
      column(3,
        checkboxInput(ns("exception_only"), "Exception Only (hide MET)", value = FALSE)
      ),
      column(3,
        selectInput(ns("area_filter"), "Functional Area",
                    choices = c("All", FUNCTIONAL_AREAS_TIER2), selected = "All")
      ),
      column(3,
        actionButton(ns("refresh"), "Refresh", icon = icon("sync"), class = "btn-primary")
      )
    ),

    hr(),

    # -- Meeting Timer (15 min) --
    fluidRow(
      column(12,
        div(id = ns("timer_container"),
          style = "text-align:center; padding:10px; border:2px solid #ccc; border-radius:8px; margin-bottom:15px;",
          h4("Tier 2 Meeting Timer"),
          uiOutput(ns("timer_display")),
          actionButton(ns("start_timer"), "Start", icon = icon("play"), class = "btn-success btn-sm"),
          actionButton(ns("reset_timer"), "Reset", icon = icon("redo"), class = "btn-warning btn-sm")
        )
      )
    ),

    # -- Functional area rollup --
    h3("Functional Area Rollup"),
    DT::dataTableOutput(ns("rollup_table")),

    hr(),

    # -- 14-day trend grid --
    h3("14-Day Trend Grid"),
    DT::dataTableOutput(ns("trend_grid")),

    hr(),

    # -- Open escalations targeting Tier 2 --
    h3("Open Escalations Targeting Tier 2"),
    DT::dataTableOutput(ns("escalations_table")),

    hr(),

    # -- Agenda widget --
    h4("Tier 2 Agenda"),
    wellPanel(
      tags$ol(
        tags$li("Review Tier 1 escalations"),
        tags$li("Functional area status review (SQDCP)"),
        tags$li("Cross-functional issues"),
        tags$li("Action items & owners"),
        tags$li("Close-out / next meeting")
      )
    )
  )
}

# Server ---
mod_board_tier2_server <- function(id) {
  moduleServer(id, function(input, output, session) {

    ns <- session$ns

    # Timer state (15 minutes)
    timer_val      <- reactiveVal(15 * 60)
    timer_active   <- reactiveVal(FALSE)
    timer_exceeded <- reactiveVal(FALSE)

    observe({
      invalidateLater(1000, session)
      isolate({
        if (timer_active()) {
          remaining <- timer_val() - 1
          timer_val(remaining)
          if (remaining <= 0) {
            timer_exceeded(TRUE)
          }
        }
      })
    })

    observeEvent(input$start_timer, {
      timer_active(TRUE)
    })

    observeEvent(input$reset_timer, {
      timer_val(15 * 60)
      timer_active(FALSE)
      timer_exceeded(FALSE)
    })

    output$timer_display <- renderUI({
      secs <- timer_val()
      mins <- abs(secs) %/% 60
      s    <- abs(secs) %% 60
      sign <- if (secs < 0) "-" else ""
      label <- sprintf("%s%02d:%02d", sign, mins, s)

      bg_color <- if (timer_exceeded()) "#dc3545" else if (secs < 60 && secs >= 0) "#ffc107" else "#28a745"
      text_color <- if (timer_exceeded()) "white" else "black"
      font_size <- if (input$board_mode) "48px" else "24px"

      div(
        style = sprintf(
          "font-size:%s; font-weight:bold; color:%s; background:%s; display:inline-block; padding:10px 30px; border-radius:8px;",
          font_size, text_color, bg_color
        ),
        label
      )
    })

    # Data
    board_data <- reactive({
      input$refresh
      today <- Sys.Date()
      start <- today - 13
      entries <- get_entries_date_range(start, today, tier = 2)
      entries
    })

    # Functional area rollup
    output$rollup_table <- DT::renderDataTable({
      input$refresh
      today <- Sys.Date()
      today_entries <- get_entries_for_date(today, tier = 2)
      issues_all <- get_open_issues_for_tier(2)

      areas <- if (input$area_filter == "All") FUNCTIONAL_AREAS_TIER2 else input$area_filter

      rollup <- data.frame(
        Area         = character(0),
        Status       = character(0),
        Issues       = character(0),
        Escalations  = integer(0),
        stringsAsFactors = FALSE
      )

      for (area in areas) {
        area_entries <- today_entries[today_entries$functional_area == area, ]
        area_issues  <- issues_all[issues_all$functional_area == area, ]

        if (nrow(area_entries) == 0) {
          status <- "TBD"
        } else if (any(area_entries$status == "NOT_MET")) {
          status <- "NOT_MET"
        } else if (any(area_entries$status == "TBD")) {
          status <- "TBD"
        } else {
          status <- "MET"
        }

        if (input$exception_only && status == "MET") next

        esc_count <- sum(area_issues$issue_type == "ESCALATION")

        rollup <- rbind(rollup, data.frame(
          Area        = area,
          Status      = status,
          Issues      = if (nrow(area_issues) > 0) "Yes" else "No",
          Escalations = esc_count,
          stringsAsFactors = FALSE
        ))
      }

      if (nrow(rollup) == 0) {
        return(DT::datatable(data.frame(Message = "All areas MET or no data.")))
      }

      DT::datatable(rollup, options = list(dom = "t"), rownames = FALSE) |>
        DT::formatStyle(
          "Status",
          backgroundColor = DT::styleEqual(
            c("MET", "TBD", "NOT_MET"),
            c("#d4edda", "#fff3cd", "#f8d7da")
          )
        )
    })

    # 14-day trend grid
    output$trend_grid <- DT::renderDataTable({
      entries <- board_data()
      metrics <- get_metrics_for_tier(2)
      today   <- Sys.Date()
      date_cols <- seq(today - 13, today, by = "day")

      if (input$area_filter != "All") {
        metrics <- metrics[metrics$functional_area == input$area_filter, ]
      }

      if (nrow(metrics) == 0) return(DT::datatable(data.frame(Message = "No Tier 2 metrics")))

      grid <- data.frame(
        Area     = metrics$functional_area,
        Category = metrics$sqdcp_category,
        Metric   = metrics$metric_name,
        stringsAsFactors = FALSE
      )

      for (d in as.character(date_cols)) {
        day_entries <- entries[as.character(entries$entry_date) == d, ]
        grid[[d]] <- sapply(metrics$metric_id, function(mid) {
          match <- day_entries[day_entries$metric_id == mid, ]
          if (nrow(match) > 0) match$status[1] else "—"
        })
      }

      DT::datatable(
        grid,
        options = list(pageLength = 25, dom = "t", scrollX = TRUE, ordering = FALSE),
        rownames = FALSE
      ) |>
        DT::formatStyle(
          columns = 4:ncol(grid),
          backgroundColor = DT::styleEqual(
            c("MET", "TBD", "NOT_MET"),
            c("#d4edda", "#fff3cd", "#f8d7da")
          )
        )
    })

    # Open escalations
    output$escalations_table <- DT::renderDataTable({
      input$refresh
      issues <- get_open_issues_for_tier(2)
      if (nrow(issues) == 0) {
        return(DT::datatable(data.frame(Message = "No open escalations for Tier 2")))
      }

      display <- issues[, c("issue_id", "issue_type", "status", "functional_area",
                             "sqdcp_category", "description", "owner", "due_date", "source_tier")]
      DT::datatable(display, options = list(pageLength = 10), rownames = FALSE)
    })
  })
}
