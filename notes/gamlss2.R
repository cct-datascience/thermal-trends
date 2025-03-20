library(gamlss2)
library(targets)
tar_load(gam_df_1950)
tar_load(gam_1950)
tar_load(gamlss_test)
find_family(gam_df_1950$DOY)
# SEP1 has lowest IC, EGB2 and WEI2 have highest IC
# GG is one of the lower ones, but there are many lower than it.

plot(gamlss_test, which = "hist-resid")
plot(gamlss_test, which = "qq-resid")
plot(gamlss_test, which = "scatter-resid")

#wow, cool.  seems to have helped!

#sigma (variance) vs. latitude
options(scipen = 999)
plot(gamlss_test, which = "effects", term = 3, scale = 0, xlab = "latitude (m)")
options(scipen = 0)

summary(gamlss_test)

#can I get avg_slopes() to "just work"
library(marginaleffects)
tar_load(newdata_stack_1950_gam_1950)

newdata_slice <- newdata_stack_1950_gam_1950 |> dplyr::filter(tar_group == 2)
source("R/calc_avg_slopes.R")
avg_slope_test <- calc_avg_slopes(gamlss_test, newdata_slice)
