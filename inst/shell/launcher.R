#!/usr/bin/env Rscript

doc <- 'RAVE command-line interface

Usage:
  rave start [--port=<n>] [--host=<addr>] [--no-browser] [--new-session]
  rave (-h | --help)
  rave --version

Options:
  -h --help       Show this screen.
  --version       Show version.
  --port=<n>      Port number (1024-65535) [default: 8788].
  --host=<addr>   Host address [default: 0.0.0.0].
  --no-browser    Do not launch browser [default: TRUE]
  --new-session   Start a brand new session [default: FALSE]
'

version <- sprintf("RAVE 2.0 (manager=v%s)", as.character(packageVersion("ravemanager")))
opts <- docopt::docopt(doc, version = version)

if (isTRUE(opts$start)) {
  port <- as.integer(opts$port)
  if(is.na(port) && port < 1024 || port > 65535) {
    stop("Invalid port number: port must be an integer between 1024-65535")
  }
  host <- opts$host
  launch_browser <- !isTRUE(opts$no_browser)
  if(isTRUE(opts$new_session)) {
    new_session <- TRUE
  } else {
    new_session <- NA
  }
  app <- rave::start_rave(
    host = host,
    port = port,
    launch.browser = launch_browser,
    new = new_session,
    as_job = FALSE
  )
  print(app)
}

