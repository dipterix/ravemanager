#' Get system requirements for 'RAVE'
#' @param os,os_release operating system and release version, see \url{https://github.com/rstudio/r-system-requirements#operating-systems}
#' @param curl the location of the curl binary on your system
#' @param ... reserved for future use
#' @examples
#'
#'
#'
#' # Please check your operating system & version!!!
#'
#' # =============== On Ubuntu Linux ===============
#'
#' # Ubuntu 20
#' ravemanager::system_requirements("ubuntu", "20")
#'
#' # Ubuntu 18
#' ravemanager::system_requirements("ubuntu", "18")
#'
#' # Ubuntu 16
#' ravemanager::system_requirements("ubuntu", "16")
#'
#' # =============== On Red Hat Enterprise Linux ===============
#'
#' # Red Hat Enterprise Linux 8
#' ravemanager::system_requirements("redhat", "8")
#'
#' # Red Hat Enterprise Linux 7
#' ravemanager::system_requirements("redhat", "7")
#'
#' # =============== On CentOS ===============
#'
#' # Red Hat Enterprise Linux 8
#' ravemanager::system_requirements("centos", "8")
#'
#' # Red Hat Enterprise Linux 7
#' ravemanager::system_requirements("centos", "7")
#'
#' # =============== On OpenSUSE ===============
#'
#' # openSUSE 42.3
#' ravemanager::system_requirements("opensuse", "42")
#'
#' # =============== On SUSE Linux Enterprise ===============
#'
#' # SUSE Linux Enterprise 12.3
#' ravemanager::system_requirements("sle", "12")
#'
#'
#'
#' @export
system_requirements <- function(os, os_release = NULL, curl = Sys.which("curl"), ...) {
  if(!is_installed("remotes")) {
    install_packages("remotes")
  }
  if(missing(os)) {
    stop(sprintf("Please specify your operating system. See Examples in %s", sQuote("?ravemanager::system_requirements")))
  }
  remotes <- asNamespace("remotes")
  res <- remotes$system_requirements(
    os = os, os_release = os_release,
    path = system.file("apps/raveplaceholder", package = "ravemanager"),
    curl = curl
  )

  attr(res, "caveats") <- sprintf("Please consider the following system libraries under %s", paste(c(os, os_release), collapse = "-"))
  class(res) <- c("ravemanager_cmd", "ravemanager_printable", "character")
  res
}

#' @export
print.ravemanager_cmd <- function(x, ...) {
  caveats <- attr(x, "caveats")
  if(!is.null(caveats)) {
    message("# ", caveats, "\n")
  } else {
    message("# Please run the following system command in terminals\n")
  }

  NextMethod("print")
}


#' @export
print.ravemanager_printable <- function(x, ...) {
  cat(x, sep = "\n")
}
