# Initialization -------------------------------------------------------
output_root <- "osm_match"

# Define regions to analyse
regions <- data.frame(
  name = character(),
  gtfs_url = character(),
  geofabrik_region = character(),
  query = I(list())
)
data <- read.csv(system.file("extdata", "gtfs_sources_pt.csv", package = "GTFShift"))

# Lisbon Metro Area -------------------------------------------------------
## Carris Metropolitana -----------------------------------
regions <- bind_rows(
  regions,
  data.frame(
    name = "AML",
    # For historical versions, refer to https://mobilitydatabase.org/feeds/gtfs/mdb-2027
    # gtfs_url = data$URL[data$ID == "AML"],
    gtfs_url = "https://github.com/U-Shift/GTFShift/releases/download/v0.9/gtfs_AML_2026-05-27.zip",
    # gtfs_day = as.character(Sys.Date()),
    gtfs_day = "2026-05-27",
    gtfs_day_filter = TRUE,
    gtfs_manipulate = "manipulate_gtfs_aml",
    query = I(list(list(
      list(key = "route", value = c("bus"), key_exact = TRUE),
      list(key = "network", value = "Carris Metropolitana", key_exact = TRUE)
    ))),
    geofabrik_region = "europe/portugal",
    metric_crs = 3763,
    osm_stop_order_relaxed = TRUE
  )
)

# Helpers -----------------------------------
manipulate_gtfs_aml <- function(gtfs) {
  # Rename all shapes that start with [.*], remove that part
  gtfs$shapes$shape_id <- gsub("^\\[[^]]*\\]\\s*", "", gtfs$shapes$shape_id)
  gtfs$trips$shape_id <- gsub("^\\[[^]]*\\]\\s*", "", gtfs$trips$shape_id)
  return(gtfs)
}
