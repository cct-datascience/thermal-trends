#' @param safe if TRUE, then instead of erroring this returns `NA`.
fit_bam <- function(data, k_spatial, safe = FALSE) {
  if (isTRUE(safe)) {
    fun <- purrr::possibly(mgcv::bam, NA)
  } else {
    fun <- mgcv::bam
  }
  fun(
    DOY ~ 
      # te(x, y, year_scaled, d = c(2, 1), bs = c("tp", "cr"), k = c(k_spatial, 20)),
      ti(x, y, bs = "tp", d = 2, k = k_spatial) +
      ti(year_scaled, bs = "cr", k = 40) +
      ti(x, y, year_scaled, d = c(2,1), bs = c("tp", "cr"), k = c(200, 20)),
    family = Gamma(link = "log"),
    data = data,
    discrete = TRUE, #speeds up computation
    samfrac = 0.1, #speeds up computation
    method = "fREML",
    nthreads = c(1, 1)
    # nthreads = c(2, 1) # *possibly* speeds up computation
  )
}

fit_gamlss2 <- function(data) {
  gamlss2::gamlss2(
    DOY ~ ti(x, y, d = 2, k = 500) + ti(year_scaled, bs = "cr", k = 40) + ti(x, y, year_scaled, d = c(2,1), bs = c("tp", "cr"), k = c(200, 20)) | s(y),
    data = data,
    family = gamlss.dist::GG, #generalized gamma appears to fit slightly better than regular gamma (GA)
    trace = FALSE
  )
}

# fit_bam_te <- function(data, k_spatial) {
#   safe_bam <- purrr::possibly(mgcv::bam, NA)
#   safe_bam(
#     DOY ~ te(x, y, year_scaled, d = c(2,1), bs = c("tp", "cr"), k = c(k_spatial, 20)),
#     data = data,
#     discrete = TRUE,
#     samfrac = 0.1, #speeds up computation
#     method = "fREML"
#   )
# }

# fit_ncv <- function(data, nei, k_spatial = 25, k_year = 10, threads = 2) {
#   mgcv::gam(
#     doy ~ ti(y, x, bs = "cr", d = 2, k = k_spatial) +
#       ti(year_scaled, bs = "cr", k = k_year) +
#       ti(y, x, year_scaled, d = c(2,1), bs = c("cr", "cr"), k = c(k_spatial, k_year)),
#     data = data,
#     method = "NCV",
#     nei = nei,
#     control = gam.control(ncv.threads = threads)
#   )
# }
