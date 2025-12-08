# Run tutorials

Run tutorials

## Usage

``` r
run_tutorials(topic = NULL, ...)
```

## Arguments

- topic:

  integers of which topic to launch, leave it blank, then 'RAVE' will
  ask you to select a topic

- ...:

  other parameters to pass to
  [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html)

## Examples

``` r
if (FALSE) { # \dontrun{

ravemanager::run_tutorials()

} # }
```
