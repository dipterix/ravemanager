# Install/Update R or Python packages to RAVE environment

Install/Update R or Python packages to RAVE environment

## Usage

``` r
add_r_package(
  pkg,
  lib = get_libpaths(check = TRUE),
  repos = get_mirror(),
  type = getOption("pkgType"),
  ...,
  INSTALL_opts = "--no-lock"
)

add_py_package(pkg, method = c("pip", "conda"))
```

## Arguments

- pkg:

  name of the package

- repos, lib, type, INSTALL_opts, ...:

  internally used

- method:

  whether to use `'pip'` or `'conda'`; default is `'pip'`

## Value

Nothing

## Examples

``` r
if (FALSE) { # \dontrun{


# ---- R --------------------------------------------------------
# Install R packages (CRAN, BioC, or RAVE's repository)
add_r_package("ravebuiltins")
add_r_package("rhdf5")

# Install from Github (github.com/dipterix/threeBrain)
add_r_package("dipterix/threeBrain")

# Install Github branch
add_r_package("dipterix/threeBrain@custom-electrode-geom")

# ---- Python ----------------------------------------------------

# Normal pypi packages
add_py_package("threebrainpy")

# Add through conda
add_py_package("fftw", method = "conda")


} # }

```
