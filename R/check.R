
is_installed <- function(pkg) {
  system.file(package = pkg) != ""
}

#' Print out 'RAVE' version information
#' @export
version_info <- function() {
  versions <- new.env()
  versions$ravemanager <- list(
    current = ravemanager_version()
  )
  tryCatch({
    versions$ravemanager$latest <- ravemanager_latest_version()
  }, error = function(e) {
    versions$ravemanager$latest <- NA
  })

  core_packages <- c("rave", rave_depends, rave_packages)
  for(pkg in core_packages) {
    versions[[pkg]] <- list(
      current = as.character(package_current_version(pkg))
    )
    tryCatch({
      versions[[pkg]]$latest <- as.character(package_latest_version(pkg))
    }, error = function(e) {
      versions[[pkg]]$latest <- NA
    })
  }
  core_packages <- c("ravemanager", core_packages)
  mnchars <- max(nchar(core_packages)) + 4
  vinfos <- lapply(core_packages, function(pkg) {

    versions[[pkg]]$needsUpdate <- FALSE
    vinfo <- sprintf("  %s: %s%s", pkg,
                     paste(rep(" ", mnchars - nchar(pkg)), collapse = ""),
                     versions[[pkg]]$current)
    if( utils::compareVersion(versions[[pkg]]$current, versions[[pkg]]$latest) < 0 ) {
      vinfo <- sprintf("%s [Latest update: %s]", vinfo, versions[[pkg]]$latest)
      versions[[pkg]]$needsUpdate <- TRUE
    }
    versions[[pkg]]$message <- vinfo
    versions[[pkg]]
  })
  names(vinfos) <- core_packages

  ravemanager_needsUpdate <- vinfos$ravemanager$needsUpdate
  packageStartupMessage(
    "RAVE core package information: \n",
    paste(unlist(lapply(vinfos, "[", "message")), collapse = "\n"), "\n",
    paste(rep("-", mnchars + 14), collapse = ""), "",
    ifelse(
      isFALSE(ravemanager_needsUpdate), "",
      paste(
        "\n*. Please update [ravemanager] using\n",
        '    lib_path <- Sys.getenv("RAVE_LIB_PATH", unset = Sys.getenv("R_LIBS_USER", unset = .libPaths()[[1]]))',
        '    install.packages("ravemanager", repos = "https://beauchamplab.r-universe.dev", lib = lib_path)',
        '\nMake sure you restart R after this step.',
        paste(rep("-", mnchars + 14), collapse = ""),
        sep = "\n"
      )
    ),
    ifelse(
      any(unlist(lapply(vinfos[-1], '[', "needsUpdate"))),
      paste(
        "\n*. Please update core dependencies using\n",
        '    lib_path <- Sys.getenv("RAVE_LIB_PATH", unset = Sys.getenv("R_LIBS_USER", unset = .libPaths()[[1]]))',
        '    loadNamespace("ravemanager", lib.loc = lib_path)',
        '    ravemanager::update_rave()',
        sep = "\n"
      ),
      ""
    )

  )
}


