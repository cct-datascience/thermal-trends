count_gdd_reached <- function(stack, roi) {
  roi <- terra::project(roi, stack)
  app(stack, \(x) sum(is.finite(x))) |> mask(roi)
}