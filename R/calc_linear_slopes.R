calc_linear_slopes <- function(stack) {
  #being extra safe here and not assuming every year is represented
  year <- as.integer(names(stack))
  #scale
  year_scaled <- year - min(year, na.rm = TRUE)
  slopes <- terra::app(stack, \(x) {
      if (sum(is.finite(x)) < 22) { #don't bother if there's fewer than half non-NA years
        NA
      } else {
        m = lm(x ~ year_scaled)
        coef(m)[2]
      }
  })
  names(slopes) <- "slope"
  #return
  slopes
}
