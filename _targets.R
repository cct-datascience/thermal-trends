# Created by use_targets().
# Follow the comments below to fill in this target script.
# Then follow the manual to check and run the pipeline:
#   https://books.ropensci.org/targets/walkthrough.html#inspect-the-pipeline

# Load packages required to define the pipeline:
library(targets)
library(tarchetypes)
library(geotargets)
library(crew)
library(crew.cluster)
library(qs2) #for format = "qs"
library(nanoparquet) #for format = tar_format_nanoparquet()

# TODO: remove SLURM stuff as we are not using UAHPC anymore

# Detect whether you're on HPC & not with an Open On Demand session (which cannot submit SLURM jobs).
slurm_host <- Sys.getenv("SLURM_SUBMIT_HOST")
hpc <- grepl("hpc\\.arizona\\.edu", slurm_host) & !grepl("ood", slurm_host)

controller_hpc_light <- 
  crew.cluster::crew_controller_slurm(
    name = "hpc_light",
    workers = 5, 
    # make workers semi-persistent: 
    tasks_max = 40, # shut down SLURM job after completing 40 targets
    seconds_idle = 300, # or when idle for some time
    options_cluster = crew_options_slurm(
      script_lines = c(
        "#SBATCH --account theresam",
        #use optimized openBLAS for linear algebra
        "export LD_PRELOAD=/opt/ohpc/pub/libs/gnu13/openblas/0.3.21/lib/libopenblas.so",
        "module load gdal/3.8.5 R/4.4 eigen/3.4.0"
      ),
      log_output = "logs/crew_log_%A.out",
      log_error = "logs/crew_log_%A.err",
      memory_gigabytes_per_cpu = 5,
      cpus_per_task = 3, #use 3 cpus per worker
      time_minutes = 60, #wall time for each worker
      partition = "standard"
    )
  )

controller_hpc_heavy <- 
  crew.cluster::crew_controller_slurm(
    name = "hpc_heavy",
    workers = 3, 
    tasks_max = 20,
    seconds_idle = 1000,
    options_cluster = crew_options_slurm(
      script_lines = c(
        "#SBATCH --account theresam",
        "export LD_PRELOAD=/opt/ohpc/pub/libs/gnu13/openblas/0.3.21/lib/libopenblas.so",
        "module load gdal/3.8.5 R/4.4 eigen/3.4.0"
      ),
      log_output = "logs/crew_heavy_log_%A.out",
      log_error = "logs/crew_heavy_log_%A.err",
      memory_gigabytes_per_cpu = 5,
      cpus_per_task = 8, 
      time_minutes = 360, #wall time for each worker
      partition = "standard"
    )
  )

controller_local <-
  crew::crew_controller_local(
    name = "local",
    workers = 5, 
    seconds_idle = 60,
    options_local = crew::crew_options_local(
      log_directory = "logs/"
    )
  )

threshold <- c( #ºF
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
    "car",
    "httr2",
    "readr",
    "sf",
    "maps",
    "tidyr",
    "dplyr",
    "broom",
    "forcats",
    "mgcv"
  ), 
  controller = crew::crew_controller_group(
    controller_hpc_heavy, controller_hpc_light, controller_local
  ),
  resources = tar_resources(
    crew = tar_resources_crew(controller = ifelse(isTRUE(hpc), "hpc_light", "local"))
  ),
  #assume workers have access to the _targets/ data store
  storage = "worker",
  retrieval = "worker",
  memory = "auto",
  #allows use of `tar_workspace()` to load dependencies of an errored target for interactive debugging.
  workspace_on_error = TRUE 
)

# `source()` the R scripts in the R/ folder with your custom functions:
targets::tar_source()


