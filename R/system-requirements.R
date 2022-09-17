system_requirements_ubuntu <- function(packages, release = "22.04") {

  if(missing(packages)) {
    packages <- unique(c(rave_depends, rspm_install))
  }


  url <- sprintf(
    "http://packagemanager.rstudio.com/__api__/repos/1/sysreqs?all=false&%s&distribution=ubuntu&release=%s",
    paste(sprintf("pkgname=%s", packages), collapse = "&"),
    release
  )
  suppressWarnings({
    reqs <- readLines(url)
  })

  cmd <- trimws(strsplit(reqs, '"')[[1]])
  cmd <- cmd[grepl("^apt-get", cmd)]
  cmd <- unique(cmd)

  cmd <- gsub("^apt(-get|) install (|-y )", "", cmd)
  cmd <- unique(c(
    "git", "apt-file", "build-essential", cmd
  ))
  cmd <- sort(cmd)

  structure(
    sprintf("sudo apt-get --no-install-recommends install %s", paste(cmd, collapse = " ")),
    class = c("ravemanager_cmd", "ravemanager_printable", "character")
  )
}

#' @export
print.ravemanager_cmd <- function(x, ...) {
  cat("Please run the following system command in terminals\n\n  ")
  NextMethod("print")
}


#' @export
print.ravemanager_printable <- function(x, ...) {
  cat(x, "\n", sep = "")
}
