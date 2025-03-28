# library(ggplot2)
# library(tidyterra)
# library(targets)
# library(colorspace)
# tar_load(starts_with("linear_slopes"))
# tar_load(roi)

# dots <- rlang::dots_list(linear_slopes_50, linear_slopes_650, linear_slopes_1250, linear_slopes_1950, linear_slopes_2500, .named = TRUE)

#' Plot pixel-wise linear slopes
#' 
#' Currently plots each threshold on it's own scale with the limits of the scale 
#' encompasing 99% of the data points with more extreme values being lumped in
#' with the limits
#' 
#' @param ... linear_slopes_{threshold} targets
#' @param use_percentile_lims use limits that capture 99% of the DOY values.
#' 
plot_linear_slopes <- function(..., roi, use_percentile_lims = TRUE) {
  dots <- rlang::dots_list(..., .named = TRUE)
  thresholds <- stringr::str_extract(names(dots), "\\d+")
  stack <- terra::rast(dots)
  names(stack) <- thresholds
  # range <- range(terra::values(stack), na.rm = TRUE)
  # limits <- dplyr::coalesce(limits, range)
  
  p_list <- purrr::map2(dots, thresholds, \(raster, threshold) {
    if(use_percentile_lims) {
      limits <- raster |> terra::values() |> quantile(probs = c(0.005, 0.995), na.rm = TRUE)
    }
  
    ggplot() +
      # facet_wrap(vars(lyr)) +
      geom_spatvector(data = roi, fill = "white") +
      geom_spatraster(data = raster) +
      scale_fill_continuous_diverging(
        palette = "Blue-Red 3",
        na.value = "transparent", 
        rev = TRUE, 
        limits = limits,
        oob = scales::oob_squish,
        breaks = breaks_limits(
          n = 5,
          min = !is.na(limits[1]),
          max = !is.na(limits[2]),
          tol = 0.15
        )
      ) +
    # scale_fill_binned_diverging(
    #   palette = "Blue-Red 3",
    #   na.value = "transparent", 
    #   rev = TRUE,
    #   n.breaks = 7
    # ) +
    labs(
      title = glue::glue("{threshold} GDD"),
      fill = "Linear slope (DOY/yr)"
    ) +
    # coord_sf(crs = "ESRI:102010") +
    theme_minimal() +
    theme(
      legend.position = "bottom",
      legend.title.position = "top",
      legend.key.width = unit(0.5, "inches"),
      legend.key.height = unit(0.2, "inches")
    )
    # p
  })
  
  p <- patchwork::wrap_plots(p_list)

  ggplot2::ggsave(
    filename = "linear_slopes.png",
    plot = p,
    path = "output/linear-slopes/",
    bg = "white",
    width = 15,
    height = 10
  )
}

# plot_linear_slopes(linear_slopes_50, c(NA, NA))
# plot_linear_slopes(linear_slopes_650, linear_slope_limits)
# plot_linear_slopes(linear_slopes_1250, linear_slope_limits)
# plot_linear_slopes(linear_slopes_1950, linear_slope_limits)
# plot_linear_slopes(linear_slopes_2500, linear_slope_limits)


# #global range
# plot_linear_slopes(linear_slopes_1950, linear_slope_limits)
# #range for just this threshold
# plot_linear_slopes(linear_slopes_1950, c(NA, NA))
# #arbitrary narrower range
# plot_linear_slopes(linear_slopes_1950, c(-0.5, 0.5))