
rave_depends <- c(
  "ravetools", "filearray", "shidashi", "rpymat",
  "dipsaus", "threeBrain", "raveio", "ravedash")

rave_packages <- c("rutabaga", "ravebuiltins")

needs_compilation <- c(
  "anytime", "askpass", "backports", "base64enc", "base64url",
  "bit", "bit64", "bitops", "brio", "cachem", "circular", "cli",
  "colorspace", "commonmark", "curl", "data.table", "diffobj",
  "digest", "dipsaus", "dplyr", "ellipsis", "fansi", "farver",
  "fastmap", "fftwtools", "filearray", "foreign", "fs", "fst",
  "fstcore", "gert", "glue", "hdf5r", "htmltools", "httpuv", "igraph",
  "isoband", "jsonlite", "later", "lattice", "lazyeval", "lme4",
  "magrittr", "maptools", "MASS", "Matrix", "mgcv", "mime", "minqa",
  "mvtnorm", "nlme", "nloptr", "nnet", "openssl", "pbdZMQ", "plyr",
  "png", "processx", "profvis", "promises", "ps", "purrr", "quantreg",
  "ragg", "rappdirs", "ravetools", "Rcpp", "RcppEigen", "RcppParallel",
  "RcppTOML", "reshape2", "reticulate", "rlang", "RNifti", "roxygen2",
  "sass", "signal", "sourcetools", "sp", "SparseM", "stringi",
  "survival", "sys", "systemfonts", "testthat", "textshaping",
  "tibble", "tidyr", "tidyselect", "utf8", "uuid", "vctrs", "waveslim",
  "xfun", "xml2", "yaml", "zip")

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
      dipterix = 'https://dipterix.r-universe.dev'
    )
  } else {
    mirrors <- c(
      beauchamplab = 'https://beauchamplab.r-universe.dev'
    )
  }

  os_type <- get_os()

  switch(
    os_type,
    "windows" = {
      mirrors[["RSPM"]] <- "https://packagemanager.rstudio.com/cran/latest"
    },
    "linux" = {
      lsb <- getOption("ravemanager.os.release", default = NULL)
      lsb <- lsb[lsb %in% c("opensuse153", "centos7", "centos8", "bionic", "focal", "jammy")]
      if(!length(lsb)) {
        info <- utils::sessionInfo()
        if(grepl("Ubuntu 22", info$running)) {
          lsb <- "jammy"
        } else if(grepl("Ubuntu 20", info$running)) {
          lsb <- "focal"
        } else if(grepl("Ubuntu 18", info$running)) {
          lsb <- "bionic"
        } else {
          # TODO: add more
        }
      }
      if(length(lsb)) {
        mirrors[["RSPM"]] <- sprintf("https://packagemanager.rstudio.com/cran/__linux__/%s/latest", lsb[[1]])
      }
    }
  )
  mirrors[["CRAN"]] <- 'https://cloud.r-project.org'
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
