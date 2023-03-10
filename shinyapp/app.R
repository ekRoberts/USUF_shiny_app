library(shiny)
library(leaflet)
library(tidyverse)
library(leaflet.extras2)
library(shinyscreenshot)
library(htmltools)
library(htmlwidgets)

#MAKE SURE YOUR CURRENT WORKING DIRECTORY IS shinyapp (the folder downloaded from github)

r_colors <- rgb(t(col2rgb(colors()) / 255))
names(r_colors) <- colors()

fulL_dataset <- read.csv("Long_Lat_Point_Data.csv")

data_points <- read.csv("Long_Lat_Point_Data.csv") %>%
  select(c("latusedd", "longusedd", "year", "megadbid"))%>%
  na.omit()

data_points$LatandLong <- str_c(data_points$longusedd, ",", data_points$latusedd, ",", data_points$year, ",", data_points$megadbid)  

unique_longandlat <- data_points%>%
  pull(LatandLong) %>% unique() %>% data.frame()

unique_longandlat[c("Long", "Lat", "Year", "megadbid")] <- str_split_fixed(unique_longandlat$., ",", 4)

years <- unique_longandlat %>% pull("Year") %>% unique()

unique_longandlat$Lat<- as.numeric(unique_longandlat$Lat)
unique_longandlat$Long <- as.numeric(unique_longandlat$Long)
unique_longandlat$Year <- as.numeric(unique_longandlat$Year)

elemental_data <- read.csv("MegaDbELEMENTAL_2021.05.30.csv", stringsAsFactors = F) %>%
  select(c("ba_ppm", "al_ppm", "co_ppm", "megadbid"))

elemental_data$ba_ppm <- as.integer(elemental_data$ba_ppm)
elemental_data$al_ppm <- as.integer(elemental_data$al_ppm)
elemental_data$co_ppm <- as.integer(elemental_data$co_ppm)
elemental_data$megadbid <- as.character(elemental_data$megadbid)

## @Emi Categorized ppm 
## @ToDO: updates for thresholds need to be updated. 
## could be good to make this into a function later. 
order = c("Safe", "Moderate", "Toxic", "Lethal")
elemental_data$ba_ppm_categorized <- cut(elemental_data$ba_ppm,
                   breaks=c(-Inf, 5.0, 14.9, 23.2, Inf),
                   labels=order)
## toxic ~> 200.228ppm - 500.571ppm
## lethal ~> 3003.427ppm - 4004.569ppm

elemental_data$al_ppm_categorized <- cut(elemental_data$al_ppm,
                   breaks=c(-Inf, 5.0, 14.9, 23.2, Inf),
                   labels=order)
##legal limit for air ~> 5 mg/m3
## toxic ~> -
## lethal ~> -

elemental_data$co_ppm_categorized <- cut(elemental_data$co_ppm,
                   breaks=c(-Inf, 5.0, 14.9, 23.2, Inf),
                   labels=order)
## normal ~> 0.1 to 2.2 mcg/L in urine sample
## toxic ~> 100 ??g L???1
## lethal ~>  seems to be pretty high

elemental_data$ba_ppm <- factor(elemental_data$ba_ppm_categorized, levels=order)
elemental_data$al_ppm <- factor(elemental_data$al_ppm_categorized, levels=order)
elemental_data$co_ppm <- factor(elemental_data$co_ppm_categorized, levels=order)

plot_elemental_data <- left_join(unique_longandlat, elemental_data, by = "megadbid")

small_sample_data <- head(plot_elemental_data, 5000) #This is where the amt of data points are being used it decided
class(small_sample_data$Year)
small_sample_data$Year <- as.numeric(small_sample_data$Year)
class(small_sample_data)
ba_ppm_color <- colorFactor(palette = "Oranges", small_sample_data$ba_ppm, levels=order, na.color = NA)
co_ppm_color <- colorFactor(palette = "Oranges", small_sample_data$co_ppm, levels=order, na.color = NA)
al_ppm_color <- colorFactor(palette = "Oranges", small_sample_data$al_ppm, levels=order, na.color = NA)

#Emma's original. numerical scale 
# elemental_data$ba_ppm <- as.integer(elemental_data$ba_ppm)
# elemental_data$al_ppm <- as.integer(elemental_data$al_ppm)
# elemental_data$co_ppm <- as.integer(elemental_data$co_ppm)
# elemental_data$megadbid <- as.character(elemental_data$megadbid)
# 
# plot_elemental_data <- left_join(unique_longandlat, elemental_data, by = "megadbid")
# 
# small_sample_data <- head(plot_elemental_data, 1000)
# class(small_sample_data$Year)
# small_sample_data$Year <- as.numeric(small_sample_data$Year)
# class(small_sample_data)
# pal <- colorNumeric(c("green", "yellow","red"), 1:10 )
# ba_ppm_color <- colorBin(palette = pal(c(1:10)), small_sample_data$ba_ppm, 10)
# co_ppm_color <- colorBin(palette = pal(c(1:10)), small_sample_data$co_ppm, 10)
# al_ppm_color <- colorBin(palette = pal(c(1:10)), small_sample_data$al_ppm, 10)


