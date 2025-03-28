

<!-- README.md is generated from README.Qmd. Please edit that file -->

# Estimating trends in phenology

<!-- badges: start -->

[![Project Status: WIP – Initial development is in progress, but there
has not yet been a stable, usable release suitable for the
public.](https://www.repostatus.org/badges/latest/wip.svg)](https://www.repostatus.org/#wip)

<!-- badges: end -->

The goal of this project is to estimate spatial and temporal trends in
phenology in the Northeastern US using
[PRISM](https://prism.oregonstate.edu/) temperature data. This
analytical pipeline downloads daily data, calculates growing degree days
(GDD) for each day, and then finds the day of year (DOY) that certain
threshold GDD are reached for this region. It then uses DOY as a
response variable in a series of generalized additive models to estimate
spatio-temporal trends.

Report of work in progress:
<https://usa-npn.github.io/thermal-trends/spatial-trends-report.html>

## Reproducibility

This workflow requires a lot of computational power and disk space.
Currently it runs on a Jetstream2 instance with 16 cores and 60GB of ram
on a 500GB disk. Even then, the disk occasionally fills up and the temp
directory needs to be manually cleared out as intermediate tiff files
accumulate. I’ve used a `.Renviron` file to set the `TMPDIR` variable to
make sure `tmpdir()` is on a large enough attached volume rather than
the root disk, which for Jetstream2 is only 50GB.

### `renv`

This project uses
[`renv`](https://rstudio.github.io/renv/articles/renv.html) for package
management. When opening this repo as an RStudio Project for the first
time, `renv` should automatically install itself and prompt you to run
`renv::restore()` to install all package dependencies.

### `targets`

This project uses the [`targets`
package](https://docs.ropensci.org/targets/) for workflow management.
Run `targets::tar_make()` from the console or from the HPC run
`sbatch run.sh` to run the workflow and reproduce all results. The graph
below shows the workflow:

- The project is out-of-sync – use `renv::status()` for details. qs2
  0.1.3

``` mermaid
graph LR
  style Legend fill:#FFFFFF00,stroke:#000000;
  style Graph fill:#FFFFFF00,stroke:#000000;
  subgraph Legend
    direction LR
    xf1522833a4d242c5([""Up to date""]):::uptodate --- xb6630624a7b3aa0f([""Dispatched""]):::dispatched
    xb6630624a7b3aa0f([""Dispatched""]):::dispatched --- xd03d7c7dd2ddda2b([""Stem""]):::none
    xd03d7c7dd2ddda2b([""Stem""]):::none --- x6f7e04ea3427f824[""Pattern""]:::none
  end
  subgraph Graph
    direction LR
    x73ccc223e5bb7e64(["roi"]):::uptodate --> xb975a0de585a7cb3(["doy_count_1950"]):::uptodate
    x8aa20a6b22429bc6(["stack_1950"]):::uptodate --> xb975a0de585a7cb3(["doy_count_1950"]):::uptodate
    x8aa20a6b22429bc6(["stack_1950"]):::uptodate --> xfaa1b336713647bd(["doy_max_1950"]):::uptodate
    x98420a84329bc56b(["stack_650"]):::uptodate --> x3b41173937ea916b(["doy_max_650"]):::uptodate
    x9bfde4bdb66389ab(["stack_2500"]):::uptodate --> xbaf200af7f0a71f4(["doy_max_2500"]):::uptodate
    xb76c0bbea0c751b0["prism_tmax"]:::uptodate --> x2fee061101c79ea2["gdd_doy_1950"]:::uptodate
    xcaf68fce9acaa5b6["prism_tmin"]:::uptodate --> x2fee061101c79ea2["gdd_doy_1950"]:::uptodate
    x73ccc223e5bb7e64(["roi"]):::uptodate --> x2fee061101c79ea2["gdd_doy_1950"]:::uptodate
    x6672cfab7f0558ba["gdd_doy_650"]:::uptodate --> x98420a84329bc56b(["stack_650"]):::uptodate
    xb76c0bbea0c751b0["prism_tmax"]:::uptodate --> x28c62ae9542e7849["gdd_doy_2500"]:::uptodate
    xcaf68fce9acaa5b6["prism_tmin"]:::uptodate --> x28c62ae9542e7849["gdd_doy_2500"]:::uptodate
    x73ccc223e5bb7e64(["roi"]):::uptodate --> x28c62ae9542e7849["gdd_doy_2500"]:::uptodate
    xff5a5197cb4eb936(["stack_50"]):::uptodate --> x3f0b57afa77b66b5(["doy_mean_50"]):::uptodate
    x9bfde4bdb66389ab(["stack_2500"]):::uptodate --> x9b5edd14021dcb36(["doy_sd_2500"]):::uptodate
    xff5a5197cb4eb936(["stack_50"]):::uptodate --> xf8fd2a7799e60707(["doy_sd_50"]):::uptodate
    x7761f97c329292a2(["doy_sd_1250"]):::uptodate --> x1a7be1bbbb0646ca(["sd_plot"]):::uptodate
    xab42aceb61ccf7c4(["doy_sd_1950"]):::uptodate --> x1a7be1bbbb0646ca(["sd_plot"]):::uptodate
    x9b5edd14021dcb36(["doy_sd_2500"]):::uptodate --> x1a7be1bbbb0646ca(["sd_plot"]):::uptodate
    xf8fd2a7799e60707(["doy_sd_50"]):::uptodate --> x1a7be1bbbb0646ca(["sd_plot"]):::uptodate
    xaa41c2217bcfce37(["doy_sd_650"]):::uptodate --> x1a7be1bbbb0646ca(["sd_plot"]):::uptodate
    x73ccc223e5bb7e64(["roi"]):::uptodate --> x1a7be1bbbb0646ca(["sd_plot"]):::uptodate
    x9bfde4bdb66389ab(["stack_2500"]):::uptodate --> xfcd12ec626286c45(["linear_slopes_2500"]):::uptodate
    x3290bd5727894db5(["stack_1250"]):::uptodate --> x7761f97c329292a2(["doy_sd_1250"]):::uptodate
    x3290bd5727894db5(["stack_1250"]):::uptodate --> x876ba53f0425363a(["doy_range_1250"]):::uptodate
    x3290bd5727894db5(["stack_1250"]):::uptodate --> x0aa922b42cc7ec98(["doy_min_1250"]):::uptodate
    xb76c0bbea0c751b0["prism_tmax"]:::uptodate --> x6672cfab7f0558ba["gdd_doy_650"]:::uptodate
    xcaf68fce9acaa5b6["prism_tmin"]:::uptodate --> x6672cfab7f0558ba["gdd_doy_650"]:::uptodate
    x73ccc223e5bb7e64(["roi"]):::uptodate --> x6672cfab7f0558ba["gdd_doy_650"]:::uptodate
    xc8e128aab3cd4a9e["gdd_doy_1250"]:::uptodate --> x3290bd5727894db5(["stack_1250"]):::uptodate
    x9bfde4bdb66389ab(["stack_2500"]):::uptodate --> x6c953909fe7b8fce(["doy_range_2500"]):::uptodate
    x3290bd5727894db5(["stack_1250"]):::uptodate --> xa03f63aab8c8f229(["linear_slopes_1250"]):::uptodate
    x98420a84329bc56b(["stack_650"]):::uptodate --> x1dcca7d9763aaf8a(["linear_slopes_650"]):::uptodate
    xa03f63aab8c8f229(["linear_slopes_1250"]):::uptodate --> x9a95e37bbec60034(["linear_slopes_plot"]):::uptodate
    x221db657f963d78d(["linear_slopes_1950"]):::uptodate --> x9a95e37bbec60034(["linear_slopes_plot"]):::uptodate
    xfcd12ec626286c45(["linear_slopes_2500"]):::uptodate --> x9a95e37bbec60034(["linear_slopes_plot"]):::uptodate
    x851dcaf881ece133(["linear_slopes_50"]):::uptodate --> x9a95e37bbec60034(["linear_slopes_plot"]):::uptodate
    x1dcca7d9763aaf8a(["linear_slopes_650"]):::uptodate --> x9a95e37bbec60034(["linear_slopes_plot"]):::uptodate
    x73ccc223e5bb7e64(["roi"]):::uptodate --> x9a95e37bbec60034(["linear_slopes_plot"]):::uptodate
    x8aa20a6b22429bc6(["stack_1950"]):::uptodate --> x0b8fc05dde8aff20(["doy_mean_1950"]):::uptodate
    x786a1a0a06ddc553["gdd_doy_50"]:::uptodate --> xff5a5197cb4eb936(["stack_50"]):::uptodate
    x98420a84329bc56b(["stack_650"]):::uptodate --> xaa41c2217bcfce37(["doy_sd_650"]):::uptodate
    x28c62ae9542e7849["gdd_doy_2500"]:::uptodate --> x9bfde4bdb66389ab(["stack_2500"]):::uptodate
    x73ccc223e5bb7e64(["roi"]):::uptodate --> xd35b859168289648(["doy_count_650"]):::uptodate
    x98420a84329bc56b(["stack_650"]):::uptodate --> xd35b859168289648(["doy_count_650"]):::uptodate
    x73ccc223e5bb7e64(["roi"]):::uptodate --> x8345cb9a3930330b(["doy_count_1250"]):::uptodate
    x3290bd5727894db5(["stack_1250"]):::uptodate --> x8345cb9a3930330b(["doy_count_1250"]):::uptodate
    xb76c0bbea0c751b0["prism_tmax"]:::uptodate --> x786a1a0a06ddc553["gdd_doy_50"]:::uptodate
    xcaf68fce9acaa5b6["prism_tmin"]:::uptodate --> x786a1a0a06ddc553["gdd_doy_50"]:::uptodate
    x73ccc223e5bb7e64(["roi"]):::uptodate --> x786a1a0a06ddc553["gdd_doy_50"]:::uptodate
    x3290bd5727894db5(["stack_1250"]):::uptodate --> x9921732670cb72dd(["doy_max_1250"]):::uptodate
    x98420a84329bc56b(["stack_650"]):::uptodate --> xcbcdbe4c5a587e73(["doy_range_650"]):::uptodate
    x73ccc223e5bb7e64(["roi"]):::uptodate --> x4357d0964999edf6(["doy_count_2500"]):::uptodate
    x9bfde4bdb66389ab(["stack_2500"]):::uptodate --> x4357d0964999edf6(["doy_count_2500"]):::uptodate
    x8aa20a6b22429bc6(["stack_1950"]):::uptodate --> xab42aceb61ccf7c4(["doy_sd_1950"]):::uptodate
    xff5a5197cb4eb936(["stack_50"]):::uptodate --> x01c3ae4c10fdd4d6(["doy_range_50"]):::uptodate
    xb76c0bbea0c751b0["prism_tmax"]:::uptodate --> xc8e128aab3cd4a9e["gdd_doy_1250"]:::uptodate
    xcaf68fce9acaa5b6["prism_tmin"]:::uptodate --> xc8e128aab3cd4a9e["gdd_doy_1250"]:::uptodate
    x73ccc223e5bb7e64(["roi"]):::uptodate --> xc8e128aab3cd4a9e["gdd_doy_1250"]:::uptodate
    xf9ac23fbc741da6f(["years"]):::uptodate --> xcaf68fce9acaa5b6["prism_tmin"]:::uptodate
    x8aa20a6b22429bc6(["stack_1950"]):::uptodate --> x221db657f963d78d(["linear_slopes_1950"]):::uptodate
    x98420a84329bc56b(["stack_650"]):::uptodate --> x5df30f9b999945d4(["doy_min_650"]):::uptodate
    x9921732670cb72dd(["doy_max_1250"]):::uptodate --> x000fd996de9c9b5d(["summary_plot"]):::uptodate
    xfaa1b336713647bd(["doy_max_1950"]):::uptodate --> x000fd996de9c9b5d(["summary_plot"]):::uptodate
    xbaf200af7f0a71f4(["doy_max_2500"]):::uptodate --> x000fd996de9c9b5d(["summary_plot"]):::uptodate
    x85b1fd2d84bf4f02(["doy_max_50"]):::uptodate --> x000fd996de9c9b5d(["summary_plot"]):::uptodate
    x3b41173937ea916b(["doy_max_650"]):::uptodate --> x000fd996de9c9b5d(["summary_plot"]):::uptodate
    xf6258223f6e4b99a(["doy_mean_1250"]):::uptodate --> x000fd996de9c9b5d(["summary_plot"]):::uptodate
    x0b8fc05dde8aff20(["doy_mean_1950"]):::uptodate --> x000fd996de9c9b5d(["summary_plot"]):::uptodate
    x708c6b484a9467bc(["doy_mean_2500"]):::uptodate --> x000fd996de9c9b5d(["summary_plot"]):::uptodate
    x3f0b57afa77b66b5(["doy_mean_50"]):::uptodate --> x000fd996de9c9b5d(["summary_plot"]):::uptodate
    xd9d49f9324b92ead(["doy_mean_650"]):::uptodate --> x000fd996de9c9b5d(["summary_plot"]):::uptodate
    x0aa922b42cc7ec98(["doy_min_1250"]):::uptodate --> x000fd996de9c9b5d(["summary_plot"]):::uptodate
    x87c2676be0ffa8f5(["doy_min_1950"]):::uptodate --> x000fd996de9c9b5d(["summary_plot"]):::uptodate
    x8edf410300c11dca(["doy_min_2500"]):::uptodate --> x000fd996de9c9b5d(["summary_plot"]):::uptodate
    x3355e3f305597f15(["doy_min_50"]):::uptodate --> x000fd996de9c9b5d(["summary_plot"]):::uptodate
    x5df30f9b999945d4(["doy_min_650"]):::uptodate --> x000fd996de9c9b5d(["summary_plot"]):::uptodate
    x73ccc223e5bb7e64(["roi"]):::uptodate --> x000fd996de9c9b5d(["summary_plot"]):::uptodate
    x8aa20a6b22429bc6(["stack_1950"]):::uptodate --> xdd7d50d2e5f7bc21(["doy_range_1950"]):::uptodate
    x9bfde4bdb66389ab(["stack_2500"]):::uptodate --> x708c6b484a9467bc(["doy_mean_2500"]):::uptodate
    x73ccc223e5bb7e64(["roi"]):::uptodate --> x254d7cf5a7c2ecc8(["doy_count_50"]):::uptodate
    xff5a5197cb4eb936(["stack_50"]):::uptodate --> x254d7cf5a7c2ecc8(["doy_count_50"]):::uptodate
    x8aa20a6b22429bc6(["stack_1950"]):::uptodate --> x87c2676be0ffa8f5(["doy_min_1950"]):::uptodate
    x2fee061101c79ea2["gdd_doy_1950"]:::uptodate --> x8aa20a6b22429bc6(["stack_1950"]):::uptodate
    x98420a84329bc56b(["stack_650"]):::uptodate --> xd9d49f9324b92ead(["doy_mean_650"]):::uptodate
    x8345cb9a3930330b(["doy_count_1250"]):::uptodate --> x11c2bf776c83b19c(["count_plot"]):::uptodate
    xb975a0de585a7cb3(["doy_count_1950"]):::uptodate --> x11c2bf776c83b19c(["count_plot"]):::uptodate
    x4357d0964999edf6(["doy_count_2500"]):::uptodate --> x11c2bf776c83b19c(["count_plot"]):::uptodate
    x254d7cf5a7c2ecc8(["doy_count_50"]):::uptodate --> x11c2bf776c83b19c(["count_plot"]):::uptodate
    xd35b859168289648(["doy_count_650"]):::uptodate --> x11c2bf776c83b19c(["count_plot"]):::uptodate
    x73ccc223e5bb7e64(["roi"]):::uptodate --> x11c2bf776c83b19c(["count_plot"]):::uptodate
    x9bfde4bdb66389ab(["stack_2500"]):::uptodate --> x8edf410300c11dca(["doy_min_2500"]):::uptodate
    xf9ac23fbc741da6f(["years"]):::uptodate --> xb76c0bbea0c751b0["prism_tmax"]:::uptodate
    x3290bd5727894db5(["stack_1250"]):::uptodate --> xf6258223f6e4b99a(["doy_mean_1250"]):::uptodate
    xff5a5197cb4eb936(["stack_50"]):::uptodate --> x85b1fd2d84bf4f02(["doy_max_50"]):::uptodate
    xff5a5197cb4eb936(["stack_50"]):::uptodate --> x851dcaf881ece133(["linear_slopes_50"]):::uptodate
    xff5a5197cb4eb936(["stack_50"]):::uptodate --> x3355e3f305597f15(["doy_min_50"]):::uptodate
    xc11069275cfeb620(["readme"]):::dispatched --> xc11069275cfeb620(["readme"]):::dispatched
  end
  classDef uptodate stroke:#000000,color:#ffffff,fill:#354823;
  classDef dispatched stroke:#000000,color:#000000,fill:#DC863B;
  classDef none stroke:#000000,color:#000000,fill:#94a4ac;
  linkStyle 0 stroke-width:0px;
  linkStyle 1 stroke-width:0px;
  linkStyle 2 stroke-width:0px;
  linkStyle 99 stroke-width:0px;
```

------------------------------------------------------------------------

Developed in collaboration with the University of Arizona [CCT Data
Science](https://datascience.cct.arizona.edu/) group.
