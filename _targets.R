# Created by use_targets().
# Follow the comments below to fill in this target script.
# Then follow the manual to check and run the pipeline:
#   https://books.ropensci.org/targets/walkthrough.html#inspect-the-pipeline

# Load packages required to define the pipeline:
library(targets)
library(tarchetypes)
library(geotargets)
library(crew)
library(qs2) #for format = "qs"

# currently this is running on a Jetstream 2 instance with 8 cores and 30GB of
# RAM with 5 parallel workers—you may need to adjust the number of workers to
# run on your system.
controller_js2 <-
  crew::crew_controller_local(
    name = "js2",
    workers = 5,
    seconds_idle = 60,
    options_local = crew::crew_options_local(
      log_directory = "logs/"
    )
  )

threshold <- c(
  #ºF
  50,
  650,
  1250,
  1950,
  2500
)

# Set target options:
tar_option_set(
  trust_timestamps = TRUE, #just check last modified date when deciding whether to re-run
  # Packages that your targets need for their tasks.
  packages = c(
    "fs",
    "terra",
    "stringr",
    "lubridate",
    "colorspace",
    "purrr",
    "ggplot2",
    "tidyterra",
    "glue",
    "httr2",
    "readr",
    "sf",
    "maps",
    "tidyr",
    "dplyr",
    "forcats"
  ),
  controller = controller_js2,
  #assume workers have access to the _targets/ data store
  storage = "worker",
  retrieval = "worker",
  memory = "auto",
  #allows use of `tar_workspace()` to load dependencies of an errored target for interactive debugging.
  workspace_on_error = TRUE
)

# `source()` the R scripts in the R/ folder with your custom functions:
targets::tar_source()

tarchetypes::tar_plan(
  years = 1981:2023,
  tar_target(
    name = prism_tmin,
    command = get_prism(years, "tmin"),
    pattern = map(years),
    deployment = "main",
    format = "file",
    description = "download PRISM tmin"
  ),
  tar_target(
    name = prism_tmax,
    command = get_prism(years, "tmax"),
    pattern = map(years),
    deployment = "main",
    format = "file",
    description = "download PRISM tmax"
  ),
  tar_terra_vect(
    roi,
    make_roi(),
    deployment = "main",
    description = "vector for North East"
  ),
  tar_map(
    # for each threshold...
    values = list(threshold = threshold),
    tar_terra_rast(
      gdd_doy,
      calc_gdd_be_doy(
        tmin_dir = prism_tmin, #ºC, but gets converted to ºF
        tmax_dir = prism_tmax, #ºC, but gets converted to ºF
        roi = roi,
        gdd_threshold = threshold, #ºF
        gdd_base = 50 #ºF
      ),
      pattern = map(prism_tmin, prism_tmax),
      description = "calc DOY to reach threshold GDD"
    ),
    # Combine list of SpatRasters into multi-layer SpatRaster
    tar_terra_rast(
      stack,
      terra::rast(unname(gdd_doy))
    ),
    #summary statistics across years
    tar_target(
      doy_range,
      range(stack) |> values() |> range(na.rm = TRUE)
    ),
    tar_terra_rast(
      doy_mean,
      #should NAs be removed?  NAs are "never reached this threshold", not "missing data"
      mean(stack, na.rm = TRUE)
    ),
    tar_terra_rast(
      doy_min,
      min(stack, na.rm = TRUE)
    ),
    tar_terra_rast(
      doy_max,
      max(stack, na.rm = TRUE)
    ),
    tar_terra_rast(
      doy_count,
      count_gdd_reached(stack = stack, roi = roi),
      description = "how many years reached this threshold"
    ),
    tar_terra_rast(
      doy_sd,
      stdev(stack, na.rm = TRUE)
    ),
    tar_terra_rast(
      linear_slopes,
      calc_linear_slopes(stack)
    )
  ), #end tar_map()
  tar_file(
    summary_plot,
    plot_summary_grid(
      roi = roi,
      !!!rlang::syms(c(
        glue::glue("doy_min_{threshold}"),
        glue::glue("doy_mean_{threshold}"),
        glue::glue("doy_max_{threshold}")
      ))
    ),
    packages = c("ggplot2", "tidyterra", "stringr", "terra", "purrr")
  ),
  tar_file(
    sd_plot,
    plot_sd_doy(!!!rlang::syms(glue::glue("doy_sd_{threshold}")), roi = roi),
    packages = c("ggplot2", "tidyterra", "stringr", "terra", "purrr")
  ),
  tar_file(
    count_plot,
    plot_count_years(
      !!!rlang::syms(glue::glue("doy_count_{threshold}")),
      roi = roi
    ),
    packages = c("ggplot2", "tidyterra", "stringr", "terra", "purrr")
  ),
  tar_file(
    linear_slopes_plot,
    plot_linear_slopes(
      !!!rlang::syms(glue::glue("linear_slopes_{threshold}")),
      roi = roi
    )
  ),
  tarchetypes::tar_quarto(readme, "README.Qmd")
)
