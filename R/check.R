
is_installed <- function(pkg) {
  re <- system.file(package = pkg) != ""
  if(length(re) > 1) { return (re[[1]]) }
  return(isTRUE(re))
}

#' Print out 'RAVE' version information
#' @param vanilla whether to use vanilla packages in this function
#' @param auto_restart whether to automatically install \code{ravemanager}
#' if an update is available and apply restart; default is true on non-Windows
#' machine
#' @param ... reserved for future use
#' @export
version_info <- function(vanilla = FALSE, auto_restart = !get_os() %in% "windows", ...) {
  options("ravemanager.nightly" = FALSE)

  if( Sys.getenv("RAVEMANAGER_SUPPRESS_AUTO_RESTART", "") != "" ) {
    auto_restart <- FALSE
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

  if( auto_restart && ravemanager_needsUpdate && is_installed("rstudioapi") ) {
    rstudioapi <- asNamespace('rstudioapi')
    if( rstudioapi$isAvailable(version_needed = "1.4") ) {
      # restart RStudio!
      try({
        message("Trying to update `ravemanager`: restarting RStudio...")
        Sys.setenv("RAVEMANAGER_SUPPRESS_AUTO_RESTART" = "TRUE")
        rstudioapi$restartSession(
          clean = TRUE,
          command = sprintf('{
  install.packages("ravemanager", repos = "https://rave-ieeg.r-universe.dev", lib = "%s")
  message("Wait a second...")
  ravemanager::version_info()
}', get_libpaths(first = TRUE, check = TRUE))
        )
      }, silent = TRUE)
      return(invisible())
    }
  }

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
        cli$cli_bullets(c("i" = "Make sure you restart R and run `{.run ravemanager::version_info()}` again after this step."))
        step <- step + 1L
      }

      if( core_needsUpdate ) {
        cli$cli_h1(c("Step {step}: update core dependencies:"))

        cli$cli_bullets(c("i" = "Make sure you close All other R instances (especially on Windows) before running the following command:"))
        cat("\n")

        # message('    lib_path <- Sys.getenv("RAVE_LIB_PATH", unset = Sys.getenv("R_LIBS_USER", unset = .libPaths()[[1]]))')
        # message('    loadNamespace("ravemanager", lib.loc = lib_path)')
        cli$cli_text(cli$col_cyan(sprintf('loadNamespace("ravemanager", lib.loc = "%s")', get_libpaths(first = TRUE, check = TRUE))))
        if( isFALSE(ravemanager_needsUpdate) ) {
          cli$cli_text(cli$col_cyan('{.run ravemanager::update_rave()}'))
        } else {
          cli$cli_text(cli$col_cyan('ravemanager::update_rave(allow_cache = FALSE)'))
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
          '\nMake sure you restart R and run `ravemanager::version_info()` after this step.',
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
            isFALSE(ravemanager_needsUpdate),
            '    ravemanager::update_rave()',
            '    ravemanager::update_rave(allow_cache = FALSE)'
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


