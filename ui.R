
library(shiny)
library(shinydashboard)
library(leaflet)

shinyUI(dashboardPage(
  
  dashboardHeader(title = h3("Finding Your cafe")),
  
  dashboardSidebar(disable = TRUE),
  
  dashboardBody(
      fluidRow(
          # left side part
          column(width = 4,
                 # box: select location
                 box(title = tagList(shiny::icon("thumb-tack"), "Select location"), 
                     width = NULL, status = "primary", solidHeader = TRUE,
                     
                     # quadrant selection
                     radioButtons('district', 'Select a quadrant to show', 
                                        choices = list('NW','NE', 'SW', 'SE'),
                                        selected = list('NW')),
                     
                     # neighborhood selection
                     uiOutput("neighbor_select"),
                     p(
                         class = "text-muted",
                         paste('Click "zoom" to take a closer look at the selected neighborhood,
                               "rezoom" to look at the original map.'
                         )
                     ),
                     # button 'zoom'
                     actionButton('zoom_neighbor', 'Click to zoom'),
                     
                     # button 'rezoom'
                     actionButton('rezoom', 'Click to rezoom')
                     ),
                 
                 # box: requirement selection
                 box(title = tagList(shiny::icon("list-alt"), "Select requirement"), width = NULL, 
                     status = "primary", solidHeader = TRUE,
                     
                     numericInput('num_chair', 'Enter needed number of chair', value = 2),
                     
                     numericInput('num_table', 'Enter needed number of table', value = 1),
                     
                     checkboxGroupInput('option', 'Select your requirement',
                                        choices = list('site plan'=1, 
                                                       'alcohol provided'=2, 
                                                       'has bus stop nearby'=3, 
                                                       'visible to public'=4,
                                                       'parking provided'=5,
                                                       'has parking meter nearby'=6
                                        ),
                                        selected = list()))
                 
                 ),
          
          # right side part
          column(width = 8,
                 
                 box(width = NULL, 
                     # orange value box
                     valueBoxOutput("num_subdata"),
                     # red value box
                     valueBoxOutput("num_neighbor")
                 ),
                 box(width = NULL, status = "warning",
                     title = tagList(shiny::icon("globe"), "Cafe information"), 
                     solidHeader = TRUE, 
                     tabsetPanel(
                         tabPanel('Cafe Map', leafletOutput('map', height = 500)),
                         tabPanel('Satisfying Cafe', dataTableOutput('subdata')),
                         tabPanel('All Cafe', dataTableOutput('data'))))
                 
                 )
      )
  )
))
