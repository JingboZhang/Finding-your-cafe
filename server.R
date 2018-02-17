
library(shiny)
library(leaflet)
library(sqldf)

shinyServer(function(input, output) {
    # data cleaning
    data <- read.csv('data.csv', header = TRUE)
    # since there're lots of duplicate rows representing same coffee shops, we can remove these duplicate rows
    distinct_cafe <- sqldf('SELECT CafeID, MAX(inspectionID) AS MAX FROM data GROUP BY CafeID', row.names=TRUE)
    data <- sqldf('SELECT * FROM data, distinct_cafe 
                  WHERE data.CafeID=distinct_cafe.CafeID 
                  AND data.InspectionID=distinct_cafe.MAX')
    # only keep columns that we needed
    data <- subset(data, select=c('X', 'Y', 'CafeID', 'CafeName', 'OwnerName', 
                                  'Address', 'Quadrant', 'NeighborhoodNames', 
                                  'StartHourForOpening1', 'EndHourForOpening1',
                                  'HasSitePlan', 'HasABRALicense', 'NumberOfTables', 'NumberOfChairs', 
                                  'HasBusStopWithIn20ft', 'HasStreetLightWithIn20ft', 'IsVisibleToPublic',
                                  'HasParkingMeterWithIn20ft', 'HasNoParkingWithIn20FtOfCurb', 
                                  'HasRushHourAM', 'HasRushHourPM'
    ))
    
    # calculate the avg longitude and latitude of each neighborhood
    # use this as the zoom center of each neighborhood
    Neighbor_zoom <- sqldf('SELECT NeighborhoodNames, AVG(X) AS longitude, AVG(Y) AS latitude
                           FROM data
                           WHERE NeighborhoodNames != ""
                           GROUP BY NeighborhoodNames')
    Neighbor_zoom$NeighborhoodNames <- as.character(Neighbor_zoom$NeighborhoodNames)
    
    # calculate avg longitude and latitude of all data
    # use this as the original zoom center
    Neighbor_zoom <- rbind(Neighbor_zoom, c('All', mean(data$X), mean(data$Y)))
    Neighbor_zoom$longitude <- as.numeric(Neighbor_zoom$longitude)
    Neighbor_zoom$latitude <- as.numeric(Neighbor_zoom$latitude)
    
    # get neighborhood list based on the quadrant user chooses
    neighbor_list <- reactive({
        subdata <- subset(data, Quadrant == input$district)
        neighbor_data <- sqldf('SELECT NeighborhoodNames, COUNT(*) AS count 
                               FROM subdata 
                               GROUP BY NeighborhoodNames 
                               ORDER BY count DESC')
        subset(neighbor_data, NeighborhoodNames != '' & count >= 5)$NeighborhoodNames
    })
    
    # return the neighborhood list as a select box
    output$neighbor_select <- renderUI({
        selectInput("neighbor", "Select a neighborhood to zoom", neighbor_list()) 
    })
    
    # show whole data table
    output$data <- renderDataTable({
      subset(data, select = c('CafeName', 'Address'))
    })
    
    # create a subset data based on user's choice
    subdata <- reactive({
        # based on quadrant
        subdata <- subset(data, Quadrant == input$district)
        # has chairs and tables that are greater than user's choice
        subdata <- subset(subdata, NumberOfTables >= input$num_table)
        subdata <- subset(subdata, NumberOfChairs >= input$num_chair)
        # satisfy check box 
        if ('1' %in% input$option)
            subdata <- subset(subdata, HasSitePlan == 1)
        if ('2' %in% input$option)
            subdata <- subset(subdata, HasABRALicense == 1)
        if ('3' %in% input$option)
            subdata <- subset(subdata, HasBusStopWithIn20ft == 1)
        if ('4' %in% input$option)
            subdata <- subset(subdata, IsVisibleToPublic == 1)
        if ('5' %in% input$option)
            subdata <- subset(subdata, HasNoParkingWithIn20FtOfCurb == 0)
        if ('6' %in% input$option)
            subdata <- subset(subdata, HasParkingMeterWithIn20ft == 1)
        subdata
    })
    
    # original zoom center
    zoom_value <- reactiveValues(lon=subset(Neighbor_zoom, NeighborhoodNames=='All')$longitude,
                                 lat=subset(Neighbor_zoom, NeighborhoodNames=='All')$latitude,
                                 zoom=12) 
    
    # return a new zoom center after clicking on 'zoom'
    observeEvent(input$zoom_neighbor, {
        zoom_value$lon <- subset(Neighbor_zoom, NeighborhoodNames==input$neighbor)$longitude
        zoom_value$lat <- subset(Neighbor_zoom, NeighborhoodNames==input$neighbor)$latitude
        zoom_value$zoom <- 16
    })
    
    # return the original zoom center after clicking on 'rezoom'
    observeEvent(input$rezoom, {
        zoom_value$lon <- subset(Neighbor_zoom, NeighborhoodNames=='All')$longitude
        zoom_value$lat <- subset(Neighbor_zoom, NeighborhoodNames=='All')$latitude
        zoom_value$zoom <- 12
    })
    
    # orange value box
    output$num_subdata <- renderValueBox({
        valueBox(
            nrow(subdata()), 'number of cafe satisfying requirement',
            icon = icon("coffee"),
            color = "orange"
        )
    })
    
    # red value box 
    output$num_neighbor <- renderValueBox({
        valueBox(
            nrow(subset(subdata(), NeighborhoodNames == input$neighbor)),
            'number of cafe in this neighborhood',
            icon = icon("thumbs-up", lib = "glyphicon"),
            color = "red"
        )
    })
    
    # map output
    output$map <- renderLeaflet({
        
        # create icon
        url <- 'https://s3.amazonaws.com/msbabobo/resizeApi.png'
        cafeIcon <- makeIcon(
            iconUrl = url,
            iconWidth = 36, iconHeight = 36,
            iconAnchorX = 18, iconAnchorY = 18
        )
        
        # edit the content of popup
        content <- paste('Name: ', subdata()$CafeName, '<br/>',
                         'Address: ', subdata()$Address, '<br/>',
                         'Operation time: ', 
                         ifelse(subdata()$StartHourForOpening1 == '' | subdata()$EndHourForOpening1 == '',
                                'N/A', paste(subdata()$StartHourForOpening1, 
                                            ' - ', subdata()$EndHourForOpening1)
                             ))
        
        # plot the map
        leaflet() %>% 
            setView(zoom_value$lon, zoom_value$lat, zoom=zoom_value$zoom) %>%
            addTiles() %>%
            addMarkers(lng=subdata()$X, lat=subdata()$Y, popup=content, icon=cafeIcon) 
    })
    
    # show the subset based on user's choices
    output$subdata <- renderDataTable({
        subset(subdata(), select = c('CafeName', 'Address'))
    })
    
  
})
