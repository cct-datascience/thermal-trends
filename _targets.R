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

# Detect whether you're on HPC & not with an Open On Demand session (which cannot submit SLURM jobs).
slurm_host <- Sys.getenv("SLURM_SUBMIT_HOST")
hpc <- grepl("hpc\\.arizona\\.edu", slurm_host) & !grepl("ood", slurm_host)

controller_hpc_light <- 
  crew.cluster::crew_controller_slurm(
    name = "hpc_light",
    host = Sys.info()["nodename"],
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
      time_minutes = 360, #wall time for each worker
      partition = "standard"
    )
  )

controller_hpc_heavy <- 
  crew.cluster::crew_controller_slurm(
    name = "hpc_heavy",
    host = Sys.info()["nodename"],
    workers = 3, 
    tasks_max = 20,
    seconds_idle = 300,
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
    workers = 3, 
    seconds_idle = 60,
    options_local = crew::crew_options_local(
      log_directory = "logs/"
    )
  )

#TODO: eventually replace with biologically relevant thresholds
threshold <- c(50, 400, 800)

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
tar_source()


main <- tar_plan(
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
  tar_target(
    name = prism_tmean,
    command = get_prism(years, "tmean"),
    pattern = map(years),
    deployment = "main", #prevent downloads from running in parallel on distributed workers
    format = "file", 
    description = "download PRISM tmean"
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
      calc_gdd_doy(rast_dir = prism_tmean, roi = roi, gdd_threshold = threshold, gdd_base = 10),
      pattern = map(prism_tmean),
      iteration = "list",
      description = "calc DOY to reach threshold GDD"
    ),
    
    # This converts the output of the dynamic branching to be SpatRasters with
    # multiple layers instead of lists of SpatRasters. Would love to not have to
    # have this target, but there is no way to customize how iteration works.
    tar_terra_rast(
      gdd_doy_stack,
      terra::rast(unname(gdd_doy))
    )
  )
)


