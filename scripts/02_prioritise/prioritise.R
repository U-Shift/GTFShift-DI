# Script to generate pre-processed data for GTFShift web dashboard

library(GTFShift)
library(dplyr)
library(stringr)
library(sf)
library(mapview)
library(jsonlite)
library(osmdata)
library(Hmisc) # For  Weighted Statistical Estimates
# set_overpass_url("https://overpass-api.de/api/interpreter")

# Run with: $ Rscript 02_prioritise/prioritise.R > 02_prioritise/prioritise_$(date +%Y%m%d_%H%M%S).log 2>&1

# Refer to prioritise_parameters.R to define parameters before running this script!
source("02_prioritise/prioritise_parameters.R")

regions <- regions |>
  # filter(name %in% c("lisboa_rt", "aml_rt", "barreiro", "stcp"))
  filter(name %in% c("aml_rt_area_3"))
#  filter(name %in% c("cascais", "barreiro", "madrid"))
# filter(name %in% c("lisboa_rt")) # , "aml_rt_area_1", "aml_rt_area_2", "aml_rt_area_3", "aml_rt_area_4", "stcp"))

# main()
if (!dir.exists(output)) {
  dir.create(output, recursive = TRUE)
}

message("------------------------------------------------------------------------------------------------------------------------")
message("\n\nRunning for regions:\n > ", paste(regions$name_long, collapse = "\n > "))
message("------------------------------------------------------------------------------------------------------------------------\n\n")

