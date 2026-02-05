# =============================================================================
# TierPulse – R/modules/mod_input_tier1.R
# Application layer – Tier 1 Input view module
# Table-form to enter/update today's metric entries by functional area.
# Enforces conditional validation: NOT_MET requires explanation, defaults escalation.
# =============================================================================

# UI ---
mod_input_tier1_ui <- function(id) {

  ns <- shiny::NS(id)

  tagList(
    fluidRow(
      column(4,
        dateInput(ns("entry_date"), "Entry Date", value = Sys.Date())
      ),
      column(4,
        selectInput(ns("area_select"), "Functional Area",
                    choices = FUNCTIONAL_AREAS_TIER1, selected = FUNCTIONAL_AREAS_TIER1[1])
      ),
      column(4,
        textInput(ns("created_by"), "Your Name", value = "")
      )
    ),

    hr(),
    h4("Metrics Input"),
    uiOutput(ns("input_form")),

    hr(),
    actionButton(ns("save_all"), "Save All Entries", icon = icon("save"),
                 class = "btn-primary btn-lg"),
    br(), br(),
    uiOutput(ns("save_feedback"))
  )
}

# Server ---
mod_input_tier1_server <- function(id) {
  moduleServer(id, function(input, output, session) {

    ns <- session$ns

    # Get metrics for selected area
    area_metrics <- reactive({
      metrics <- get_metrics_for_tier(1)
      metrics[metrics$functional_area == input$area_select, ]
    })

    # Render dynamic input form
    output$input_form <- renderUI({
      metrics <- area_metrics()
      if (nrow(metrics) == 0) return(p("No active metrics for this area."))

      # Check existing entries for this date
      existing <- get_entries_for_date(input$entry_date, tier = 1)

      form_rows <- lapply(seq_len(nrow(metrics)), function(i) {
        m <- metrics[i, ]
        mid <- m$metric_id
        prefix <- paste0("m_", mid)

        # Pre-fill from existing
        ex <- existing[existing$metric_id == mid, ]
        current_status <- if (nrow(ex) > 0) ex$status[1] else "TBD"
        current_value  <- if (nrow(ex) > 0 && !is.na(ex$value_text[1])) ex$value_text[1] else ""
        current_expl   <- if (nrow(ex) > 0 && !is.na(ex$explanation_text[1])) ex$explanation_text[1] else ""
        current_esc    <- if (nrow(ex) > 0) ex$is_escalated_bool[1] else TRUE

        wellPanel(
          style = "margin-bottom:8px; padding:10px;",
          fluidRow(
            column(3,
              strong(m$metric_name),
              br(),
              tags$small(m$metric_prompt),
              br(),
              tags$em(paste("Target:", m$target_text))
            ),
            column(2,
              selectInput(ns(paste0(prefix, "_status")), NULL,
                          choices = c("MET", "TBD", "NOT_MET"),
                          selected = current_status)
            ),
            column(2,
              textInput(ns(paste0(prefix, "_value")), "Value", value = current_value)
            ),
            column(3,
              textAreaInput(ns(paste0(prefix, "_explanation")), "Explanation",
                            value = current_expl, rows = 2)
            ),
            column(2,
              checkboxInput(ns(paste0(prefix, "_escalate")), "Escalate?",
                            value = current_esc)
            )
          )
        )
      })

      do.call(tagList, form_rows)
    })

    # Auto-set escalation when NOT_MET
    observe({
      metrics <- area_metrics()
      if (nrow(metrics) == 0) return()

      for (i in seq_len(nrow(metrics))) {
        mid <- metrics$metric_id[i]
        prefix <- paste0("m_", mid)
        status_id <- paste0(prefix, "_status")
        esc_id    <- paste0(prefix, "_escalate")

        status_val <- input[[status_id]]
        if (!is.null(status_val) && status_val == "NOT_MET") {
          updateCheckboxInput(session, esc_id, value = TRUE)
        }
      }
    })

    # Save all entries
    observeEvent(input$save_all, {
      metrics <- area_metrics()
      if (nrow(metrics) == 0) return()

      errors   <- c()
      saved    <- 0

      for (i in seq_len(nrow(metrics))) {
        m <- metrics[i, ]
        mid <- m$metric_id
        prefix <- paste0("m_", mid)

        status_val <- input[[paste0(prefix, "_status")]]
        value_val  <- input[[paste0(prefix, "_value")]]
        expl_val   <- input[[paste0(prefix, "_explanation")]]
        esc_val    <- input[[paste0(prefix, "_escalate")]]

        if (is.null(status_val)) next

        # Validation: NOT_MET requires explanation
        if (status_val == "NOT_MET" && (is.null(expl_val) || trimws(expl_val) == "")) {
          errors <- c(errors, paste0(m$metric_name, ": explanation required for NOT_MET."))
          next
        }

        created_by <- if (trimws(input$created_by) != "") input$created_by else "system"

        save_metric_entry(
          metric_id        = mid,
          entry_date       = input$entry_date,
          status           = status_val,
          value_text       = value_val,
          explanation_text = expl_val,
          is_escalated     = isTRUE(esc_val),
          created_by       = created_by
        )
        saved <- saved + 1
      }

      output$save_feedback <- renderUI({
        msgs <- c()
        if (saved > 0) msgs <- c(msgs, paste0(saved, " entries saved successfully."))
        if (length(errors) > 0) msgs <- c(msgs, paste0("Errors: ", paste(errors, collapse = "; ")))

        div(
          style = if (length(errors) > 0) "color:#dc3545;" else "color:#28a745;",
          lapply(msgs, function(m) p(strong(m)))
        )
      })
    })
  })
}