gams <- tar_plan(
  #prep data
  tar_target(
    gam_df_50gdd,
    make_gam_df(gdd_doy_stack_50, res = 25000),
    format = tar_format_nanoparquet()
  ),
  tar_target(
    gam_df_400gdd,
    make_gam_df(gdd_doy_stack_400, res = 25000),
    format = tar_format_nanoparquet()
  ),
  tar_target(
    gam_df_800gdd,
    make_gam_df(gdd_doy_stack_800, res = 25000),
    format = tar_format_nanoparquet()
  ),
  #fit gams
  tar_target(
    gam_50gdd,
    fit_bam(gam_df_50gdd, k_spatial = 1000),
    format = "qs",
    resources = tar_resources(
      crew = tar_resources_crew(controller = ifelse(isTRUE(hpc), "hpc_heavy", "local"))
    )
  ),
  tar_target(
    gam_50gdd_gp,
    fit_bam_gp(gam_df_50gdd, k_spatial = 1000),
    format = "qs",
    resources = tar_resources(
      crew = tar_resources_crew(controller = ifelse(isTRUE(hpc), "hpc_heavy", "local"))
    )
  ),
  tar_target(
    gam_400gdd,
    fit_bam(gam_df_400gdd, k_spatial = 1000),
    format = "qs",
    resources = tar_resources(
      crew = tar_resources_crew(controller = ifelse(isTRUE(hpc), "hpc_heavy", "local"))
    )
  ),
  tar_target(
    gam_800gdd,
    fit_bam(gam_df_800gdd, k_spatial = 1000),
    format = "qs",
    resources = tar_resources(
      crew = tar_resources_crew(controller = ifelse(isTRUE(hpc), "hpc_heavy", "local"))
    )
  ),
  tar_file(
    smooths_50gdd,
    draw_smooth_estimates(gam_50gdd, roi)
  ),
  tar_file(
    smooths_50gdd_gp,
    draw_smooth_estimates(gam_50gdd_gp, roi)
  ),
  tar_file(
    smooths_400gdd,
    draw_smooth_estimates(gam_400gdd, roi)
  ),
  tar_file(
    smooths_800gdd,
    draw_smooth_estimates(gam_800gdd, roi)
  ),
  tar_target(
    k_check_50gdd,
    check_k(gam_50gdd),
    packages = c("mgcv", "dplyr")
  ),
  tar_target(
    k_check_400gdd,
    check_k(gam_400gdd),
    packages = c("mgcv", "dplyr")
  ),
  tar_target(
    k_check_800gdd,
    check_k(gam_800gdd),
    packages = c("mgcv", "dplyr")
  ),
  tar_target(
    k_check_df,
    bind_rows(!!!rlang::syms(c(
      "k_check_50gdd", "k_check_400gdd", "k_check_800gdd"
    ))),
    tidy_eval = TRUE,
    description = "Collect results from k_check targets"
  ),
  tar_file(
    k_check_df_csv,
    tar_write_csv(k_check_df, "output/gams/k_check.csv")
  ),
  tar_target(
    slope_newdata,
    #doesn't matter which dataset since all that is used is x,y, and year_scaled
    #using very coarse newdata regardless of resolution of original data.
    make_slope_newdata(gdd_doy_stack_50, res_m = 25000) |> 
      dplyr::group_by(group) |> 
      targets::tar_group(),
    #grouped by about 1000 pixels per group
    iteration = "group",
    format = "qs"
  ),
  tar_target(
    cities_sf,
    make_cities_sf(),
    description = "Example cities for plotting fitted trends"
  ),
  tar_map(
    values = list(gam = rlang::syms(c("gam_50gdd", "gam_400gdd", "gam_800gdd"))),
    tar_target(
      slopes,
      calc_avg_slopes(gam, slope_newdata),
      packages = c("marginaleffects", "mgcv"),
      resources = tar_resources(
        crew = tar_resources_crew(controller = ifelse(isTRUE(hpc), "hpc_heavy", "local"))
      ),
      pattern = map(slope_newdata),
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
    ),
    tar_target(
      city_plot,
      plot_city_trend(gam, cities_sf),
      description = "timeseries plot for example cities for each gam"
    )
  ),
  tar_target(
    slope_range,
    range(slope_range_gam_50gdd, slope_range_gam_400gdd, slope_range_gam_800gdd),
    description = "range across all thresholds for colorbar"
  ),
  tar_map(
    values = list(
      slopes = rlang::syms(c(
        "slopes_gam_50gdd", "slopes_gam_400gdd", "slopes_gam_800gdd"
      )),
      city_plot = rlang::syms(c(
        "city_plot_gam_50gdd", "city_plot_gam_400gdd", "city_plot_gam_800gdd"
      ))
    ),
    tar_file(
      slopes_plot,
      plot_avg_slopes(slopes, slope_range, roi, cities_sf, city_plot),
      packages = c("ggpattern", "ggplot2", "terra", "tidyterra", "patchwork"),
      resources = tar_resources(
        crew = tar_resources_crew(controller = ifelse(isTRUE(hpc), "hpc_heavy", "local"))
      )
    )
  )
)
city_slopes <- tar_plan(
  tar_map(
    values = list(gam = rlang::syms(c("gam_50gdd", "gam_400gdd", "gam_800gdd"))),
    tar_target(
      city_slopes,
      calc_city_slopes(cities_sf, gam),
      format = tar_format_nanoparquet(),
      resources = tar_resources(
        crew = tar_resources_crew(controller = ifelse(isTRUE(hpc), "hpc_heavy", "local"))
      ),
      description = "for each GDD threshold, calc avg slope for specific cities"
    )
  )
)
city_slopes_plot <- tar_plan(
  tar_combine(
    city_slopes_df,
    city_slopes,
    format = tar_format_nanoparquet(),
    description = "combine predictions from all GDD thresholds for plotting"
  )
)

tar_plan(
  main,
  gams,
  city_slopes,
  city_slopes_plot
)
