
package_latest_version <- function(pkg, url = NULL) {
  if( length(url) != 1 ) {
    if(getOption("ravemanager.nightly", FALSE)) {
      url <- "https://dipterix.r-universe.dev/packages"
    } else {
      url <- "https://beauchamplab.r-universe.dev/packages"
    }
  }

  if(length(pkg) != 1) {
    stop("package_needs_update: `pkg` must be length of 1")
  }

  # get r-universe
  available_version <- tryCatch({
    suppressWarnings({
      pkg_url <- gsub("[/]+$", '', url)
      pkg_url <- paste0(pkg_url, "/", pkg)
      versions <- readLines(pkg_url)
      versions <- versions[grepl('^[ ]{0, }"Version":[ ]{0,}"[0-9\\.]+"[, ]{0,}$', versions)]
      versions <- gsub("[^0-9\\.]", "", versions)
      max_ver <- versions[[1]]
      for(v in versions) {
        if( utils::compareVersion(max_ver, v) < 0 ) {
          max_ver <- v
        }
      }
      package_version(max_ver)
    })
  }, error = function(e) {
    NULL
  })

  if(is.null(available_version)) {
    return(NA)
  }
  return(available_version)
}

package_current_version <- function(pkg, lib = NULL) {
  if(!pkg %in% loadedNamespaces() && is.null(lib)) {
    lib <- get_libpaths(first = FALSE)
  }
  current_version <- tryCatch({
    utils::packageVersion(pkg, lib.loc = lib)
  }, error = function(e) {
    NULL
  })

  if(is.null(current_version)) { return(NA) }
  return( current_version )
}

package_needs_update <- function(pkg, lib = NULL, url = NULL) {
  if( length(url) != 1 ) {
    if(getOption("ravemanager.nightly", FALSE)) {
      url <- "https://dipterix.r-universe.dev/packages"
    } else {
      url <- "https://beauchamplab.r-universe.dev/packages"
    }
  }

  if(length(pkg) != 1) {
    stop("package_needs_update: `pkg` must be length of 1")
  }
  if(!pkg %in% loadedNamespaces() && is.null(lib)) {
    lib <- get_libpaths(first = FALSE)
  }
  current_version <- tryCatch({
    utils::packageVersion(pkg, lib.loc = lib)
  }, error = function(e) {
    NULL
  })

  if(is.null(current_version)) { return(TRUE) }

  # get r-universe
  available_version <- tryCatch({
    suppressWarnings({
      pkg_url <- gsub("[/]+$", '', url)
      pkg_url <- paste0(pkg_url, "/", pkg)
      versions <- readLines(pkg_url)
      versions <- versions[grepl('^[ ]{0, }"Version":[ ]{0,}"[0-9\\.]+"[, ]{0,}$', versions)]
      versions <- gsub("[^0-9\\.]", "", versions)
      max_ver <- versions[[1]]
      for(v in versions) {
        if( utils::compareVersion(max_ver, v) < 0 ) {
          max_ver <- v
        }
      }
      package_version(max_ver)
    })
  }, error = function(e) {
    NULL
  })

  if(is.null(available_version)) {
    return(NA)
  }

  needs_update <- NA
  try({
    needs_update <- isTRUE(utils::compareVersion(as.character(available_version), as.character(current_version)) > 0)
  })

  needs_update
}

ravemanager_latest_version <- function() {

  tryCatch({
    descr <- readLines("https://raw.githubusercontent.com/dipterix/ravemanager/main/DESCRIPTION")
    dev_descr <- read.dcf(textConnection(descr))
    dev_descr <- structure(as.list(dev_descr), names = colnames(dev_descr))
    versions <- dev_descr$Version
    versions
  }, error = function(e) {
    tryCatch({
      suppressWarnings({
        versions <- readLines("https://beauchamplab.r-universe.dev/packages/ravemanager")
        versions <- versions[grepl('^[ ]{0, }"Version":[ ]{0,}"[0-9\\.]+"[, ]{0,}$', versions)]
        versions <- gsub("[^0-9\\.]", "", versions)
        return(versions[[1]])
      })
    }, error = function(e){
      NULL
    })
  })

}

#' @title Get current 'RAVE' installer's version
#' @return Returns the \code{ravemanager} version
#' @export
ravemanager_version <- function() {
  desc <- utils::packageDescription("ravemanager")
  desc$Version
}


get_latest_R_version <- function(url = "https://cran.rstudio.com/bin/windows/base/", pat = "R-[0-9.]+.+-win\\.exe") {
  page <- readLines(url, warn = FALSE)

  res <- gregexpr(pat, text = page)
  sel <- which(vapply(res, function(item) {
    isTRUE(any(!is.na(item) & item >= 0))
  }, FALSE))[[1]]

  res <- res[[sel]]
  target_line <- page[sel]

  mlen <- attr(res, "match.length")[[1]]
  filename <- substr(target_line, res[[1]], res[[1]] + mlen - 1)

  res <- gregexpr("[0-9.]+", text = filename)[[1]]
  mlen <- attr(res, "match.length")[[1]]
  latest_R_version <- substr(filename, res[[1]], res[[1]] + mlen - 1)

  pat <- "Last change: [0-9.]+-[0-9.]+-[0-9.]+"
  target_line <- grep(pat, page, value = TRUE)

  m <- regexpr(pat, target_line)
  latest_R_date <- regmatches(target_line, m)
  latest_R_date <- gsub(pattern = "Last change: ", "", latest_R_date)

  current_R_version <- as.character(getRversion())
  there_is_a_newer_version <- utils::compareVersion(current_R_version, latest_R_version) == -1

  if( there_is_a_newer_version ) {
    message_text <- paste(
      "There is a newer version of R for you to download!\n\n",
      "You are using R version:    \t", gsub("R version", "", R.version$version.string), "\n",
      "And the latest R version is:\t ", latest_R_version, " (", latest_R_date, ")", "\n",
      sep = ""
    )
  } else {
    message_text <- NULL
  }

  list(
    has_new_version = there_is_a_newer_version,
    latest_R_version = latest_R_version,
    latest_R_date = latest_R_date,
    current_R_version = current_R_version,
    message_text = message_text
  )


}
