# =============================================================================
# TierPulse – R/modules/mod_attendance.R
# Application layer – Attendance tracking module (shared for Tier 1 & 2)
# =============================================================================

# UI ---
mod_attendance_ui <- function(id) {

  ns <- shiny::NS(id)

  tagList(
    h4("Attendance Tracker"),

    fluidRow(
      column(3,
        dateInput(ns("meeting_date"), "Meeting Date", value = Sys.Date())
      ),
      column(3,
        selectInput(ns("area_select"), "Functional Area",
                    choices = c("All", FUNCTIONAL_AREAS_TIER1, FUNCTIONAL_AREAS_TIER2),
                    selected = "All")
      ),
      column(3,
        textInput(ns("person_name"), "Person Name", value = "")
      ),
      column(3,
        checkboxInput(ns("present"), "Present?", value = TRUE)
      )
    ),

    fluidRow(
      column(6,
        textInput(ns("notes"), "Notes", value = "")
      ),
      column(3,
        br(),
        actionButton(ns("add_record"), "Add Attendance", icon = icon("plus"),
                     class = "btn-success")
      ),
      column(3,
        br(),
        actionButton(ns("refresh"), "Refresh", icon = icon("sync"),
                     class = "btn-primary")
      )
    ),

    hr(),
    h4("Attendance Records"),
    DT::dataTableOutput(ns("attendance_table")),

    uiOutput(ns("attendance_feedback"))
  )
}

# Server ---
# tier_level is passed as a parameter when calling this module
mod_attendance_server <- function(id, tier_level) {
  moduleServer(id, function(input, output, session) {

    ns <- session$ns

    attendance_data <- reactive({
      input$refresh
      input$add_record
      get_attendance(tier_level = tier_level, meeting_date = input$meeting_date)
    })

    output$attendance_table <- DT::renderDataTable({
      att <- attendance_data()
      if (nrow(att) == 0) {
        return(DT::datatable(data.frame(Message = "No attendance records for this date.")))
      }
      DT::datatable(att, options = list(pageLength = 20), rownames = FALSE)
    })

    observeEvent(input$add_record, {
      if (trimws(input$person_name) == "") {
        output$attendance_feedback <- renderUI(
          div(style = "color:#dc3545;", p(strong("Person name is required.")))
        )
        return()
      }

      area <- if (input$area_select == "All") "" else input$area_select

      save_attendance(
        tier_level      = tier_level,
        meeting_date    = input$meeting_date,
        functional_area = area,
        person_name     = input$person_name,
        present_bool    = isTRUE(input$present),
        notes           = input$notes
      )

      output$attendance_feedback <- renderUI(
        div(style = "color:#28a745;", p(strong("Attendance record added.")))
      )
    })
  })
}
