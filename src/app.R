library(shiny)
library(leaflet)
library(dplyr)
library(tidyr)
library(bslib)
library(leaflet.extras)
library(htmltools)
library(htmlwidgets)
library(RColorBrewer)

##
map_data <- read.csv("res/map_data2022-02-13.csv")

city_columns <- c("city", "lat", "lng", "country", "province")
warning_columns <- c("Warning", "Message")
column_columns <-
  c(
    "city",
    "lat",
    "lng",
    "country",
    "province",
    "Warning",
    "Message",
    "wet_bulb_temperature_today",
    "popup_info",
    "city_name_search"
  )
colnames(map_data) <- column_columns
cat(colnames(map_data))
##
threshold_benchmark <-
  data.frame(
    city = c("NOTREALCITY"),
    lat = c(179),
    lng = c(179),
    country = c("NOTREALCOUNTRY"),
    province = c("NOTREALPROVINCE"),
    Warning = c("Red"),
    Message = c("<b><font color='red'>Red</font></b> warning on NEVER"),
    wet_bulb_temperature_today = c(95),
    popup_info = c(
      "<img src= https://live.staticflickr.com/65535/51359614069_e968c76f10_o.png/> <br/> <b>NOTREALCITY</b> <br/> NOTREALPROVINCE <br/> <b><font color='red'>Red</font></b> warning on NEVER"
    ),
    city_name_search = c("0")
  )
map_data <- rbind(map_data, threshold_benchmark)
##
map_data <- map_data %>%
  mutate(
    warning_code = case_when(
      Warning == "Red" ~ 1,
      Warning == "Orange" ~ 2,
      Warning == "White" ~ 3,
      Warning == "Grey" ~ 4
    )
  )

map_data

choices = c(
  "Red" = 1,
  "Orange" = 2,
  "White" = 3,
  "No Data" = 4
)

default_choices = choices[1:3]

colorpal <- colorNumeric(
  palette = "RdYlGn",
  domain = map_data$wet_bulb_temperature_today,
  na.color = "#808080",
  alpha = FALSE,
  reverse = TRUE
)

#map_data <- map_data[1:12,]
ui <- bootstrapPage(
  tags$style(
    type = "text/css",
    "html, body {width:100%;height:100%}",
    "
        #controls {
            background-color: #fff;
            opacity: 0.5;
            border-radius: 4px;
            //text-align:center;
            box-shadow: 0 0 15px rgba(0,0,0,0.8);
            padding-left: 16px;
            padding-top: 16px;
            padding-bottom: 16px;
            -moz-box-sizing: border-box;
            box-sizing: border-box;
            transition: opacity 1s ease-out;
        }
        #controls:hover{
            opacity: 1;
            transition: opacity 1s ease-out;
        }
        "
  ),
  theme = bs_theme(version = 4, bootswatch = "materia"),
  leafletOutput("map", width = '100%', height = '100%'),
  
  absolutePanel(
    id = "controls",
    class = "panel panel-default",
    fixed = F,
    draggable = TRUE,
    top = 45,
    left = "auto",
    right = 10,
    bottom = "auto",
    width = 330,
    height = "auto",
    
    h2("Wet Heat Warnings"),
    
    sliderInput(
      inputId = "sliderin",
      label = "Wet Bulb Temperature (°F)",
      min = min(map_data$wet_bulb_temperature_today),
      max = max(map_data$wet_bulb_temperature_today),
      value = range(map_data$wet_bulb_temperature_today),
      step = 0.1
    ), 
    
    checkboxInput("legend", "Display legend", TRUE),
    
    actionButton(inputId = "Reset", label = "Reset to Defaults")
  )
)

server <- function(input, output, session) {
  output$map <- renderLeaflet({
    leaflet(map_data) %>% addProviderTiles(providers$OpenStreetMap) %>%
      setMaxBounds(-180, -90, 180, 90) %>%
      setView(lng = 0,
              lat = 20,
              zoom = 2.5) %>%
      addCircles(
        lng = ~ lng,
        lat = ~ lat,
        weight = 12,
        fillOpacity = 0.5,
        radius = 6000,
        color = ~ colorpal(wet_bulb_temperature_today),
        popup = ~ popup_info,
        label = ~ city_name_search,
        group = "cities"
      ) %>%
      addResetMapButton() %>%
      addEasyButton(easyButton(
        icon = "fa-crosshairs",
        title = "Locate Me",
        onClick = JS("function(btn, map){ map.locate({setView: true}); }")
      )) %>%
      addSearchFeatures(
        targetGroups = "cities",
        options = searchFeaturesOptions(
          zoom = 7,
          openPopup = TRUE,
          firstTipSubmit = TRUE,
          autoCollapse = TRUE,
          hideMarkerOnCollapse = TRUE,
          position = "topright"
        )
      ) %>%
      addMiniMap(width = 150,
                 height = 150,
                 toggleDisplay = T) %>%
      addLegend(
        title = "Wet Bulb<br>Temperature",
        labFormat = labelFormat(
          suffix= "°F"
        ),
        pal = colorpal,
        position = "bottomleft",
        layerId = "legendLayer",
        values = ~wet_bulb_temperature_today
      )
  })
  
  mydata_filtered <- reactive({
    map_data[map_data$wet_bulb_temperature_today >= input$sliderin[1] &
               map_data$wet_bulb_temperature_today <= input$sliderin[2], ]
  })
  
  observe({
    leafletProxy("map", data = mydata_filtered()) %>%
      setMaxBounds(-180, -90, 180, 90) %>%
      clearGroup("cities") %>%
      addCircles(
        lng = ~ lng,
        lat = ~ lat,
        weight = 12,
        fillOpacity = 0.5,
        radius = 6000,
        color = ~ colorpal(wet_bulb_temperature_today),
        popup = ~ popup_info,
        label = ~ city_name_search,
        group = "cities"
      ) %>%
      addResetMapButton() %>%
      addEasyButton(easyButton(
        icon = "fa-crosshairs",
        title = "Locate Me",
        onClick = JS("function(btn, map){ map.locate({setView: true}); }")
      )) %>%
      addSearchFeatures(
        targetGroups = "cities",
        options = searchFeaturesOptions(
          zoom = 7,
          openPopup = TRUE,
          firstTipSubmit = TRUE,
          autoCollapse = TRUE,
          hideMarkerOnCollapse = TRUE,
          position = "topright"
        )
      ) %>%
      addMiniMap(width = 150,
                 height = 150,
                 toggleDisplay = T)
  })
  
  observe({
    proxy <- leafletProxy("map", data = mydata_filtered())
    proxy %>% removeControl("legendLayer")
    if (input$legend) {
      proxy %>% addLegend(
        title = "Wet Bulb<br>Temperature",
        labFormat = labelFormat(
          suffix= "°F"
        ),
        pal = colorpal,
        position = "bottomleft",
        layerId = "legendLayer",
        values = ~wet_bulb_temperature_today
      )
    }
  })
  
  observeEvent(input$Reset, {
    updateSliderInput(
      session = session,
      inputId = "sliderin",
      label = "Wet Bulb Temperature (°F)",
      min = min(map_data$wet_bulb_temperature_today),
      max = max(map_data$wet_bulb_temperature_today),
      value = range(map_data$wet_bulb_temperature_today),
      step = 0.1
    )
    updateCheckboxInput(
      session = session,
      inputId = "legend",
      label = "Display legend",
      value = TRUE
    )
  })
  
}
# Run the application
shinyApp(ui = ui, server = server)