# this controls the front end of the app - how you would add new elements
ui <- fluidPage(
  
  tags$style(type = "text/css", "
             .irs-slider {width: 30px; height: 30px; top: 22px;}
             .irs-grid-text {font-size: 20px}
             .irs--shiny .irs-to, .irs--shiny .irs-from, .irs--shiny .irs-single{ font-size: 17px; color: black; background: transparent}"),
  
  # this renders the map on the page 
  leafletOutput("mymap"),
  p(),
  #this puts the range slider on the page and gives it a max and a min
  sliderInput("range", "Year", min(small_sample_data$Year), 2012, value = range(small_sample_data$Year), step = 1, sep = "",
              width = "40%"),
  
  ## a download button that pdownloads the map from the page 
  downloadButton("mymapDownload", label = "Download Map")
  
  ## a download button that generates the report that made the map
  downloadButton("report", "Generate Report")
)


# the server function controls the backend of the app
server <- function(input, output, session) {

  #this function updates the data whenever the user updates the slider 
  filteredData <- reactive({
    small_sample_data [small_sample_data$Year >= input$range[1] & small_sample_data$Year <= input$range[2],] 
  })

  #this gives the map in the UI output its data
  output$mymap <- renderLeaflet({
    
    # select data
    leaflet(data = small_sample_data) %>%
      addEasyButton(easyButton(
        icon="fa-globe", title="Zoom to Level 1",
        onClick=JS("function(btn, map){ map.setZoom(1); }"))) %>%
      addEasyButton(easyButton(
        icon="fa-crosshairs", title="Locate Me",
        onClick=JS("function(btn, map){ map.locate({setView: true}); }"))) %>%
    #leaflet(data = filteredData()) %>%
      # add differnt map layers
      addProviderTiles(providers$Stamen.TonerLite, options = providerTileOptions(noWrap = TRUE), group = "Basic Map") %>%
      addProviderTiles(providers$Esri.WorldImagery, options = providerTileOptions(noWrap = TRUE), group = "Topographical")%>%
      addProviderTiles(providers$Esri.WorldTopoMap, options = providerTileOptions(noWrap = TRUE), group = "Lined Topographical")%>%
      #addMarkers(~Long, ~Lat, group = "Plot Markers")%>%
      #add the ability to select different layers
      addLayersControl(
        baseGroups = c("Basic Map", "Topographical", "Lined Topographical"),
        overlayGroups = c("Barium", "Cobalt", "Aluminium", "Plot Markers"),
        options = layersControlOptions(collapsed = FALSE)
      )%>%
      #add legends for the element concentrations
    addLegend('bottomleft', pal = ba_ppm_color, values = small_sample_data$ba_ppm,
              title = 'Color Gradient for Barium (parts per million)',
              opacity = 1, group = "Barium")%>%
      addLegend('bottomleft', pal = co_ppm_color, values = small_sample_data$co_ppm,
                title = 'Color Gradient for Cobalt (parts per million)',
                opacity = 1, group = "Cobalt") %>%
      addLegend('bottomleft', pal = al_ppm_color, values = small_sample_data$al_ppm,
                title = 'Color Gradient for Aluminium (parts per million)',
                opacity = 1, group = "Aluminium")%>%
      # don't show these groups till they are selected
      hideGroup(c("Barium", "Aluminium", "Cobalt"))
  })
  
#   #@Emi's addin for downloading the map -- not sure if it works yet. 
#   output$mymapDownload <- downloadHandler(
#       filename = 'USUFMap.png',
#       content = function(file) {
#         #device <- function(..., width, height) {
#         #  grDevices::png(..., width = width, height = height,
#         #                 res = 300, units = "in")
#         #}
#         ggsave(file, plot = "mymap", device = '.png')
#       }
#   )
  
#   #@Emi's addin for downloading the report --- not tested to work 
#   output$report <- downloadHandler(
#       # For PDF output, change this to "report.pdf"
#       filename = "report.html",
#       content = function(file) {
#         # Copy the report file to a temporary directory before processing it, in
#         # case we don't have write permissions to the current working dir (which
#         # can happen when deployed).
#         tempReport <- file.path(tempdir(), "report.Rmd")
#         file.copy("report.Rmd", tempReport, overwrite = TRUE)

#         # Set up parameters to pass to Rmd document
#         params <- list(n = input$slider)

#         # Knit the document, passing in the `params` list, and eval it in a
#         # child of the global environment (this isolates the code in the document
#         # from the code in this app).
#         rmarkdown::render(tempReport, output_file = file,
#           params = params,
#           envir = new.env(parent = globalenv())
#         )
#       }
#     )
  
  #whenever the user selects a different year range the points and circles are updated
  observe({
    leafletProxy("mymap", data = filteredData())%>%
      clearMarkers()%>%
      addMarkers(~Long, ~Lat, group = "Plot Markers")%>%
      clearShapes()%>%
      #addCircles(~Long, ~Lat, ~ba_ppm*500, stroke = F, color = ~ba_ppm_color(ba_ppm),group = "ba_ppm")%>%
      #addCircles(~Long, ~Lat, ~co_ppm*500, stroke = F, color = ~co_ppm_color(co_ppm) ,group = "co_ppm")%>%
      #addCircleMarkers(~Long, ~Lat, ~al_ppm*500, stroke = F, color = ~al_ppm_color(al_ppm) ,group = "al_ppm")
      addCircleMarkers(~Long, ~Lat, radius = 7.5, color = ~circleMarkerOutline(ba_ppm), stroke = T, weight = 0.4, fillColor = ~ba_ppm_color(ba_ppm),fillOpacity = ~factop(ba_ppm), group = "Barium")%>%
      addCircleMarkers(~Long, ~Lat, radius = 7.5, color = ~circleMarkerOutline(co_ppm), stroke = T, weight = 0.4, fillColor = ~co_ppm_color(co_ppm), fillOpacity = ~factop(co_ppm) ,group = "Cobalt")%>%
      addCircleMarkers(~Long, ~Lat, radius = 7.5, color = ~circleMarkerOutline(al_ppm), stroke = T, weight = 0.4, fillColor = ~al_ppm_color(al_ppm), fillOpacity = ~factop(al_ppm) ,group = "Aluminium")
  })
}

shinyApp(ui, server)