main <- tarchetypes::tar_plan(
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
  tar_map( # for each threshold...
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
    tar_target(
      gam_df,
      make_gam_df(stack, res = 50000),
      format = "qs"
    ),
    ## GAMs ###
    # NOTE: if k_spatial needs to be adjusted for each threshold,
    # create a dataframe to pass to `values` arg of `tar_map()`
    tar_target(
      gam,
      fit_bam(gam_df, k_spatial = 500), 
      format = "qs",
      resources = tar_resources(
        crew = tar_resources_crew(controller = ifelse(isTRUE(hpc), "hpc_heavy", "local"))
      )
    ),
    # Model diagnostics
    tar_file(
      smooths,
      draw_partial_effects(gam, roi)
    ),
    tar_file(
      appraisal,
      appraise_gam(gam)
    ),
    tar_target(
      k_check,
      check_k(gam),
      packages = c("mgcv", "dplyr")
    )
  ), #end tar_map()
  tar_file(
    summary_plot,
    plot_summary_grid(roi = roi, !!!rlang::syms(c(
      glue::glue("doy_min_{threshold}"),
      glue::glue("doy_mean_{threshold}"),
      glue::glue("doy_max_{threshold}")
    ))),
    packages = c("ggplot2", "tidyterra", "stringr", "terra", "purrr")
  ),
  tar_file(
    sd_plot,
    plot_sd_doy(!!!rlang::syms(glue::glue("doy_sd_{threshold}")), roi = roi),
    packages = c("ggplot2", "tidyterra", "stringr", "terra", "purrr")
  ),
  tar_file(
    count_plot,
    plot_count_years(!!!rlang::syms(glue::glue("doy_count_{threshold}")), roi = roi),
    packages = c("ggplot2", "tidyterra", "stringr", "terra", "purrr")
  )
)

slopes <- tar_plan(
  tar_map(
    values = list(
      stack = rlang::syms(glue::glue("stack_{threshold}")),
      gam = rlang::syms(glue::glue("gam_{threshold}"))
    ),
    tar_target(
      newdata,
      make_slope_newdata(stack, res_m = 50000) |>
        dplyr::group_by(group) |>
        targets::tar_group(),
      #grouped by about 1000 pixels per group
      iteration = "group",
      format = "qs"
    ),
    tar_target(
      slopes,
      calc_avg_slopes(gam, newdata),
      packages = c("marginaleffects", "mgcv"),
      resources = tar_resources(
        crew = tar_resources_crew(controller = ifelse(isTRUE(hpc), "hpc_heavy", "local"))
      ),
      pattern = map(newdata),
      format = tar_format_nanoparquet()
    ),
    tar_target(
      slope_range,
      range(slopes$estimate),
      resources = tar_resources(
        crew = tar_resources_crew(controller = ifelse(isTRUE(hpc), "hpc_heavy", "local"))
      ),
      pattern = map(slopes),
      format = "qs"
    )
  )
)

slopes_plots <- tar_plan(
  tar_target(
    slope_range,
    range(!!!rlang::syms(glue::glue("slope_range_stack_{threshold}_gam_{threshold}"))),
    description = "range across all thresholds for colorbar",
    tidy_eval = TRUE
  ),
  tar_map(
    values = list(slopes = rlang::syms(glue::glue("slopes_stack_{threshold}_gam_{threshold}"))),
    tar_file(
      slopes_plot,
      plot_avg_slopes(slopes, slope_range, roi),
      packages = c("ggpattern", "ggplot2", "terra", "tidyterra"),
      resources = tar_resources(
        crew = tar_resources_crew(controller = ifelse(isTRUE(hpc), "hpc_heavy", "local"))
      )
    )
  )
)


# gams <- tarchetypes::tar_plan(
  #prep data
  # tar_map(
    # values = list(threshold = threshold),
    # tar_target(
    #   gam_df,
    #   make_gam_df(stack_650, res = 25000),
    #   format = "qs"
    # )
  # )
  #fit gams
  # tar_target(
  #   gam_650,
  #   fit_bam(gam_df_650, k_spatial = 1000),
  #   format = "qs",
  #   resources = tar_resources(
  #     crew = tar_resources_crew(controller = ifelse(isTRUE(hpc), "hpc_heavy", "local"))
  #   )
  # ),
  
  #model diagnostics
  # tar_file(
  #   smooths_650,
  #   draw_partial_effects(gam_650, roi)
  # ),
  # tar_file(
  #   appraisal_650,
  #   appraise_gam(gam_650)
  # ),
  # tar_target(
  #   k_check_650,
  #   check_k(gam_650),
  #   packages = c("mgcv", "dplyr")
  # ),

  # tar_target(
  #   k_check_df,
  #   bind_rows(!!!rlang::syms(c(
  #     "k_check_650"
  #   ))),
  #   tidy_eval = TRUE,
  #   description = "Collect results from k_check targets"
  # ),
  # tar_file(
  #   k_check_df_csv,
  #   tar_write_csv(k_check_df, "output/gams/k_check.csv")
  # ),
  
