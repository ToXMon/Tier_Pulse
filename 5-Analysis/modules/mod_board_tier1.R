# =============================================================================
# TierPulse – R/modules/mod_board_tier1.R
# Application layer – Tier 1 Board view module
# Status tiles + 6-day rolling SQDCP grid + open issues + meeting timer
# =============================================================================

# UI ---
mod_board_tier1_ui <- function(id) {

  ns <- shiny::NS(id)

  tagList(
    # -- Controls row --
    fluidRow(
      column(3,
        checkboxInput(ns("board_mode"), "Board Mode (large)", value = TRUE)
      ),
      column(3,
        checkboxInput(ns("exception_only"), "Exception Only (hide MET)", value = FALSE)
      ),
      column(3,
        selectInput(ns("area_filter"), "Functional Area",
                    choices = c("All", FUNCTIONAL_AREAS_TIER1), selected = "All")
      ),
      column(3,
        actionButton(ns("refresh"), "Refresh", icon = icon("sync"), class = "btn-primary")
      )
    ),

    hr(),

    # -- Meeting Timer --
    fluidRow(
      column(12,
        div(id = ns("timer_container"),
          style = "text-align:center; padding:10px; border:2px solid #ccc; border-radius:8px; margin-bottom:15px;",
          h4("Tier 1 Meeting Timer"),
          uiOutput(ns("timer_display")),
          actionButton(ns("start_timer"), "Start", icon = icon("play"), class = "btn-success btn-sm"),
          actionButton(ns("reset_timer"), "Reset", icon = icon("redo"), class = "btn-warning btn-sm")
        )
      )
    ),

    # -- Status tiles --
    h3("Status Tiles by Functional Area"),
    uiOutput(ns("status_tiles")),

    hr(),

    # -- 6-day rolling grid --
    h3("6-Day Rolling SQDCP Grid"),
    DT::dataTableOutput(ns("rolling_grid")),

    hr(),

    # -- Open issues --
    h3("Open Issues (Tier 1)"),
    DT::dataTableOutput(ns("open_issues_table"))
  )
}

# Server ---
mod_board_tier1_server <- function(id) {
  moduleServer(id, function(input, output, session) {

    ns <- session$ns

    # Timer state
    timer_val      <- reactiveVal(8 * 60)  # 8 minutes in seconds
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
      timer_val(8 * 60)
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

    # Data reactive
    board_data <- reactive({
      input$refresh  # trigger
      today <- Sys.Date()
      start <- today - 5
      entries <- get_entries_date_range(start, today, tier = 1)
      entries
    })

    # Status tiles
    output$status_tiles <- renderUI({
      entries <- board_data()
      today <- Sys.Date()
      today_entries <- entries[entries$entry_date == today, ]

      areas <- if (input$area_filter == "All") FUNCTIONAL_AREAS_TIER1 else input$area_filter
      font_size <- if (input$board_mode) "28px" else "16px"
      tile_padding <- if (input$board_mode) "25px" else "12px"

      tile_list <- lapply(areas, function(area) {
        area_entries <- today_entries[today_entries$functional_area == area, ]

        if (nrow(area_entries) == 0) {
          status <- "TBD"
        } else if (any(area_entries$status == "NOT_MET")) {
          status <- "NOT_MET"
        } else if (any(area_entries$status == "TBD")) {
          status <- "TBD"
        } else {
          status <- "MET"
        }

        # Exception only filter
        if (input$exception_only && status == "MET") return(NULL)

        sc <- STATUS_COLORS[[status]]

        column(
          width = if (input$board_mode) 4 else 2,
          div(
            style = sprintf(
              "background:%s; color:white; padding:%s; margin:5px; border-radius:10px; text-align:center; min-height:100px;",
              sc$color, tile_padding
            ),
            icon(sc$icon, style = sprintf("font-size:%s;", font_size)),
            h4(style = sprintf("font-size:%s; margin-top:5px;", font_size), area),
            p(style = "font-size:14px; margin:0;", sc$label)
          )
        )
      })

      tile_list <- Filter(Negate(is.null), tile_list)
      if (length(tile_list) == 0) {
        return(p("All metrics MET – nothing to show in exception mode."))
      }
      do.call(fluidRow, tile_list)
    })

    # 6-day rolling grid
    output$rolling_grid <- DT::renderDataTable({
      entries   <- board_data()
      metrics   <- get_metrics_for_tier(1)
      today     <- Sys.Date()
      date_cols <- seq(today - 5, today, by = "day")

      if (input$area_filter != "All") {
        metrics <- metrics[metrics$functional_area == input$area_filter, ]
      }

      if (nrow(metrics) == 0) return(DT::datatable(data.frame(Message = "No metrics found")))

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
        options = list(pageLength = 25, dom = "t", ordering = FALSE),
        rownames = FALSE,
        escape = FALSE
      ) |>
        DT::formatStyle(
          columns = 4:ncol(grid),
          backgroundColor = DT::styleEqual(
            c("MET", "TBD", "NOT_MET"),
            c("#d4edda", "#fff3cd", "#f8d7da")
          )
        )
    })

    # Open issues table
    output$open_issues_table <- DT::renderDataTable({
      input$refresh
      issues <- get_open_issues_for_tier(1)
      if (nrow(issues) == 0) {
        return(DT::datatable(data.frame(Message = "No open issues for Tier 1")))
      }

      display <- issues[, c("issue_id", "issue_type", "status", "functional_area",
                             "sqdcp_category", "description", "owner", "due_date")]
      DT::datatable(display, options = list(pageLength = 10), rownames = FALSE)
    })
  })
}
