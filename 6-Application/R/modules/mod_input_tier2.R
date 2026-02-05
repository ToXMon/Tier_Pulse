# =============================================================================
# TierPulse – R/modules/mod_input_tier2.R
# Application layer – Tier 2 Input view module
# Weekly assessment style entry; link Tier 1 issues.
# =============================================================================

# UI ---
mod_input_tier2_ui <- function(id) {

  ns <- shiny::NS(id)

  tagList(
    fluidRow(
      column(4,
        dateInput(ns("entry_date"), "Assessment Date", value = Sys.Date())
      ),
      column(4,
        selectInput(ns("area_select"), "Functional Area",
                    choices = FUNCTIONAL_AREAS_TIER2, selected = FUNCTIONAL_AREAS_TIER2[1])
      ),
      column(4,
        textInput(ns("created_by"), "Your Name", value = "")
      )
    ),

    hr(),
    h4("Tier 2 Metrics Assessment"),
    uiOutput(ns("input_form")),

    hr(),
    h4("Open Tier 1 Issues (available to link)"),
    DT::dataTableOutput(ns("tier1_issues")),

    hr(),
    actionButton(ns("save_all"), "Save Assessment", icon = icon("save"),
                 class = "btn-primary btn-lg"),
    br(), br(),
    uiOutput(ns("save_feedback"))
  )
}

# Server ---
mod_input_tier2_server <- function(id) {
  moduleServer(id, function(input, output, session) {

    ns <- session$ns

    area_metrics <- reactive({
      metrics <- get_metrics_for_tier(2)
      metrics[metrics$functional_area == input$area_select, ]
    })

    output$input_form <- renderUI({
      metrics <- area_metrics()
      if (nrow(metrics) == 0) return(p("No active Tier 2 metrics for this area."))

      existing <- get_entries_for_date(input$entry_date, tier = 2)

      form_rows <- lapply(seq_len(nrow(metrics)), function(i) {
        m <- metrics[i, ]
        mid <- m$metric_id
        prefix <- paste0("m_", mid)

        ex <- existing[existing$metric_id == mid, ]
        current_status <- if (nrow(ex) > 0) ex$status[1] else "TBD"
        current_value  <- if (nrow(ex) > 0 && !is.na(ex$value_text[1])) ex$value_text[1] else ""
        current_expl   <- if (nrow(ex) > 0 && !is.na(ex$explanation_text[1])) ex$explanation_text[1] else ""
        current_esc    <- if (nrow(ex) > 0) ex$is_escalated_bool[1] else FALSE

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

    # Show open Tier 1 issues for linking / context
    output$tier1_issues <- DT::renderDataTable({
      issues <- get_open_issues_for_tier(1)
      tier1_esc <- get_issues(target_tier_filter = 2)
      all_issues <- rbind(issues, tier1_esc)
      all_issues <- all_issues[!duplicated(all_issues$issue_id), ]

      if (nrow(all_issues) == 0) {
        return(DT::datatable(data.frame(Message = "No open Tier 1 issues")))
      }

      display <- all_issues[, c("issue_id", "issue_type", "status", "functional_area",
                                 "sqdcp_category", "description", "owner", "due_date")]
      DT::datatable(display, options = list(pageLength = 10), rownames = FALSE,
                    selection = "multiple")
    })

    # Save
    observeEvent(input$save_all, {
      metrics <- area_metrics()
      if (nrow(metrics) == 0) return()

      errors <- c()
      saved  <- 0

      for (i in seq_len(nrow(metrics))) {
        m <- metrics[i, ]
        mid <- m$metric_id
        prefix <- paste0("m_", mid)

        status_val <- input[[paste0(prefix, "_status")]]
        value_val  <- input[[paste0(prefix, "_value")]]
        expl_val   <- input[[paste0(prefix, "_explanation")]]
        esc_val    <- input[[paste0(prefix, "_escalate")]]

        if (is.null(status_val)) next

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
        if (saved > 0) msgs <- c(msgs, paste0(saved, " assessments saved."))
        if (length(errors) > 0) msgs <- c(msgs, paste0("Errors: ", paste(errors, collapse = "; ")))

        div(
          style = if (length(errors) > 0) "color:#dc3545;" else "color:#28a745;",
          lapply(msgs, function(m) p(strong(m)))
        )
      })
    })
  })
}