#TODO: consider bigger chunks since not RAM limited, but CPU limited.
  # tar_target(
  #   slope_newdata,
  #   #doesn't matter which dataset since all that is used is x,y, and year_scaled
  #   #using very coarse newdata regardless of resolution of original data.
  #   make_slope_newdata(stack_650, res_m = 25000) |>
  #     dplyr::group_by(group) |>
  #     targets::tar_group(),
  #   #grouped by about 1000 pixels per group
  #   iteration = "group",
  #   format = "qs"
  # ),
  # tar_target(
  #   cities_sf,
  #   make_cities_sf(),
  #   description = "Example cities for plotting fitted trends"
  # ),
  # tar_map(
  #   values = list(gam = rlang::syms(c("gam_650"))),
  #   tar_target(
  #     slopes,
  #     calc_avg_slopes(gam, slope_newdata),
  #     packages = c("marginaleffects", "mgcv"),
  #     resources = tar_resources(
  #       crew = tar_resources_crew(controller = ifelse(isTRUE(hpc), "hpc_heavy", "local"))
  #     ),
  #     pattern = map(slope_newdata),
  #     format = tar_format_nanoparquet()
  #   ),
  #   tar_target(
  #     slope_range,
  #     range(slopes$estimate),
  #     resources = tar_resources(
  #       crew = tar_resources_crew(controller = ifelse(isTRUE(hpc), "hpc_heavy", "local"))
  #     ),
  #     pattern = map(slopes),
  #     format = "qs"
  #   )#,
    # tar_target(
    #   city_plot,
    #   plot_city_trend(gam, cities_sf),
    #   description = "timeseries plot for example cities for each gam"
    # )
  # ),
  # tar_target(
  #   slope_range,
  #   range(slope_range_gam_650),
  #   description = "range across all thresholds for colorbar"
  # ),
  # tar_map(
  #   values = list(
  #     slopes = rlang::syms(c(
  #       "slopes_gam_650"
  #     ))#,
      # city_plot = rlang::syms(c(
      #   "city_plot_gam_650"
      # ))
#     ),
#     tar_file(
#       slopes_plot,
#       plot_avg_slopes(slopes, slope_range, roi),
#       packages = c("ggpattern", "ggplot2", "terra", "tidyterra"),
#       resources = tar_resources(
#         crew = tar_resources_crew(controller = ifelse(isTRUE(hpc), "hpc_heavy", "local"))
#       )
#     )
#   )
# )
# city_slopes <- tar_plan(
#   tar_map(
#     values = list(gam = rlang::syms(c("gam_50gdd", "gam_400gdd", "gam_800gdd"))),
#     tar_target(
#       city_slopes,
#       calc_city_slopes(cities_sf, gam),
#       format = tar_format_nanoparquet(),
#       resources = tar_resources(
#         crew = tar_resources_crew(controller = ifelse(isTRUE(hpc), "hpc_heavy", "local"))
#       ),
#       description = "for each GDD threshold, calc avg slope for specific cities"
#     )
#   )
# )
# city_slopes_plot <- tar_plan(
#   tar_combine(
#     city_slopes_df,
#     city_slopes,
#     format = tar_format_nanoparquet(),
#     description = "combine predictions from all GDD thresholds for plotting"
#   )
# )

tarchetypes::tar_plan(
  main,
  slopes,
  slopes_plots,
  tar_target(
    gamlss_test,
    fit_gamlss2(data = gam_df_1950),
    packages = c("gamlss2", "gamlss", "gamlss.dist", "mgcv")
  ),

  # Doesn't work currently due to no methods in marginaleffects for gamlss2
  # tar_target(
  #   gamlss_slopes,
  #   calc_avg_slopes(gamlss_test, newdata_stack_1950_gam_1950),
  #     packages = c("marginaleffects", "mgcv", "gamlss2"),
  #     resources = tar_resources(
  #       crew = tar_resources_crew(controller = ifelse(isTRUE(hpc), "hpc_heavy", "local"))
  #     ),
  #     pattern = map(newdata_stack_1950_gam_1950),
  #     format = tar_format_nanoparquet()
  #   ),
  # tarchetypes::tar_quarto(report, "docs/report.qmd", quiet = FALSE)
  # gams,
  # city_slopes,
  # city_slopes_plot
)
