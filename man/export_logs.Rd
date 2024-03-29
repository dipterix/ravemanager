% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/report.R
\name{export_logs}
\alias{export_logs}
\title{Print out 'RAVE' session log}
\usage{
export_logs(
  session = NULL,
  modules = NULL,
  max_lines = Sys.getenv("RAVEMANAGER_BUGREPORT_MAX", "200"),
  verbose = TRUE
)
}
\arguments{
\item{session}{'RAVE' session string; default is the most recent (active)
session}

\item{modules}{which module to read; default is all}

\item{max_lines}{maximum number of lines to read; default is 200}

\item{verbose}{whether to print out the log; default is true}
}
\value{
characters of log
}
\description{
Print out 'RAVE' session log
}
