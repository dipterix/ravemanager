
rave_depends <- c(
  "bidsr",
  "dipsaus",
  "filearray",
  "ieegio",
  "ravedash",
  "raveio",
  "ravepipeline",
  "ravetools",
  "readNSx",
  "rpyANTs",
  "rpymat",
  "shidashi",
  "threeBrain"
)

rave_packages <- c("rutabaga", "ravebuiltins")

rave_suggests <- c( "SparseM", "Rvcg", "visNetwork", "clustermq", "quantreg", "mvtnorm", "nloptr", "minqa", "lme4", "circular", "learnr", "RcppEigen", "zoo", "lmtest" )

rspm_install <- c("abind", "anytime", "askpass", "assertthat", "backports", "base64enc", "base64url", "BH", "bit", "bit64", "bitops", "boot", "brew", "brio", "broom", "bslib", "cachem", "callr", "car", "carData", "circular", "cli", "clipr", "codetools", "colorspace", "commonmark", "cpp11", "crayon", "credentials", "crosstalk", "curl", "data.table", "desc", "devtools", "diffobj", "digest", "dipsaus", "downlit", "downloader", "dplyr", "DT", "edfReader", "ellipsis", "emmeans", "estimability", "evaluate", "fansi", "farver", "fastmap", "fftwtools", "filearray", "fontawesome", "foreign", "formatR", "freesurferformats", "fs", "fst", "fstcore", "future", "future.apply", "generics", "gert", "ggplot2", "gh", "gifti", "gitcreds", "globals", "glue", "gtable", "hdf5r", "here", "highr", "htmltools", "htmlwidgets", "httpuv", "httr", "igraph", "ini", "IRdisplay", "IRkernel", "isoband", "jquerylib", "jsonlite", "knitr", "labeling", "later", "lattice", "lazyeval", "lifecycle", "listenv", "lme4", "lmerTest", "logger", "magrittr", "maptools", "MASS", "Matrix", "MatrixModels", "memoise", "mgcv", "mime", "miniUI", "minqa", "munsell", "mvtnorm", "nlme", "nloptr", "nnet", "numDeriv", "openssl", "oro.nifti", "parallelly", "pbdZMQ", "pbkrtest", "pillar", "pkgbuild", "pkgconfig", "pkgdown", "pkgfilecache", "pkgload", "plyr", "png", "praise", "prettyunits", "processx", "profvis", "progressr", "promises", "ps", "purrr", "quantreg", "R.matlab", "R.methodsS3", "R.oo", "R.utils", "R6", "ragg", "rappdirs", "rave", "ravedash", "raveio", "ravetools", "rcmdcheck", "RColorBrewer", "Rcpp", "RcppEigen", "RcppParallel", "RcppTOML", "rematch2", "remotes", "repr", "reshape2", "reticulate", "rlang", "rmarkdown", "RNifti", "roxygen2", "rprojroot", "rpymat", "rstudioapi", "rutabaga", "rversions", "sass", "scales", "sessioninfo", "shidashi", "shiny", "shinydashboard", "shinyFiles", "shinyjs", "shinyvalidate", "shinyWidgets", "signal", "sourcetools", "sp", "SparseM", "startup", "stringi", "stringr", "survival", "sys", "systemfonts", "targets", "testthat", "textshaping", "threeBrain", "tibble", "tidyr", "tidyselect", "tinytex", "urlchecker", "usethis", "utf8", "uuid", "vctrs", "viridisLite", "waldo", "waveslim", "whisker", "withr", "xfun", "xml2", "xopen", "xtable", "yaml", "zip", "Rvcg", "readNSx", "RcppEigen")

rspm_install_compile <- ""

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
    return("x86")
  }
}


get_mirror <- function(nightly = FALSE) {

  if(nightly) {
    mirrors <- c(
      raveieeg = 'https://rave-ieeg.r-universe.dev',
      dipterix = 'https://dipterix.r-universe.dev'
    )
  } else {
    mirrors <- c(
      raveieeg = 'https://rave-ieeg.r-universe.dev'
    )
  }

  os_type <- get_os()

  switch(
    os_type,
    "windows" = {
      mirrors[["RSPM"]] <- "https://packagemanager.posit.co/cran/latest"
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
        mirrors[["RSPM"]] <- sprintf("https://packagemanager.posit.co/cran/__linux__/%s/latest", lsb[[1]])
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

detect_gh_ci <- function() {
  if(isTRUE(toupper(as.character(Sys.getenv("TEST_INSTALLATION"))) %in% c("TRUE", "YES"))) {
    return(TRUE)
  }
  return(FALSE)
}
