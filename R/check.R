
is_installed <- function(pkg) {
  re <- system.file(package = pkg) != ""
  if(length(re) > 1) { return (re[[1]]) }
  return(isTRUE(re))
}

#' Print out 'RAVE' version information
#' @param nightly whether to check 'nightly' build which contains the newest
#' experimental features. However, 'nightly' builds are not stable. This
#' option is only recommended for zero-day bug fixes.
#' @param vanilla whether to use vanilla packages in this function
#' @export
version_info <- function(nightly = FALSE, vanilla = FALSE) {
  if( nightly ) {
    options("ravemanager.nightly" = TRUE)
  } else {
    options("ravemanager.nightly" = FALSE)
  }

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
  core_needsUpdate <- any(unlist(lapply(vinfos[-1], '[', "needsUpdate")))

  tryCatch({
    if(vanilla || system.file(package = "cli") == "") {
      stop()
    }
    cli <- asNamespace("cli")
    cli$cli_h1("RAVE core package information:")
    invisible(lapply(vinfos, function(info) {
      if(info$needsUpdate) {
        # cli$cli_bullets(c("!" = info$message))
        cli$cat_bullet(info$message, bullet = "warning", bullet_col = "orange", col = "orange")
      } else {
        cli$cat_bullet(info$message, bullet = "tick", bullet_col = "green", col = "gray")
        # cli$cli_bullets(c("v" = info$message))
      }
    }))
    cat("\n")
    if(!isFALSE(ravemanager_needsUpdate) || core_needsUpdate) {
      cli$cli_alert("One or more package needs update! (see the following instructions)")
      # cli$cli_h1("Update instruction:")

      step <- 1L
      if( !isFALSE(ravemanager_needsUpdate) ) {
        cli$cli_h1(c("Step {step}: update [ravemanager]: (copy, paste, and run)"))
        cat("\n")
        cat(cli$col_cyan(sprintf('install.packages(
  "ravemanager", repos = "https://rave-ieeg.r-universe.dev",
  lib = "%s")', get_libpaths(first = TRUE, check = TRUE))), "\n")

        # cat(cli$col_cyan('install.packages("ravemanager", repos = "https://rave-ieeg.r-universe.dev", lib = Sys.getenv("RAVE_LIB_PATH", unset = Sys.getenv("R_LIBS_USER", unset = .libPaths()[[1]])))'), "\n")
        cat("\n")
        cli$cli_bullets(c("i" = "Make sure you restart R after this step."))
        step <- step + 1L
      }

      if( core_needsUpdate ) {
        cli$cli_h1(c("Step {step}: update core dependencies:"))

        cli$cli_bullets(c("i" = "Make sure you close All other R instances (especially on Windows) before running the following command:"))
        cat("\n")

        # message('    lib_path <- Sys.getenv("RAVE_LIB_PATH", unset = Sys.getenv("R_LIBS_USER", unset = .libPaths()[[1]]))')
        # message('    loadNamespace("ravemanager", lib.loc = lib_path)')
        cli$cli_text(cli$col_cyan(sprintf('loadNamespace("ravemanager", lib.loc = "%s")', get_libpaths(first = TRUE, check = TRUE))))
        if( nightly ) {
          cli$cli_text(cli$col_cyan('ravemanager::update_rave(nightly = TRUE)'))
        } else {
          cli$cli_text(cli$col_cyan('ravemanager::update_rave()'))
        }
        cat("\n")
      }

    } else {
      cli$cli_bullets(c("v" = "Everything is up to date"))
    }
  }, error = function(e) {
    packageStartupMessage(
      "RAVE core package information: \n",
      paste(unlist(lapply(vinfos, "[", "message")), collapse = "\n"), "\n",
      paste(rep("-", mnchars + 14), collapse = ""), "",
      ifelse(
        isFALSE(ravemanager_needsUpdate), "",
        paste(
          "\n* Please update [ravemanager] using\n",
          '    lib_path <- Sys.getenv("RAVE_LIB_PATH", unset = Sys.getenv("R_LIBS_USER", unset = .libPaths()[[1]]))',
          '    install.packages("ravemanager", repos = "https://rave-ieeg.r-universe.dev", lib = lib_path)',
          '\nMake sure you restart R after this step.',
          paste(rep("-", mnchars + 14), collapse = ""),
          sep = "\n"
        )
      ),
      ifelse(
        core_needsUpdate,
        paste(
          "\n* Please update core dependencies using\n",
          '    lib_path <- Sys.getenv("RAVE_LIB_PATH", unset = Sys.getenv("R_LIBS_USER", unset = .libPaths()[[1]]))',
          '    loadNamespace("ravemanager", lib.loc = lib_path)',
          ifelse(
            nightly,
            '    ravemanager::update_rave(nightly = TRUE)',
            '    ravemanager::update_rave()'
          ),
          sep = "\n"
        ),
        ifelse(
          ravemanager_needsUpdate, "", "\n* Everything is up to date"
        )
      )

    )
  })

  invisible()
}


