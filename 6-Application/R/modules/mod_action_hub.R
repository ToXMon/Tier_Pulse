# =============================================================================
# TierPulse – R/modules/mod_action_hub.R
# Application layer – Unified Action Hub module
# All issues table with filters + Promote to Escalation button
# =============================================================================

# UI ---
mod_action_hub_ui <- function(id) {

  ns <- shiny::NS(id)

  tagList(
    h3("Action Hub – Unified Issues Manager"),

    fluidRow(
      column(2,
        selectInput(ns("filter_type"), "Type",
                    choices = c("All", "ACTION", "ESCALATION"), selected = "All")
      ),
      column(2,
        selectInput(ns("filter_status"), "Status",
                    choices = c("All", "OPEN", "IN_PROGRESS", "RESOLVED", "VERIFIED"),
                    selected = "All")
      ),
      column(2,
        selectInput(ns("filter_tier"), "Source Tier",
                    choices = c("All", "1", "2"), selected = "All")
      ),
      column(2,
        selectInput(ns("filter_area"), "Functional Area",
                    choices = c("All", FUNCTIONAL_AREAS_TIER1, FUNCTIONAL_AREAS_TIER2),
                    selected = "All")
      ),
      column(2,
        actionButton(ns("refresh"), "Refresh", icon = icon("sync"), class = "btn-primary")
      ),
      column(2,
        br(),
        actionButton(ns("promote_btn"), "Promote to Escalation",
                     icon = icon("arrow-up"), class = "btn-warning")
      )
    ),

    hr(),

    # -- New issue form --
    h4("Create New Issue"),
    wellPanel(
      fluidRow(
        column(2,
          selectInput(ns("new_type"), "Type", choices = c("ACTION", "ESCALATION"))
        ),
        column(2,
          selectInput(ns("new_source_tier"), "Source Tier", choices = c(1, 2), selected = 1)
        ),
        column(2,
          selectInput(ns("new_target_tier"), "Target Tier", choices = c(1, 2, 3), selected = 2)
        ),
        column(2,
          selectInput(ns("new_area"), "Functional Area",
                      choices = c(FUNCTIONAL_AREAS_TIER1, FUNCTIONAL_AREAS_TIER2))
        ),
        column(2,
          selectInput(ns("new_category"), "SQDCP Category", choices = SQDCP_CATEGORIES)
        ),
        column(2,
          textInput(ns("new_owner"), "Owner", value = "")
        )
      ),
      fluidRow(
        column(6,
          textAreaInput(ns("new_description"), "Description", rows = 2)
        ),
        column(3,
          dateInput(ns("new_due_date"), "Due Date", value = Sys.Date() + 7)
        ),
        column(3,
          br(),
          actionButton(ns("create_issue_btn"), "Create Issue",
                       icon = icon("plus"), class = "btn-success")
        )
      )
    ),

    hr(),

    # -- Issues table --
    DT::dataTableOutput(ns("issues_table")),

    br(),

    # -- Status update --
    fluidRow(
      column(4,
        numericInput(ns("update_issue_id"), "Issue ID to Update", value = NA, min = 1)
      ),
      column(4,
        selectInput(ns("update_status"), "New Status",
                    choices = c("OPEN", "IN_PROGRESS", "RESOLVED", "VERIFIED"))
      ),
      column(4,
        br(),
        actionButton(ns("update_status_btn"), "Update Status",
                     icon = icon("edit"), class = "btn-info")
      )
    ),

    uiOutput(ns("action_feedback"))
  )
}

# Server ---
mod_action_hub_server <- function(id) {
  moduleServer(id, function(input, output, session) {

    ns <- session$ns

    issues_data <- reactive({
      input$refresh
      input$create_issue_btn
      input$promote_btn
      input$update_status_btn

      get_issues(
        status_filter = input$filter_status,
        type_filter   = input$filter_type,
        tier_filter   = input$filter_tier,
        area_filter   = input$filter_area
      )
    })

    output$issues_table <- DT::renderDataTable({
      issues <- issues_data()
      if (nrow(issues) == 0) {
        return(DT::datatable(data.frame(Message = "No issues match filters.")))
      }

      display <- issues[, c("issue_id", "issue_type", "source_tier", "target_tier",
                             "status", "functional_area", "sqdcp_category",
                             "description", "owner", "due_date", "created_at")]

      DT::datatable(
        display,
        options = list(pageLength = 20, order = list(list(10, "desc"))),
        rownames = FALSE,
        selection = "single"
      ) |>
        DT::formatStyle(
          "status",
          backgroundColor = DT::styleEqual(
            c("OPEN", "IN_PROGRESS", "RESOLVED", "VERIFIED"),
            c("#f8d7da", "#fff3cd", "#d4edda", "#cce5ff")
          )
        ) |>
        DT::formatStyle(
          "issue_type",
          backgroundColor = DT::styleEqual(
            c("ACTION", "ESCALATION"),
            c("#e2e3e5", "#f8d7da")
          )
        )
    })

    # Create new issue
    observeEvent(input$create_issue_btn, {
      if (trimws(input$new_description) == "") {
        output$action_feedback <- renderUI(
          div(style = "color:#dc3545;", p(strong("Description is required.")))
        )
        return()
      }

      create_issue(
        issue_type      = input$new_type,
        source_tier     = as.integer(input$new_source_tier),
        target_tier     = as.integer(input$new_target_tier),
        functional_area = input$new_area,
        sqdcp_category  = input$new_category,
        description     = input$new_description,
        owner           = input$new_owner,
        due_date        = as.character(input$new_due_date),
        created_by      = input$new_owner
      )

      output$action_feedback <- renderUI(
        div(style = "color:#28a745;", p(strong("Issue created successfully.")))
      )
    })

    # Promote to escalation
    observeEvent(input$promote_btn, {
      selected <- input$issues_table_rows_selected
      if (is.null(selected) || length(selected) == 0) {
        output$action_feedback <- renderUI(
          div(style = "color:#dc3545;", p(strong("Select an ACTION row to promote.")))
        )
        return()
      }

      issues <- issues_data()
      issue_row <- issues[selected, ]

      if (issue_row$issue_type != "ACTION") {
        output$action_feedback <- renderUI(
          div(style = "color:#dc3545;", p(strong("Only ACTIONs can be promoted to ESCALATION.")))
        )
        return()
      }

      promote_to_escalation(issue_row$issue_id)
      output$action_feedback <- renderUI(
        div(style = "color:#28a745;",
            p(strong(sprintf("Issue #%d promoted to ESCALATION (target tier incremented).",
                             issue_row$issue_id))))
      )
    })

    # Update status
    observeEvent(input$update_status_btn, {
      issue_id <- input$update_issue_id
      if (is.na(issue_id)) {
        output$action_feedback <- renderUI(
          div(style = "color:#dc3545;", p(strong("Enter a valid Issue ID.")))
        )
        return()
      }

      update_issue_status(issue_id, input$update_status)
      output$action_feedback <- renderUI(
        div(style = "color:#28a745;",
            p(strong(sprintf("Issue #%d status updated to %s.", issue_id, input$update_status))))
      )
    })
  })
}
