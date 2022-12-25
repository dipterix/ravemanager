
# ravemanager

Manages libraries for the [RAVE project](https://rave.wiki/)

### Version & Builder Status

|Core Package|Version|Builder Status|Description|
|:--|:--|:--|:--|
|[ravemanager](https://github.com/dipterix/ravemanager)|![r-universe](https://beauchamplab.r-universe.dev/badges/ravemanager)|[![R-CMD-check](https://github.com/dipterix/ravemanager/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/dipterix/ravemanager/actions/workflows/R-CMD-check.yaml)|Dependence manager|
|[rave](https://github.com/beauchamplab/rave)|![r-universe](https://beauchamplab.r-universe.dev/badges/rave)|[![R-CMD-check](https://github.com/beauchamplab/rave/workflows/R-CMD-check/badge.svg)](https://github.com/beauchamplab/rave/actions)|Main package|
|[ravedash](https://github.com/dipterix/ravedash)|![r-universe](https://beauchamplab.r-universe.dev/badges/ravedash)|[![R-CMD-check](https://github.com/dipterix/ravedash/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/dipterix/ravedash/actions/workflows/R-CMD-check.yaml)|Framework for front-end dashboard|
|[ravetools](https://github.com/dipterix/ravetools)|![r-universe](https://beauchamplab.r-universe.dev/badges/ravetools)|[![R-CMD-check](https://github.com/dipterix/ravetools/workflows/R-CMD-check/badge.svg)](https://github.com/dipterix/ravetools/actions)|Signal processing|
|[raveio](https://github.com/beauchamplab/raveio)|![r-universe](https://beauchamplab.r-universe.dev/badges/raveio)|[![R-CMD-check](https://github.com/beauchamplab/raveio/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/beauchamplab/raveio/actions/workflows/R-CMD-check.yaml)|File system support|
|[filearray](https://github.com/dipterix/filearray)|![r-universe](https://beauchamplab.r-universe.dev/badges/filearray)|[![R-check](https://github.com/dipterix/filearray/workflows/R-CMD-check/badge.svg)](https://github.com/dipterix/filearray/actions)|Out-of-memory solution|
|[threeBrain](https://github.com/dipterix/threeBrain)|![r-universe](https://beauchamplab.r-universe.dev/badges/threeBrain)|[![R-CMD-check](https://github.com/dipterix/threeBrain/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/dipterix/threeBrain/actions/workflows/R-CMD-check.yaml)|3D viewer engine|
|[rpymat](https://github.com/dipterix/rpymat)|![r-universe](https://beauchamplab.r-universe.dev/badges/rpymat)|[![R-CMD-check](https://github.com/dipterix/rpymat/workflows/R-CMD-check/badge.svg)](https://github.com/dipterix/rpymat/actions)|Python manager & interface|
|[dipsaus](https://github.com/dipterix/dipsaus)|![r-universe](https://beauchamplab.r-universe.dev/badges/dipsaus)|[![R-CMD-check](https://github.com/dipterix/dipsaus/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/dipterix/dipsaus/actions/workflows/R-CMD-check.yaml)|Utility functions|


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

