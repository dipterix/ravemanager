
# ravemanager

<!-- badges: start -->
<!-- badges: end -->

Manages libraries for the [RAVE project](https://rave.wiki/)

## Install for the first time

Please make sure you have [R](https://cran.r-project.org/) installed first!

1. Open the R application. Copy and paste the following command into the "R" (or "RStudio") console: 

``` r
 install.packages('ravemanager', repos = 'https://beauchamplab.r-universe.dev')
```

2. Install system libraries (To be added)



3. Install `RAVE`

Enter the following command into R console:

```r
ravemanager::install()
```

## Check for updates

To check if `RAVE` and its dependencies are in the latest version, use the following R command

``` r
ravemanager::version_info()
```

