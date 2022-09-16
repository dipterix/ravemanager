
rave_depends <- c(
  "ravetools", "filearray", "shidashi", "rpymat",
  "dipsaus", "threeBrain", "raveio", "ravedash")

rave_packages <- c("rutabaga", "ravebuiltins")

get_os <- function () {
  if ("windows" %in% tolower(.Platform$OS.type)) {
    return("windows")
  }
  os <- tolower(R.version$os)
  if (startsWith(os, "darwin")) {
    return("darwin")
  }
  if (startsWith(os, "linux")) {
    return("linux")
  }
  if (startsWith(os, "solaris")) {
    return("solaris")
  }
  if (startsWith(os, "win")) {
    return("windows")
  }
  return("unknown")
}

get_arch <- function() {
  if(grepl("arch64", R.version$arch)) {
    return("aarch64")
  } else {
    return("x64")
  }
}


get_mirror <- function(nightly = TRUE) {
  if(nightly) {
    mirrors <- c(
      beauchamplab = 'https://beauchamplab.r-universe.dev',
      dipterix = 'https://dipterix.r-universe.dev',
      CRAN = 'https://cloud.r-project.org'
    )
  } else {
    mirrors <- c(
      beauchamplab = 'https://beauchamplab.r-universe.dev',
      CRAN = 'https://cloud.r-project.org'
    )
  }

  mirrors
}

dir_create2 <- function (x, showWarnings = FALSE, recursive = TRUE, check = TRUE, ...) {
  if (!dir.exists(x)) {
    dir.create(x, showWarnings = showWarnings, recursive = recursive, ...)
  }
  if (check && !dir.exists(x)) {
    stop("Cannot create directory at ", shQuote(x))
  }
  invisible(normalizePath(x))
}
