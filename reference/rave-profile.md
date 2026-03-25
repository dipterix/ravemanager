# Make a profile allowing portable `RAVE` configurations

Make a profile allowing portable `RAVE` configurations

## Usage

``` r
make_profile(profile = shared_profile(), profile_name = "default")

use_profile(profile_name = "default", auto_install = TRUE)
```

## Arguments

- profile:

  profile configurations

- profile_name:

  name of the profile

- auto_install:

  whether to automatically install RAVE with the profile; default is
  `TRUE`

## Examples

``` r
if (FALSE) { # \dontrun{

# Make a template profile first. You may edit this profile
# to redirect paths to shared drive, SSD etc.
# Make sure you have the write permissions

make_profile()

# Test and install the profile
use_profile()

# Edit in your .Rprofile via `usethis::edit_r_profile()`
# add this line
ravemanager::use_profile(auto_install = FALSE)

} # }
```
