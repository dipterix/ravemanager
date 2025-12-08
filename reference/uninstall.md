# Uninstall RAVE components

Remove cache, python, and/or all settings. Please be aware that R,
'RStudio', and already installed R packages will not be uninstalled.
Please carefully read printed messages.

## Usage

``` r
uninstall(components = c("cache", "python", "all"))
```

## Arguments

- components:

  which component to remove, see example for choices.

## Examples

``` r
if( FALSE ) {

  # remove cache only
  ravemanager::uninstall("cache")

  # remove python environment
  ravemanager::uninstall("python")

  # remove all sample data, settings files
  ravemanager::uninstall("all")

}

```
