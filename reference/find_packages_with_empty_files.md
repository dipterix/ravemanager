# Find packages with empty files

Check whether packages are installed correctly. In rare cases (possibly
network issues), packages downloaded contain empty files. This function
provides a method to check empty files in packages.

## Usage

``` r
find_packages_with_empty_files(lib = get_libpaths(check = TRUE))
```

## Arguments

- lib:

  library path where packages are installed; default is set to user
  library path.

## Value

A list of packages (and files) containing empty files.

## Examples

``` r

find_packages_with_empty_files()
#> The following packages have empty files: 
#> rpyANTs         - [2%] 1 empty of 45 files
#> ravecore        - [2%] 1 empty of 48 files
#> reticulate      - [2%] 1 empty of 62 files
#> rave            - [1%] 1 empty of 76 files
#> renv            - [1%] 1 empty of 77 files
#> pkgdown         - [1%] 2 empty of 165 files
#> plotly          - [0%] 1 empty of 211 files
#> Rcpp            - [0%] 1 empty of 638 files
#> 
#> If you suspect that any package was installed incorrectly, please use
#>  ravemanager::add_r_package('<pkg_name>')
#> to re-install.
```