for (i in 1:nrow(regions)) { # i =1
  region <- regions[i, ]
  if (is.null(region$metric_crs) || is.na(region$metric_crs)) {
    stop(sprintf("Please define the metric_crs for region '%s' in prioritise_parameters.R", region$name))
  }

  # 1. Load data for region
  region <- regions[i, ]
  gtfs_day_str <- gsub("-", "", region$gtfs_day)
  run_day <- gsub("-", "", Sys.Date())
  message(sprintf("\n\nRunning for %s (%s)...", region$name, region$gtfs_day))

  output_region <- sprintf("%s/%s/gtfs_%s/run_%s", output, tolower(region$name), gtfs_day_str, format(Sys.time(), "%Y%m%d_%H%M%S"))
  if (!dir.exists(output_region)) {
    dir.create(output_region, recursive = TRUE)
  }

  gtfs <- GTFShift::load_feed(region$gtfs_url, headers = if (!is.null(region$gtfs_url_headers)) unlist(region$gtfs_url_headers[[1]]) else NULL)
  # gtfs <- tidytransit::read_gtfs(region$gtfs_url)
  # assign(sprintf("gtfs_%s_%s", region$name, region$gtfs_day), gtfs)
  gtfs_file_location <- sprintf("%s/gtfs_%s_%s.zip", output_region, region$name, gtfs_day_str)
  if (!file.exists(gtfs_file_location)) {
    tidytransit::write_gtfs(gtfs, gtfs_file_location)
  }

  gtfs_shapes <- tidytransit::shapes_as_sf(gtfs$shapes)
  bbox <- sf::st_bbox(gtfs_shapes)

  gtfs <- tidytransit::filter_feed_by_date(gtfs, extract_date = region$gtfs_day)
  gtfs_file <- sprintf("%s/gtfs_%s_%s.zip", output_region, region$name, gtfs_day_str)
  tidytransit::write_gtfs(gtfs, gtfs_file)

  if (!is.null(region$gtfs_manipulate) && !is.na(region$gtfs_manipulate)) {
    message("Manipulating GTFS with function: ", region$gtfs_manipulate)
    message("Manipulating gtfs...")
    gtfs <- get(region$gtfs_manipulate)(gtfs)
    gtfs_file_manipulated <- sprintf("%s/gtfs_%s_%s_manipulated.zip", output_region, region$name, gtfs_day_str)
    if (!file.exists(gtfs_file_manipulated)) {
      tidytransit::write_gtfs(gtfs, gtfs_file_manipulated)
    }
    message("GTFS manipulation completed.")
  }

  # Build OSM query
  q <- opq(bbox = bbox, timeout = 300) # Timeout to 5 minutes
  for (feat in region$query[[1]]) {
    q <- add_osm_feature(
      q,
      key = feat$key,
      value = feat$value,
      key_exact = if (!is.null(feat$key_exact)) feat$key_exact else FALSE
    )
  }
  # assign(sprintf("q_%s_gtfs%s", region$name, region$gtfs_day), q)

  # Get OSM extract to avoid API call
  # osmextract::oe_download_directory()
  if (is.null(region$geofabrik_region)) {
    stop("Please define the geofabrik_region for this region in prioritise_parameters.R")
  }
  osm_file <- osmextract::oe_download(
    sprintf("https://download.geofabrik.de/%s-latest.osm.pbf", region$geofabrik_region),
    file_basename = sprintf("%s_%s.osm.pbf", str_replace_all(region$geofabrik_region, "/", "_"), format(Sys.Date(), "%Y%m%d"))
  )

  # 2. Prioritise based on planned operation and infrastructure characteristics
  prioritisation <- GTFShift::prioritise_lanes(gtfs, q, date = region$gtfs_day, keep_osm_attributes = TRUE, osm_file = osm_file)
  # assign(sprintf("prioritisation_%s_gtfs%s", region$name, region$gtfs_day), prioritisation)

  prioritisation <- prioritisation |>
    select(way_osm_id, hour, frequency, is_bus_lane, n_lanes_parking, n_lanes_circulation, n_directions, n_lanes_circulation_direction, routes, shapes, name, geometry)

  prioritisation_area_polygon <- prioritisation |>
    st_union() |>
    st_convex_hull()

  st_write(
    prioritisation_area_polygon,
    sprintf("%s/prioritisation_area_polygon_%s_gtfs%s_run%s.gpkg", output_region, region$name, gtfs_day_str, run_day)
  )
  st_write(
    prioritisation_area_polygon,
    sprintf("%s/prioritisation_area_polygon_%s_gtfs%s_run%s.geojson", output_region, region$name, gtfs_day_str, run_day)
  )

  # 3. Extend with real-time data if available
  has_rt_collection <- !is.null(region$rt_collection) &&
    length(region$rt_collection) > 0 &&
    !is.null(region$rt_collection[[1]]) &&
    length(region$rt_collection[[1]]) > 0 &&
    !all(is.na(region$rt_collection[[1]]))

  route_speed_profiles <- NULL
  route_speed_profiles_nested <- NULL
  shape_speed_profiles_nested <- NULL

  if (has_rt_collection) {
    message("Extending with real-time data...")
    rt_files <- as.character(region$rt_collection[[1]])


    rt_collection_raw <- dplyr::bind_rows(lapply(rt_files, read.csv))
    message(sprintf("Loaded %d real-time updates from %d files", nrow(rt_collection_raw), length(rt_files)))
    if (!is.null(region$rt_collection_manipulate) && !is.na(region$rt_collection_manipulate)) {
      message("Manipulating RT collection with function: ", region$rt_collection_manipulate)
      rt_collection_manipulate <- get(region$rt_collection_manipulate)
      extra_params <- if (!is.null(region$rt_collection_manipulate_extra_params) && length(region$rt_collection_manipulate_extra_params) > 0) {
        region$rt_collection_manipulate_extra_params[[1]]
      } else {
        list()
      }

      rt_collection_filtered <- do.call(rt_collection_manipulate, c(list(rt_collection_raw), extra_params))
      message(sprintf("Filtered to %d real-time updates after manipulation", nrow(rt_collection_filtered)))
    } else {
      rt_collection_filtered <- rt_collection_raw
    }

    # Extend prioritisation with real-time data
    prioritisation_speeds <- rt_extend_prioritisation(
      lane_prioritisation = prioritisation |> select(way_osm_id) |> distinct(),
      rt_collection = rt_collection_filtered,
      metric_crs = region$metric_crs
    ) |>
      filter(speed_count >= THRESHOLD_MIN_UPDATES_PER_ROAD_SEGMENT_FOR_SPEED) |>
      mutate(
        # Round all columns that start with speed_ to 2 decimals
        across(starts_with("speed_"), ~ round(., 2))
      ) |>
      st_drop_geometry()
    prioritisation <- prioritisation |>
      left_join(prioritisation_speeds, by = "way_osm_id")

    # Trip-level speed profile analysis and disturbance index
    route_speed_profiles <- NULL
    tryCatch(
      {
        message("Computing trip-level speed profiles and disturbance index...")
        # Drop geometry and ungroup for profile computation
        rt_for_profile <- rt_collection_filtered
        if (inherits(rt_for_profile, "sf")) {
          rt_for_profile <- sf::st_drop_geometry(rt_for_profile)
        }
        rt_for_profile <- dplyr::ungroup(rt_for_profile)

        # Ensure trip_id and route_id are character
        if ("trip_id" %in% colnames(rt_for_profile)) rt_for_profile$trip_id <- as.character(rt_for_profile$trip_id)
        if ("route_id" %in% colnames(rt_for_profile)) rt_for_profile$route_id <- as.character(rt_for_profile$route_id)

        # Compute trip-level speed profile by (trip_id, route_id, day)
        trip_profiles <- GTFShift::get_trip_speed_profile(
          rt_speed = rt_for_profile,
          by = c("trip_id", "route_id", "day")
        )

        # Extract hour from timestamp_min in Europe/Lisbon timezone and link shape_id from gtfs$trips
        trip_profiles <- trip_profiles |>
          mutate(
            hour = if (all(is.na(timestamp_min))) {
              NA_integer_
            } else if (is.numeric(timestamp_min)) {
              as.integer(format(as.POSIXct(timestamp_min, origin = "1970-01-01", tz = "Europe/Lisbon"), "%H"))
            } else {
              as.integer(format(as.POSIXct(timestamp_min, tz = "Europe/Lisbon"), "%H"))
            }
          )
        if ("shape_id" %in% colnames(gtfs$trips)) {
          trip_shapes <- gtfs$trips |>
            select(trip_id, shape_id) |>
            filter(!is.na(shape_id) & shape_id != "") |>
            distinct(trip_id, .keep_all = TRUE)
          trip_shapes$trip_id <- as.character(trip_shapes$trip_id)
          trip_shapes$shape_id <- as.character(trip_shapes$shape_id)
          trip_profiles <- trip_profiles |>
            left_join(trip_shapes, by = "trip_id")
        } else {
          trip_profiles$shape_id <- NA_character_
        }

        # 1. Global stats per route_id (across all trips of any time)
        route_global_stats <- trip_profiles |>
          group_by(route_id) |>
          summarise(
            n_days = n_distinct(day),
            n_trips = n(),
            commercial_speed_avg = round(mean(commercial_speed, na.rm = TRUE), 2),
            commercial_speed_median = round(median(commercial_speed, na.rm = TRUE), 2),
            commercial_speed_alt = round(mean(commercial_speed_alt, na.rm = TRUE), 2),
            commercial_speed_p15 = round(as.numeric(quantile(commercial_speed, probs = 0.15, na.rm = TRUE, names = FALSE)), 2),
            commercial_speed_p25 = round(as.numeric(quantile(commercial_speed, probs = 0.25, na.rm = TRUE, names = FALSE)), 2),
            commercial_speed_p75 = round(as.numeric(quantile(commercial_speed, probs = 0.75, na.rm = TRUE, names = FALSE)), 2),
            commercial_speed_p85 = round(as.numeric(quantile(commercial_speed, probs = 0.85, na.rm = TRUE, names = FALSE)), 2),
            commercial_speed_min = round(min(commercial_speed, na.rm = TRUE), 2),
            commercial_speed_max = round(max(commercial_speed, na.rm = TRUE), 2),
            .groups = "drop"
          )

        # 2. Aggregations by (route_id, hour)
        route_hour_stats <- trip_profiles |>
          filter(!is.na(hour)) |>
          group_by(route_id, hour) |>
          summarise(
            n_days = n_distinct(day),
            n_trips = n(),
            commercial_speed_avg = round(mean(commercial_speed, na.rm = TRUE), 2),
            commercial_speed_median = round(median(commercial_speed, na.rm = TRUE), 2),
            commercial_speed_alt = round(mean(commercial_speed_alt, na.rm = TRUE), 2),
            commercial_speed_p15 = round(as.numeric(quantile(commercial_speed, probs = 0.15, na.rm = TRUE, names = FALSE)), 2),
            commercial_speed_p25 = round(as.numeric(quantile(commercial_speed, probs = 0.25, na.rm = TRUE, names = FALSE)), 2),
            commercial_speed_p75 = round(as.numeric(quantile(commercial_speed, probs = 0.75, na.rm = TRUE, names = FALSE)), 2),
            commercial_speed_p85 = round(as.numeric(quantile(commercial_speed, probs = 0.85, na.rm = TRUE, names = FALSE)), 2),
            commercial_speed_min = round(min(commercial_speed, na.rm = TRUE), 2),
            commercial_speed_max = round(max(commercial_speed, na.rm = TRUE), 2),
            .groups = "drop"
          ) |>
          left_join(route_global_stats |> select(route_id, route_speed_p85 = commercial_speed_p85), by = "route_id") |>
          mutate(
            # Disturbance index: (commercial_speed_avg - route_speed_p85) / route_speed_p85
            disturbance_index = ifelse(
              !is.na(route_speed_p85) & route_speed_p85 > 0,
              round((commercial_speed_avg - route_speed_p85) / route_speed_p85, 4),
              NA_real_
            )
          ) |>
          select(-route_speed_p85)

        # 3. Aggregations by trip_id across days
        trip_global_stats <- trip_profiles |>
          filter(!is.na(trip_id)) |>
          group_by(trip_id, route_id) |>
          summarise(
            n_days = n(),
            commercial_speed_avg = round(mean(commercial_speed, na.rm = TRUE), 2),
            commercial_speed_median = round(median(commercial_speed, na.rm = TRUE), 2),
            commercial_speed_alt = round(mean(commercial_speed_alt, na.rm = TRUE), 2),
            commercial_speed_p15 = round(as.numeric(quantile(commercial_speed, probs = 0.15, na.rm = TRUE, names = FALSE)), 2),
            commercial_speed_p25 = round(as.numeric(quantile(commercial_speed, probs = 0.25, na.rm = TRUE, names = FALSE)), 2),
            commercial_speed_p75 = round(as.numeric(quantile(commercial_speed, probs = 0.75, na.rm = TRUE, names = FALSE)), 2),
            commercial_speed_p85 = round(as.numeric(quantile(commercial_speed, probs = 0.85, na.rm = TRUE, names = FALSE)), 2),
            commercial_speed_min = round(min(commercial_speed, na.rm = TRUE), 2),
            commercial_speed_max = round(max(commercial_speed, na.rm = TRUE), 2),
            .groups = "drop"
          ) |>
          left_join(route_global_stats |> select(route_id, route_speed_p85 = commercial_speed_p85), by = "route_id") |>
          mutate(
            # Disturbance index for trip: (commercial_speed_avg - route_speed_p85) / route_speed_p85
            disturbance_index = ifelse(
              !is.na(route_speed_p85) & route_speed_p85 > 0,
              round((commercial_speed_avg - route_speed_p85) / route_speed_p85, 4),
              NA_real_
            )
          ) |>
          select(-route_speed_p85)

        # 4. Individual trip stats by (trip_id, day)
        trip_day_stats <- trip_profiles |>
          filter(!is.na(trip_id)) |>
          left_join(route_global_stats |> select(route_id, route_speed_p85 = commercial_speed_p85), by = "route_id") |>
          mutate(
            # Disturbance index for individual trip run: (commercial_speed - route_speed_p85) / route_speed_p85
            disturbance_index = ifelse(
              !is.na(route_speed_p85) & route_speed_p85 > 0,
              round((commercial_speed - route_speed_p85) / route_speed_p85, 4),
              NA_real_
            )
          ) |>
          select(-route_speed_p85)

        route_speed_profiles <- list(
          by_route = route_global_stats,
          by_route_hour = route_hour_stats,
          by_trip = trip_global_stats,
          by_trip_day = trip_day_stats
        )

        # Build nested dictionary keyed by route_id for JSON storage
        all_rids <- unique(c(route_global_stats$route_id, route_hour_stats$route_id, trip_global_stats$route_id, trip_day_stats$route_id))
        route_speed_profiles_nested <- setNames(lapply(all_rids, function(rid) {
          g_row <- route_global_stats |> filter(route_id == rid)
          h_rows <- route_hour_stats |> filter(route_id == rid)
          t_rows <- trip_global_stats |> filter(route_id == rid)
          td_rows <- trip_day_stats |> filter(route_id == rid)

          stats_obj <- if (nrow(g_row) > 0) {
            as.list(g_row[1, setdiff(names(g_row), "route_id")])
          } else {
            list()
          }

          # Convert hour rows into a list of records
          hour_list <- if (nrow(h_rows) > 0) {
            lapply(seq_len(nrow(h_rows)), function(row_idx) {
              as.list(h_rows[row_idx, setdiff(names(h_rows), "route_id")])
            })
          } else {
            list()
          }

          # Convert trip rows into a list of records
          trip_list <- if (nrow(t_rows) > 0) {
            lapply(seq_len(nrow(t_rows)), function(row_idx) {
              as.list(t_rows[row_idx, setdiff(names(t_rows), "route_id")])
            })
          } else {
            list()
          }

          # Convert individual (trip_id, day) rows into a list of records
          trip_day_list <- if (nrow(td_rows) > 0) {
            lapply(seq_len(nrow(td_rows)), function(row_idx) {
              as.list(td_rows[row_idx, setdiff(names(td_rows), "route_id")])
            })
          } else {
            list()
          }

          c(stats = list(stats_obj), hours = list(hour_list), trips = list(trip_list), trip_days = list(trip_day_list))
        }), all_rids)

        # 5. Global stats per shape_id (across all trips of any time)
        shape_global_stats <- trip_profiles |>
          filter(!is.na(shape_id) & shape_id != "") |>
          group_by(shape_id) |>
          summarise(
            n_days = n_distinct(day),
            n_trips = n(),
            commercial_speed_avg = round(mean(commercial_speed, na.rm = TRUE), 2),
            commercial_speed_median = round(median(commercial_speed, na.rm = TRUE), 2),
            commercial_speed_alt = round(mean(commercial_speed_alt, na.rm = TRUE), 2),
            commercial_speed_p15 = round(as.numeric(quantile(commercial_speed, probs = 0.15, na.rm = TRUE, names = FALSE)), 2),
            commercial_speed_p25 = round(as.numeric(quantile(commercial_speed, probs = 0.25, na.rm = TRUE, names = FALSE)), 2),
            commercial_speed_p75 = round(as.numeric(quantile(commercial_speed, probs = 0.75, na.rm = TRUE, names = FALSE)), 2),
            commercial_speed_p85 = round(as.numeric(quantile(commercial_speed, probs = 0.85, na.rm = TRUE, names = FALSE)), 2),
            commercial_speed_min = round(min(commercial_speed, na.rm = TRUE), 2),
            commercial_speed_max = round(max(commercial_speed, na.rm = TRUE), 2),
            .groups = "drop"
          )

        # 6. Aggregations by (shape_id, hour)
        shape_hour_stats <- trip_profiles |>
          filter(!is.na(shape_id) & shape_id != "" & !is.na(hour)) |>
          group_by(shape_id, hour) |>
          summarise(
            n_days = n_distinct(day),
            n_trips = n(),
            commercial_speed_avg = round(mean(commercial_speed, na.rm = TRUE), 2),
            commercial_speed_median = round(median(commercial_speed, na.rm = TRUE), 2),
            commercial_speed_alt = round(mean(commercial_speed_alt, na.rm = TRUE), 2),
            commercial_speed_p15 = round(as.numeric(quantile(commercial_speed, probs = 0.15, na.rm = TRUE, names = FALSE)), 2),
            commercial_speed_p25 = round(as.numeric(quantile(commercial_speed, probs = 0.25, na.rm = TRUE, names = FALSE)), 2),
            commercial_speed_p75 = round(as.numeric(quantile(commercial_speed, probs = 0.75, na.rm = TRUE, names = FALSE)), 2),
            commercial_speed_p85 = round(as.numeric(quantile(commercial_speed, probs = 0.85, na.rm = TRUE, names = FALSE)), 2),
            commercial_speed_min = round(min(commercial_speed, na.rm = TRUE), 2),
            commercial_speed_max = round(max(commercial_speed, na.rm = TRUE), 2),
            .groups = "drop"
          ) |>
          left_join(shape_global_stats |> select(shape_id, shape_speed_p85 = commercial_speed_p85), by = "shape_id") |>
          mutate(
            # Disturbance index: (commercial_speed_avg - shape_speed_p85) / shape_speed_p85
            disturbance_index = ifelse(
              !is.na(shape_speed_p85) & shape_speed_p85 > 0,
              round((commercial_speed_avg - shape_speed_p85) / shape_speed_p85, 4),
              NA_real_
            )
          ) |>
          select(-shape_speed_p85)

        # 7. Aggregations by (shape_id, trip_id) across days
        shape_trip_global_stats <- trip_profiles |>
          filter(!is.na(shape_id) & shape_id != "" & !is.na(trip_id)) |>
          group_by(shape_id, trip_id, route_id) |>
          summarise(
            n_days = n(),
            commercial_speed_avg = round(mean(commercial_speed, na.rm = TRUE), 2),
            commercial_speed_median = round(median(commercial_speed, na.rm = TRUE), 2),
            commercial_speed_alt = round(mean(commercial_speed_alt, na.rm = TRUE), 2),
            commercial_speed_p15 = round(as.numeric(quantile(commercial_speed, probs = 0.15, na.rm = TRUE, names = FALSE)), 2),
            commercial_speed_p25 = round(as.numeric(quantile(commercial_speed, probs = 0.25, na.rm = TRUE, names = FALSE)), 2),
            commercial_speed_p75 = round(as.numeric(quantile(commercial_speed, probs = 0.75, na.rm = TRUE, names = FALSE)), 2),
            commercial_speed_p85 = round(as.numeric(quantile(commercial_speed, probs = 0.85, na.rm = TRUE, names = FALSE)), 2),
            commercial_speed_min = round(min(commercial_speed, na.rm = TRUE), 2),
            commercial_speed_max = round(max(commercial_speed, na.rm = TRUE), 2),
            .groups = "drop"
          ) |>
          left_join(shape_global_stats |> select(shape_id, shape_speed_p85 = commercial_speed_p85), by = "shape_id") |>
          mutate(
            # Disturbance index for trip: (commercial_speed_avg - shape_speed_p85) / shape_speed_p85
            disturbance_index = ifelse(
              !is.na(shape_speed_p85) & shape_speed_p85 > 0,
              round((commercial_speed_avg - shape_speed_p85) / shape_speed_p85, 4),
              NA_real_
            )
          ) |>
          select(-shape_speed_p85)

        # 8. Individual trip stats by (shape_id, trip_id, day)
        shape_trip_day_stats <- trip_profiles |>
          filter(!is.na(shape_id) & shape_id != "" & !is.na(trip_id)) |>
          left_join(shape_global_stats |> select(shape_id, shape_speed_p85 = commercial_speed_p85), by = "shape_id") |>
          mutate(
            # Disturbance index for individual trip run: (commercial_speed - shape_speed_p85) / shape_speed_p85
            disturbance_index = ifelse(
              !is.na(shape_speed_p85) & shape_speed_p85 > 0,
              round((commercial_speed - shape_speed_p85) / shape_speed_p85, 4),
              NA_real_
            )
          ) |>
          select(-shape_speed_p85)

        # Build nested dictionary keyed by shape_id for JSON storage
        all_sids <- unique(c(shape_global_stats$shape_id, shape_hour_stats$shape_id, shape_trip_global_stats$shape_id, shape_trip_day_stats$shape_id))
        shape_speed_profiles_nested <- setNames(lapply(all_sids, function(sid) {
          g_row <- shape_global_stats |> filter(shape_id == sid)
          h_rows <- shape_hour_stats |> filter(shape_id == sid)
          t_rows <- shape_trip_global_stats |> filter(shape_id == sid)
          td_rows <- shape_trip_day_stats |> filter(shape_id == sid)

          stats_obj <- if (nrow(g_row) > 0) {
            as.list(g_row[1, setdiff(names(g_row), "shape_id")])
          } else {
            list()
          }

          # Convert hour rows into a list of records
          hour_list <- if (nrow(h_rows) > 0) {
            lapply(seq_len(nrow(h_rows)), function(row_idx) {
              as.list(h_rows[row_idx, setdiff(names(h_rows), "shape_id")])
            })
          } else {
            list()
          }

          # Convert trip rows into a list of records
          trip_list <- if (nrow(t_rows) > 0) {
            lapply(seq_len(nrow(t_rows)), function(row_idx) {
              as.list(t_rows[row_idx, setdiff(names(t_rows), "shape_id")])
            })
          } else {
            list()
          }

          # Convert individual (trip_id, day) rows into a list of records
          trip_day_list <- if (nrow(td_rows) > 0) {
            lapply(seq_len(nrow(td_rows)), function(row_idx) {
              as.list(td_rows[row_idx, setdiff(names(td_rows), "shape_id")])
            })
          } else {
            list()
          }

          c(stats = list(stats_obj), hours = list(hour_list), trips = list(trip_list), trip_days = list(trip_day_list))
        }), all_sids)

        message("Trip speed profile and disturbance index computation completed.")
      },
      error = function(e) {
        warning("Could not compute trip speed profiles: ", e$message)
      }
    )

    # RT analysis per hour
    if (isTRUE(region$rt_collection_per_hour) && "hh" %in% colnames(rt_collection_filtered)) {
      message("Extending prioritisation with real-time data per hour...")
      hours <- unique(rt_collection_filtered$hh)
      prioritisation_hour_aggregated <- data.frame()
      for (h in hours) {
        rt_collection_hour <- rt_collection_filtered |> filter(hh == h)
        prioritisation_hour <- prioritisation |>
          filter(hour == h) |>
          select(way_osm_id, hour) # No need for distinct(), as it already has one row per way_osm_id and hour
        if (nrow(rt_collection_hour) > 0 && nrow(prioritisation_hour) > 0) {
          prioritisation_hour_extended <- rt_extend_prioritisation(
            lane_prioritisation = prioritisation_hour,
            rt_collection = rt_collection_hour,
            metric_crs = region$metric_crs
          ) |>
            filter(speed_count >= THRESHOLD_MIN_UPDATES_PER_ROAD_SEGMENT_FOR_SPEED) |>
            mutate(
              # Round all columns that start with speed_ to 2 decimals
              across(starts_with("speed_"), ~ round(., 2))
            ) |>
            # Prepend all columns that start with speed_ with hour_
            rename_with(.cols = starts_with("speed_"), .fn = ~ paste0("hour_", .)) |>
            st_drop_geometry()
          # Update prioritisation_hour with extended data for this hour
          prioritisation_hour_aggregated <- bind_rows(prioritisation_hour_aggregated, prioritisation_hour_extended)
        }
      }
      # Left join prioritisation with prioritisation_hour_aggregated by way_osm_id and hour
      prioritisation <- prioritisation |>
        left_join(prioritisation_hour_aggregated, by = c("way_osm_id", "hour")) |>
        mutate(
          # Compute segment disturbance index using speed_p85 baseline and hour_speed_median
          disturbance_index = ifelse(
            !is.na(speed_p85) & speed_p85 > 0 & !is.na(hour_speed_median),
            round((hour_speed_median - speed_p85) / speed_p85, 4),
            NA_real_
          )
        )
    }
  }

  # 3.2. Extend with route demand data if available
  route_demand <- data.frame(route_id = character(), route_short_name = character(), demand = numeric())
  has_demand <- !is.null(region$demand_for_route) &&
    length(region$demand_for_route) > 0 &&
    !is.null(region$demand_for_route[[1]]) &&
    length(region$demand_for_route[[1]]) > 0 &&
    !all(is.na(region$demand_for_route[[1]]))
  if (has_demand) {
    message("Extending with route demand data...")
    route_demand_files <- as.character(region$demand_for_route[[1]])
    route_demand <- read.csv(route_demand_files) |>
      mutate(route_short_name = as.character(route_short_name)) |>
      right_join(gtfs$routes |> select(route_id, route_short_name), by = "route_short_name") |>
      filter(!is.na(demand))

    # For each prioritisation row, sum route_demand$demand for all routes with route_id in prioritisation$routes list
    priotitization_demand <- prioritisation |>
      st_drop_geometry() |>
      select(way_osm_id, hour, routes) |>
      # Split routes list column in rows
      tidyr::unnest(routes) |>
      # Get demand
      left_join(route_demand |> select(route_id, demand), by = c("routes" = "route_id")) |>
      # Group back by way_osm_id and hour, summing demand
      group_by(way_osm_id, hour) |>
      summarise(demand = sum(demand, na.rm = TRUE), .groups = "drop")

    prioritisation <- prioritisation |>
      left_join(priotitization_demand, by = c("way_osm_id", "hour"))
  }
  write.csv(
    prioritisation |>
      sf::st_drop_geometry() |>
      mutate(
        # Convert vector of strings to single string with ";" separator
        routes = sapply(routes, function(x) paste(x, collapse = ";"), USE.NAMES = FALSE),
        shapes = sapply(shapes, function(x) paste(x, collapse = ";"), USE.NAMES = FALSE)
      ),
    sprintf("%s/prioritisation_%s_gtfs%s_run%s.csv", output_region, region$name, gtfs_day_str, run_day),
    row.names = FALSE
  )
  st_write(prioritisation |> mutate(
    routes = sapply(routes, function(x) paste(x, collapse = ";"), USE.NAMES = FALSE),
    shapes = sapply(shapes, function(x) paste(x, collapse = ";"), USE.NAMES = FALSE)
  ), sprintf("%s/prioritisation_%s_gtfs%s_run%s.gpkg", output_region, region$name, gtfs_day_str, run_day), append = FALSE)

  # 4. Build data for dashboard
  # > 4.1. Store ways geometries
  ways <- prioritisation |>
    distinct(way_osm_id, geometry)
  st_write(ways, sprintf("%s/ways_%s_gtfs%s_run%s.gpkg", output_region, region$name, gtfs_day_str, run_day), append = FALSE)
  st_write(ways, sprintf("%s/ways_%s_gtfs%s_run%s.geojson", output_region, region$name, gtfs_day_str, run_day), append = FALSE)

  ways_length <- ways |> # Convert to metric_crs
    st_transform(crs = region$metric_crs) |>
    # Calculate lenght in meters
    mutate(length_m = st_length(geometry)) |>
    # Drop units
    mutate(length_m = round(as.numeric(length_m), digits = 2))

  # > 4.2. Store prioritisation as json, grouping by way_osm_id, each grouped by hour
  nested_data <- lapply(split(
    prioritisation |>
      st_drop_geometry() |>
      left_join(ways_length |> select(way_osm_id, length_m) |> st_drop_geometry()),
    prioritisation$way_osm_id
  ), function(df) {
    # 1. Extract first row and convert to list
    static_df <- df[1, ] %>% select(-way_osm_id, -hour, -frequency, -starts_with("hour_"))
    # As demand is daily, get max demand for the way_osm_id across all hours (when most routes go through it)
    static_df$demand <- if ("demand" %in% colnames(df)) max(df$demand, na.rm = TRUE) else NA
    static_info <- as.list(static_df)

    # 2. Extract values from list-columns and wrap routes/shapes in I()
    # This ensures they remain arrays even with length 1
    for (col in names(static_info)) {
      if (col == "routes") {
        static_info[[col]] <- unique(unlist(df$routes))
      } else if (col == "shapes") {
        static_info[[col]] <- unique(unlist(df$shapes))
      } else if (is.list(static_info[[col]])) {
        # If it's a list-column (common in sf/dplyr), grab the vector inside
        static_info[[col]] <- static_info[[col]][[1]]
      }

      # Protect specific columns from unboxing
      if (col %in% c("routes", "shapes")) {
        static_info[[col]] <- I(as.character(na.omit(static_info[[col]])))
      }
    }

    # 3. Hourly frequencies (auto_unbox will handle these as single numbers)
    hourly_freqs <- setNames(as.list(df$frequency), df$hour)

    # 4. Hourly speeds (auto_unbox will handle these as single numbers)
    if ("hour_speed_avg" %in% colnames(df)) {
      # For avg, median, p25, p75, p85 (if available) and count
      hourly_speeds_avg <- setNames(as.list(df$hour_speed_avg), df$hour)
      hourly_speeds_median <- setNames(as.list(df$hour_speed_median), df$hour)
      hourly_speeds_p25 <- setNames(as.list(df$hour_speed_p25), df$hour)
      hourly_speeds_p75 <- setNames(as.list(df$hour_speed_p75), df$hour)
      hourly_speeds_count <- setNames(as.list(df$hour_speed_count), df$hour)

      hourly_list <- list(
        hour_frequency = hourly_freqs,
        hour_speed_avg = hourly_speeds_avg,
        hour_speed_median = hourly_speeds_median,
        hour_speed_p25 = hourly_speeds_p25,
        hour_speed_p75 = hourly_speeds_p75,
        hour_speed_count = hourly_speeds_count
      )

      if ("hour_speed_p85" %in% colnames(df)) {
        hourly_list$hour_speed_p85 <- setNames(as.list(df$hour_speed_p85), df$hour)
      }

      if ("disturbance_index" %in% colnames(df)) {
        hourly_list$hour_disturbance_index <- setNames(as.list(df$disturbance_index), df$hour)
      }

      return(c(static_info, hourly_list))
    }

    # Combine
    return(c(static_info, list(hour_frequency = hourly_freqs)))
  })
  json_string <- toJSON(
    nested_data,
    na = "null", # To avoid NAs being converted to strings in JSON
    auto_unbox = TRUE,
    pretty = TRUE
  )
  write(
    json_string,
    sprintf("%s/way_data_%s_gtfs%s_run%s.json", output_region, region$name, gtfs_day_str, run_day)
  )

  # > 4.3. Store route data
  routes <- GTFShift::get_route_frequency_hourly(gtfs, date = region$gtfs_day) |>
    st_drop_geometry() |>
    select(-route_short_name) |>
    left_join(gtfs$routes |> select(route_id, route_short_name, route_long_name), by = "route_id") |>
    left_join(gtfs$routes |> select(route_id, route_color, route_text_color), by = "route_id")
  # If route_color does not start with "#", add suffix
  routes <- routes |> mutate(
    route_color = ifelse(!str_starts(route_color, "#"), paste0("#", route_color), route_color),
    route_text_color = ifelse(!str_starts(route_text_color, "#"), paste0("#", route_text_color), route_text_color)
  )

  # Precompute departure and arrival stop coordinates for each shape
  shape_terminal_stops <- tryCatch(
    {
      # Find the first and last stop_sequence for each trip
      trip_terminals <- gtfs$stop_times |>
        group_by(trip_id) |>
        summarise(
          dep_seq = min(stop_sequence, na.rm = TRUE),
          arr_seq = max(stop_sequence, na.rm = TRUE),
          dep_stop_id = stop_id[which.min(stop_sequence)],
          arr_stop_id = stop_id[which.max(stop_sequence)],
          .groups = "drop"
        )

      # Link trips to shapes and deduplicate per shape_id
      shapes_terminals_raw <- gtfs$trips |>
        select(shape_id, trip_id) |>
        filter(!is.na(shape_id) & shape_id != "") |>
        inner_join(trip_terminals, by = "trip_id") |>
        distinct(shape_id, .keep_all = TRUE)

      # Prepare stops dataframe with coords and name
      stops_info <- gtfs$stops |>
        select(stop_id, any_of(c("stop_name")), stop_lat, stop_lon)

      # Join terminal stops with their coordinates
      shapes_terminals_raw |>
        left_join(stops_info |> rename(departure_stop_id = stop_id, departure_stop_name = any_of("stop_name"), departure_stop_lat = stop_lat, departure_stop_lon = stop_lon), by = c("dep_stop_id" = "departure_stop_id")) |>
        left_join(stops_info |> rename(arrival_stop_id = stop_id, arrival_stop_name = any_of("stop_name"), arrival_stop_lat = stop_lat, arrival_stop_lon = stop_lon), by = c("arr_stop_id" = "arrival_stop_id"))
    },
    error = function(e) {
      warning("Could not compute shape terminal stops: ", e$message)
      NULL
    }
  )

  nested_shapes <- lapply(split(routes, routes$shape_id), function(df) {
    # Extract static metadata associated with this shape
    shape_metadata <- df[1, ] %>%
      select(route_id, shape_id, route_short_name, route_long_name, direction_id, route_color, route_text_color) %>%
      as.list()

    # Add departure and arrival stop details
    if (!is.null(shape_terminal_stops)) {
      terminals <- shape_terminal_stops |> filter(shape_id == shape_metadata$shape_id)
      if (nrow(terminals) > 0) {
        dep <- list(
          stop_id = terminals$dep_stop_id[1],
          lat = round(as.numeric(terminals$departure_stop_lat[1]), 6),
          lon = round(as.numeric(terminals$departure_stop_lon[1]), 6)
        )
        if ("departure_stop_name" %in% names(terminals) && !is.na(terminals$departure_stop_name[1])) {
          dep$stop_name <- terminals$departure_stop_name[1]
        }
        shape_metadata$departure_stop <- dep

        arr <- list(
          stop_id = terminals$arr_stop_id[1],
          lat = round(as.numeric(terminals$arrival_stop_lat[1]), 6),
          lon = round(as.numeric(terminals$arrival_stop_lon[1]), 6)
        )
        if ("arrival_stop_name" %in% names(terminals) && !is.na(terminals$arrival_stop_name[1])) {
          arr$stop_name <- terminals$arrival_stop_name[1]
        }
        shape_metadata$arrival_stop <- arr
      }
    }

    # Create the hourly frequency mapping (aggregating frequencies of all routes sharing this shape by hour)
    df_hourly <- df %>%
      dplyr::group_by(hour) %>%
      dplyr::summarise(frequency = sum(frequency, na.rm = TRUE), .groups = "drop")
    hourly_frequencies <- setNames(as.list(df_hourly$frequency), df_hourly$hour)

    # Get stats for shape
    prioritisation_shape <- prioritisation |>
      rowwise() |>
      filter(shape_metadata$shape_id %in% shapes) |>
      ungroup()
    # > If no stats, ignore shape
    if (nrow(prioritisation_shape) == 0) {
      return(NULL)
    }
    shape_metadata$stats <- GTFShift::get_prioritisation_stats(
      prioritisation_shape |> distinct(way_osm_id, .keep_all = TRUE),
      weight = "length",
      metric_crs = region$metric_crs
    )
    # Round all numeric values to 2 decimals
    shape_metadata$stats <- lapply(shape_metadata$stats, function(x) {
      if (is.numeric(x)) {
        round(x, 2)
      } else {
        x
      }
    })

    # Attach speed profile stats if available
    sid <- as.character(shape_metadata$shape_id)
    if (!is.null(shape_speed_profiles_nested) && sid %in% names(shape_speed_profiles_nested)) {
      shape_metadata$speed_profile <- shape_speed_profiles_nested[[sid]]
    }

    # Combine metadata with the hourly 'schedule'
    c(shape_metadata, list(schedule = hourly_frequencies))
  })
  nested_shapes <- nested_shapes[!sapply(nested_shapes, is.null)]
  nested_shapes_df <- bind_rows(lapply(nested_shapes, function(x) {
    # message(sprintf("Processing shape %s", x$shape_id))
    # Prepend prefixes to sub-list names before flattening
    names(x$stats) <- paste0("stats.", names(x$stats))
    names(x$schedule) <- paste0("schedule.", names(x$schedule))
    if (!is.null(x$departure_stop)) {
      names(x$departure_stop) <- paste0("departure_stop.", names(x$departure_stop))
    }
    if (!is.null(x$arrival_stop)) {
      names(x$arrival_stop) <- paste0("arrival_stop.", names(x$arrival_stop))
    }

    speed_profile_flat <- list()
    if (!is.null(x$speed_profile) && !is.null(x$speed_profile$stats)) {
      sp_stats <- x$speed_profile$stats
      names(sp_stats) <- paste0("speed_profile.", names(sp_stats))
      speed_profile_flat <- sp_stats
    }

    # Flatten everything into one list and convert to tibble
    as_tibble(c(
      x[!(names(x) %in% c("stats", "schedule", "departure_stop", "arrival_stop", "speed_profile"))],
      x$departure_stop,
      x$arrival_stop,
      x$stats,
      x$schedule,
      speed_profile_flat
    ))
  }))

  write_json(
    nested_shapes,
    sprintf("%s/shape_data_%s_gtfs%s_run%s.json", output_region, region$name, gtfs_day_str, run_day),
    auto_unbox = TRUE,
    digits = NA # To avoid precision loss in coordinates
  )
  write.csv(nested_shapes_df, sprintf("%s/shape_data_%s_gtfs%s_run%s.csv", output_region, region$name, gtfs_day_str, run_day))

  nested_routes <- lapply(split(
    gtfs$routes |>
      select(route_id, route_short_name, route_long_name, route_color, route_text_color) |>
      left_join(route_demand |> select(route_id, demand), by = "route_id"),
    gtfs$routes$route_id
  ), function(df) {
    route_metadata <- df[1, ] %>%
      as.list()

    # Attach speed profile stats if available
    rid <- as.character(df$route_id[1])
    if (!is.null(route_speed_profiles_nested) && rid %in% names(route_speed_profiles_nested)) {
      route_metadata$speed_profile <- route_speed_profiles_nested[[rid]]
    }

    c(route_metadata)
  })
  write_json(
    nested_routes,
    sprintf("%s/route_data_%s_gtfs%s_run%s.json", output_region, region$name, gtfs_day_str, run_day),
    auto_unbox = TRUE,
    digits = NA # To avoid precision loss in coordinates
  )


  # > 4.4. Store metadata about execution details
  prioritisation <- prioritisation |>
    left_join(ways_length |> select(way_osm_id, length_m) |> st_drop_geometry(), by = "way_osm_id")
  prioritisation_infrastructure <- prioritisation |>
    distinct(way_osm_id, .keep_all = TRUE)

  shapes_found <- unique(unlist(prioritisation$shapes))
  shapes_missing <- unique(gtfs$shapes$shape_id) %>% setdiff(shapes_found)
  shapes_found_frequency <- sum((routes |> filter(shape_id %in% shapes_found))$frequency)
  shapes_missing_frequency <- sum((routes |> filter(shape_id %in% shapes_missing))$frequency)

  routes_missing <- routes |>
    group_by(route_id) |>
    summarise(
      shapes = list(unique(shape_id)),
      n_shapes = length(unique(shape_id))
    ) |>
    mutate(
      n_shapes_missing = sapply(shapes, function(s_list) sum(s_list %in% shapes_missing))
    ) |>
    filter(n_shapes_missing > 0) |>
    select(-shapes)
  routes_missing_nested <- lapply(split(routes_missing, routes_missing$route_id), function(df) {
    df %>%
      select(n_shapes, n_shapes_missing) %>%
      as.list()
  })

  # For i in range 0, 23
  prioritisation_hour <- list()
  stop_times_fix <- gtfs$stop_times |>
    mutate(
      across(c(departure_time, arrival_time), ~ {
        sec <- lubridate::period_to_seconds(lubridate::hms(.x)) %% 86400
        hms::as_hms(sec)
      })
    )
  gtfs_hour_fix <- gtfs
  gtfs_hour_fix$stop_times <- stop_times_fix
  for (i in 0:23) {
    gtfs_hour <- NULL
    tryCatch(
      {
        gtfs_hour <- tidytransit::filter_feed_by_date(gtfs_hour_fix, extract_date = region$gtfs_day, min_departure_time = sprintf("%02d:00:00", i), max_arrival_time = sprintf("%02d:00:00", (i + 1)))
      },
      error = function(e) {
        message(sprintf("No GTFS data for hour %02d...", i))
      }
    )
    if (is.null(gtfs_hour)) {
      next
    }
    shapes_found_list <- unique(unlist(prioritisation$shapes))
    # Filter to make sure they are at gtfs_hour$shapes$shape_id
    shapes_found_list <- shapes_found_list[shapes_found_list %in% gtfs_hour$shapes$shape_id]
    shapes_missing_list <- setdiff(unique(gtfs_hour$shapes$shape_id), shapes_found_list)
    shapes_found_frequency_hour <- sum((routes |> filter(shape_id %in% shapes_found_list & hour == i))$frequency)
    shapes_missing_frequency_hour <- sum((routes |> filter(shape_id %in% shapes_missing_list & hour == i))$frequency)

    # Now for routes
    routes_found_list <- unique(unlist(prioritisation$routes))
    # Filter to make sure they are at gtfs_hour$routes$route_id
    routes_found_list <- routes_found_list[routes_found_list %in% gtfs_hour$routes$route_id]

    routes_missing_hour <- routes |>
      filter(route_id %in% gtfs_hour$routes$route_id) |>
      group_by(route_id) |>
      summarise(
        shapes = list(unique(shape_id)),
        n_shapes = length(unique(shape_id))
      ) |>
      mutate(
        n_shapes_missing = sapply(shapes, function(s_list) sum(s_list %in% shapes_missing_list))
      ) |>
      filter(n_shapes_missing > 0) |>
      select(-shapes)
    routes_missing_hour_nested <- lapply(split(routes_missing_hour, routes_missing_hour$route_id), function(df) {
      df %>%
        select(n_shapes, n_shapes_missing) %>%
        as.list()
    })

    prioritisation_hour[[as.character(i)]] <- list(
      shapes_missing = shapes_missing_list,
      routes_missing = routes_missing_hour_nested,
      shapes_total = length(unique(gtfs_hour$shapes$shape_id)),
      shapes_found_n = length(shapes_found_list),
      shapes_missing_n = length(shapes_missing_list),
      shapes_total_frequency = sum((routes |> filter(shape_id %in% gtfs_hour$shapes$shape_id & hour == i))$frequency),
      shapes_found_frequency = shapes_found_frequency_hour,
      shapes_missing_frequency = shapes_missing_frequency_hour,
      routes_total = length(unique(gtfs_hour$routes$route_id)),
      routes_missing_n = length(routes_missing_hour),
      routes_found_n = length(routes_found_list)
    )
  }

  dataCensus <- function(numberArray, weights) {
    quantiles <- wtd.quantile(numberArray, weights = weights, probs = c(0.05, 0.15, 0.25, 0.5, 0.75, 0.85, 0.95))
    return(list(
      min = round(min(numberArray, na.rm = TRUE), digits = 2),
      max = round(max(numberArray, na.rm = TRUE), digits = 2),
      p5 = round(as.numeric(quantiles[1]), digits = 2),
      p15 = round(as.numeric(quantiles[2]), digits = 2),
      p25 = round(as.numeric(quantiles[3]), digits = 2),
      p75 = round(as.numeric(quantiles[5]), digits = 2),
      p85 = round(as.numeric(quantiles[6]), digits = 2),
      p95 = round(as.numeric(quantiles[7]), digits = 2),
      mean = round(wtd.mean(numberArray, weights = weights, na.rm = TRUE), digits = 2),
      median = round(as.numeric(quantiles[4]), digits = 2),
      # Compute median for values below p85
      median_below_p95 = round(wtd.quantile(numberArray[numberArray <= quantiles[7]], weights = weights[numberArray <= quantiles[7]], probs = 0.5, na.rm = TRUE), digits = 2),
      median_below_p85 = round(wtd.quantile(numberArray[numberArray <= quantiles[6]], weights = weights[numberArray <= quantiles[6]], probs = 0.5, na.rm = TRUE), digits = 2),
      median_below_p75 = round(wtd.quantile(numberArray[numberArray <= quantiles[5]], weights = weights[numberArray <= quantiles[5]], probs = 0.5, na.rm = TRUE), digits = 2),
      variance = round(wtd.var(numberArray, weights = weights, na.rm = TRUE), digits = 2),
      sd = round(sqrt(wtd.var(numberArray, weights = weights, na.rm = TRUE)), digits = 2),
      count = length(numberArray)
    ))
  }

  rt_list <- NA
  if (has_rt_collection) {
    rt_list <- list(
      url = "", # To be edited manually
      period = region$rt_interval,
      notes = region$rt_notes,
      thresholds = list(
        min_updates_per_road_segment_for_speed = THRESHOLD_MIN_UPDATES_PER_ROAD_SEGMENT_FOR_SPEED,
        max_time_between_updates = THRESHOLD_TIME_BETWEEN_UPDATES_MAX,
        min_updates_per_trip_margin = THRESHOLD_UPDATES_PER_TRIP_MIN_MARGIN,
        max_distance_to_geometry = THRESHOLD_DISTANCE_TO_GEOMETRY_MAX,
        edge_distance_discard = THRESHOLD_EDGE_DISTANCE_DISCARD,
        max_speed = THRESHOLD_SPEED_MAX
      )
    )
  }
  demand_list <- NA
  if (has_demand) {
    demand_list <- list(
      notes = region$demand_notes
    )
  }
  census_frequency_hour <- list()
  census_speed_avg_hour_length <- list()
  census_speed_avg_hour_frequency <- list()
  census_speed_median_hour_length <- list()
  census_speed_median_hour_frequency <- list()
  census_speed_p85_hour_length <- list()
  census_speed_p85_hour_frequency <- list()
  census_disturbance_index_hour_length <- list()
  census_disturbance_index_hour_frequency <- list()

  for (h in 0:23) {
    prioritisation_h <- prioritisation |> filter(hour == h)
    census <- dataCensus(prioritisation_h$frequency, prioritisation_h$length_m)
    if (!is.na(census$mean)) {
      census_frequency_hour[[as.character(h)]] <- census
    }

    if ("hour_speed_avg" %in% colnames(prioritisation)) {
      prioritisation_h_savg <- prioritisation_h |> filter(!is.na(hour_speed_avg))
      if (nrow(prioritisation_h_savg) > 0) {
        c_len <- dataCensus(prioritisation_h_savg$hour_speed_avg, prioritisation_h_savg$length_m)
        c_freq <- dataCensus(prioritisation_h_savg$hour_speed_avg, prioritisation_h_savg$frequency)
        if (!is.na(c_len$mean)) census_speed_avg_hour_length[[as.character(h)]] <- c_len
        if (!is.na(c_freq$mean)) census_speed_avg_hour_frequency[[as.character(h)]] <- c_freq
      }
    }

    if ("hour_speed_median" %in% colnames(prioritisation)) {
      prioritisation_h_smed <- prioritisation_h |> filter(!is.na(hour_speed_median))
      if (nrow(prioritisation_h_smed) > 0) {
        c_len <- dataCensus(prioritisation_h_smed$hour_speed_median, prioritisation_h_smed$length_m)
        c_freq <- dataCensus(prioritisation_h_smed$hour_speed_median, prioritisation_h_smed$frequency)
        if (!is.na(c_len$mean)) census_speed_median_hour_length[[as.character(h)]] <- c_len
        if (!is.na(c_freq$mean)) census_speed_median_hour_frequency[[as.character(h)]] <- c_freq
      }
    }

    if ("hour_speed_p85" %in% colnames(prioritisation)) {
      prioritisation_h_sp85 <- prioritisation_h |> filter(!is.na(hour_speed_p85))
      if (nrow(prioritisation_h_sp85) > 0) {
        c_len <- dataCensus(prioritisation_h_sp85$hour_speed_p85, prioritisation_h_sp85$length_m)
        c_freq <- dataCensus(prioritisation_h_sp85$hour_speed_p85, prioritisation_h_sp85$frequency)
        if (!is.na(c_len$mean)) census_speed_p85_hour_length[[as.character(h)]] <- c_len
        if (!is.na(c_freq$mean)) census_speed_p85_hour_frequency[[as.character(h)]] <- c_freq
      }
    }

    if ("disturbance_index" %in% colnames(prioritisation)) {
      prioritisation_h_di <- prioritisation_h |> filter(!is.na(disturbance_index))
      if (nrow(prioritisation_h_di) > 0) {
        census_di_len <- dataCensus(prioritisation_h_di$disturbance_index, prioritisation_h_di$length_m)
        census_di_freq <- dataCensus(prioritisation_h_di$disturbance_index, prioritisation_h_di$frequency)
        if (!is.na(census_di_len$mean)) census_disturbance_index_hour_length[[as.character(h)]] <- census_di_len
        if (!is.na(census_di_freq$mean)) census_disturbance_index_hour_frequency[[as.character(h)]] <- census_di_freq
      }
    }
  }

  metadata <- list(
    region = region$name_long,
    gtfs = list(
      date = region$gtfs_day,
      url = region$gtfs_url
    ),
    osm_query = lapply(region$query[[1]], function(feat) {
      list(
        key = feat$key,
        value = feat$value,
        key_exact = if (!is.null(feat$key_exact)) feat$key_exact else FALSE
      )
    }),
    prioritisation = list(
      shapes_missing = shapes_missing,
      routes_missing = routes_missing_nested,
      shapes_total = length(unique(gtfs$shapes$shape_id)),
      shapes_found_n = length(shapes_found),
      shapes_missing_n = length(shapes_missing),
      shapes_total_frequency = sum(routes$frequency),
      shapes_found_frequency = shapes_found_frequency,
      shapes_missing_frequency = shapes_missing_frequency,
      routes_total = nrow(gtfs$routes),
      routes_missing_n = nrow(routes_missing),
      routes_found_n = nrow(routes) - nrow(routes_missing)
    ),
    prioritisation_hour = prioritisation_hour,
    data_census = list(
      frequency = dataCensus(prioritisation$frequency, prioritisation$length_m),
      frequency_hour = census_frequency_hour,
      speed_avg_length = NA,
      speed_avg_frequency = NA,
      speed_median_length = NA,
      speed_median_frequency = NA,
      speed_p85_length = NA,
      speed_p85_frequency = NA,
      demand_frequency = NA,
      demand_length = NA,
      lanes_length = dataCensus(prioritisation_infrastructure$n_lanes_circulation_direction, prioritisation_infrastructure$length_m),
      lanes_frequency = dataCensus(prioritisation_infrastructure$n_lanes_circulation_direction, prioritisation_infrastructure$frequency),
      prioritisation_stats_length = lapply(
        GTFShift::get_prioritisation_stats(prioritisation_infrastructure, weight = "length"),
        function(x) {
          if (is.numeric(x)) {
            round(x, 2)
          } else {
            x
          }
        }
      ),
      prioritisation_stats_frequency = lapply(
        GTFShift::get_prioritisation_stats(prioritisation_infrastructure, weight = "frequency"),
        function(x) {
          if (is.numeric(x)) {
            round(x, 2)
          } else {
            x
          }
        }
      )
    ),
    rt = rt_list,
    demand = demand_list,
    execution = list(
      moment = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
      script = "dev/web_version.R",
      git_commit = system("git rev-parse HEAD", intern = TRUE)
    ),
    environment = list(
      r = R.version.string,
      GTFShift = GTFShiftVersion,
      os = Sys.info()[["sysname"]],
      os_release = Sys.info()[["release"]]
    )
  )
  if ("speed_avg" %in% colnames(prioritisation_infrastructure)) {
    metadata$data_census$speed_avg_length <- dataCensus(prioritisation_infrastructure$speed_avg, prioritisation_infrastructure$length_m)
    metadata$data_census$speed_avg_frequency <- dataCensus(prioritisation_infrastructure$speed_avg, prioritisation_infrastructure$frequency)
    metadata$data_census$speed_avg_hour_length <- census_speed_avg_hour_length
    metadata$data_census$speed_avg_hour_frequency <- census_speed_avg_hour_frequency
  }
  if ("speed_median" %in% colnames(prioritisation_infrastructure)) {
    metadata$data_census$speed_median_length <- dataCensus(prioritisation_infrastructure$speed_median, prioritisation_infrastructure$length_m)
    metadata$data_census$speed_median_frequency <- dataCensus(prioritisation_infrastructure$speed_median, prioritisation_infrastructure$frequency)
    metadata$data_census$speed_median_hour_length <- census_speed_median_hour_length
    metadata$data_census$speed_median_hour_frequency <- census_speed_median_hour_frequency
  }
  if ("speed_p85" %in% colnames(prioritisation_infrastructure)) {
    metadata$data_census$speed_p85_length <- dataCensus(prioritisation_infrastructure$speed_p85, prioritisation_infrastructure$length_m)
    metadata$data_census$speed_p85_frequency <- dataCensus(prioritisation_infrastructure$speed_p85, prioritisation_infrastructure$frequency)
    metadata$data_census$speed_p85_hour_length <- census_speed_p85_hour_length
    metadata$data_census$speed_p85_hour_frequency <- census_speed_p85_hour_frequency
  }
  if ("disturbance_index" %in% colnames(prioritisation)) {
    valid_di <- prioritisation |> filter(!is.na(disturbance_index))
    if (nrow(valid_di) > 0) {
      metadata$data_census$disturbance_index_length <- dataCensus(valid_di$disturbance_index, valid_di$length_m)
      metadata$data_census$disturbance_index_frequency <- dataCensus(valid_di$disturbance_index, valid_di$frequency)
      metadata$data_census$disturbance_index_hour_length <- census_disturbance_index_hour_length
      metadata$data_census$disturbance_index_hour_frequency <- census_disturbance_index_hour_frequency
    }
  }
  if ("demand" %in% colnames(prioritisation_infrastructure)) {
    metadata$data_census$demand_frequency <- dataCensus(prioritisation_infrastructure$demand, prioritisation_infrastructure$frequency)
    metadata$data_census$demand_length <- dataCensus(prioritisation_infrastructure$demand, prioritisation_infrastructure$length_m)
  }
  write_json(
    metadata,
    sprintf("%s/metadata_%s_gtfs%s_run%s.json", output_region, region$name, gtfs_day_str, run_day),
    auto_unbox = TRUE,
    digits = NA
  )
}
