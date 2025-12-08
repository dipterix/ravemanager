# Print out 'RAVE' session log

Print out 'RAVE' session log

## Usage

``` r
export_logs(
  session = NULL,
  modules = NULL,
  max_lines = Sys.getenv("RAVEMANAGER_BUGREPORT_MAX", "200"),
  verbose = TRUE
)
```

## Arguments

- session:

  'RAVE' session string; default is the most recent (active) session

- modules:

  which module to read; default is all

- max_lines:

  maximum number of lines to read; default is 200

- verbose:

  whether to print out the log; default is true

## Value

characters of log
