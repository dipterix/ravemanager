#' @name RAVE-install
#' @title Install or upgrade 'RAVE'
#' @description Installs the newest version of 'RAVE' and its dependence
#' packages; executes the scripts to finalize installation to update
#' configuration files.
#' @param nightly whether to install the nightly build
#' @param upgrade_manager whether to upgrade the installer (\code{ravemanager})
#' before updating other packages
#' @param force whether to force updating packages even the installed have
#' the latest versions
#' @param finalize whether to run finalizing installation scripts
#' @param packages packages to run finalizing installation scripts
#' @param upgrade upgrade type
#' @param async whether to execute finalizing installation scripts in other
#' processes
#' @param ... passed to internal functions, useful arguments include
#' \code{use_rspm} to whether use \code{'RSPM'} on \code{'Ubuntu'} (enabled by default)
#' @return Nothing
NULL


#' @rdname RAVE-install
#' @export
add_shortcuts <- function() {
  os <- get_os()
  switch(
    os,
    "darwin" = {
      app <- system.file("shell/rave-2.0.app", package = "ravemanager")
      dir.create("/Applications/RAVE/", showWarnings = FALSE, recursive = TRUE)
      if(dir.exists("/Applications/RAVE/rave-2.0.app")) {
        unlink("/Applications/RAVE/rave-2.0.app", recursive = TRUE)
      }
      file.copy(app, "/Applications/RAVE/",
                overwrite = TRUE, copy.date = TRUE, recursive = TRUE)
      Sys.chmod("/Applications/RAVE/rave-2.0.app/Contents/MacOS/executable",
                mode = "0755", use_umask = FALSE)
      system("open /Applications/RAVE/")
    }
  )
}

upgrade_ravemanager <- function() {
  lib_path <- get_libpaths(first = TRUE, check = TRUE)
  unload_namespace("ravemanager")
  if(is_installed("remotes")) {

    # remove existing packages
    current_paths <- .libPaths()
    for(path in current_paths) {
      if(system.file(package = 'ravemanager', lib.loc = path) != "") {
        message("Removing ravemanager at: ", path)
        utils::remove.packages("ravemanager", lib = path)
      }
    }
    message("Upgrading ravemanager at: ", lib_path)

    tryCatch({
      remotes <- asNamespace("remotes")
      remotes$install_github("dipterix/ravemanager", quiet = TRUE, lib = lib_path)
    }, error = function(e) {

      utils::install.packages(
        pkgs = 'ravemanager',
        repos = 'https://beauchamplab.r-universe.dev',
        lib = lib_path)
    })
  }
}

clear_uninstalled <- function() {
  libs <- get_libpaths(first = FALSE)
  for(lib in libs) {
    if(dir.exists(lib)) {
      locked <- list.files(lib, all.files = FALSE, full.names = FALSE,
                       recursive = FALSE, pattern = "^00",
                       include.dirs = TRUE, no.. = FALSE)
      for(f in locked) {
        absf <- file.path(lib, f)
        if(dir.exists(absf)) {
          tryCatch({
            message(sprintf("Trying to unlock [%s] from previous installation", f))
            unlink(absf, recursive = TRUE, force = TRUE)
          }, error = function(e) {
            message(sprintf("Failed to remove [%s]", absf))
          })
        }
      }
    }
  }
}

install_packages <- function(pkgs, lib = get_libpaths(check = TRUE),
                             repos = get_mirror(), type = getOption("pkgType"),
                             ..., INSTALL_opts = '--no-lock', force = TRUE, verbose = TRUE) {

  if(!force) {
    pkgs <- pkgs[sapply(pkgs, function(pkg) {
      re <- isFALSE(package_needs_update(pkg, lib = lib))
      if(verbose && re) {
        if(identical(type, "binary")) {
          message(sprintf("Package [%s] (binary) is up-to-date. Skipping", pkg))
        } else if(identical(type, "source")) {
          message(sprintf("Package [%s] (source) is up-to-date. Skipping", pkg))
        } else {
          message(sprintf("Package [%s] is up-to-date. Skipping", pkg))
        }
      }
      !re
    })]
  }

  if(length(pkgs)) {
    utils::install.packages(pkgs, lib = lib, repos = repos, ..., INSTALL_opts = INSTALL_opts, type = type)
    # Set package installation date
    root_path <- file.path(tools::R_user_dir(package = "ravemanager", which = "config"), "last_updates")
    if(!dir.exists(root_path)) {
      dir.create(root_path, showWarnings = FALSE, recursive = TRUE)
    }
    now <- as.character(Sys.time())
    for(pkg in pkgs) {
      writeLines(text = now, con = file.path(root_path, pkg))
    }
    if(any(pkgs %in% c("rave", rave_depends, rave_packages))) {
      writeLines(text = now, con = file.path(root_path, "rave-family"))
    }
  }
}

#' @rdname RAVE-install
#' @export
finalize_installation <- function(
  packages = NULL,
  upgrade = c('config-only', 'ask', 'always', 'never', 'data-only'),
  async = FALSE, ...
) {
  upgrade <- match.arg(upgrade)

  # Get all packages with rave.yaml
  lib_path <- get_libpaths(first = FALSE)

  allpackages <- unlist(sapply(lib_path, function(lp){
    list.dirs(lp, recursive = FALSE, full.names = FALSE)
  }, simplify = FALSE))
  allpackages <- unique(allpackages)

  yaml_path <- sapply(allpackages, function(p){
    system.file('rave.yaml', package = p, lib.loc = lib_path)
  })

  sel <- yaml_path != ''

  if(length(packages)){
    sel <- sel & (allpackages %in% packages)
  }
  packages <- unique(allpackages[sel])

  lapply(packages, function(pkg) {
    tryCatch({

      # load yaml
      yaml_path <- system.file('rave.yaml', package = pkg, lib.loc = lib_path)
      s <- readLines(yaml_path)
      s <- s[grepl("^[ ]{0,}finalize_installation:", s)]
      if(!length(s)) {
        return()
      }
      s <- strsplit(s[[1]], ":")[[1]]
      s <- trimws(s[[2]])

      ensure_depends(pkg)

      suppressWarnings({
        ns <- asNamespace(pkg)
      })

      fun <- ns[[s]]
      if(!is.function(fun)) {
        return()
      }

      fml <- formals(fun)

      args <- list()

      opt <- c(upgrade, "config-only", "never", "always")
      opt <- opt[opt %in% eval(fml$upgrade)]
      if(length(opt)) {
        args$upgrade <- opt[[1]]
      }
      if("async" %in% names(fml)) {
        args$async <- async
      }

      message("Finalizing installation: ", pkg)
      do.call(fun, args)

      if(async) {
        message(sprintf(
          "[%s] Scheduled finalizing installation in the background.",
          pkg
        ))
      }

  }, error = function(e) {
    warning("Unable to finalize the installation of package ", shQuote(pkg),
            ". Skipping. Reason: \n", e$message)
    })

  })

  if(async) {
    message("Please wait until the background installations are finished.")
  } else {
    message("Done finalizing installations! Please close all your R/RStudio sessions and restart.")
  }
}

#' @rdname RAVE-install
#' @export
install <- function(nightly = TRUE, upgrade_manager = FALSE,
                    finalize = TRUE, force = FALSE, ...) {

  # check R version
  rversion <- R.Version()
  rversion <- sprintf("%s.%s", rversion$major, rversion$minor)
  if(utils::compareVersion(rversion, "4.0.0") < 1) {
    stop(sprintf("Your R version (%s) is too low. Please install the latest R on your machine\n  Please check https://cran.r-project.org/ for more information.", rversion))
  }

  # make sure RAVE is installed in path defined by `R_LIBS_USER` system env
  lib_path <- guess_libpath()

  if(length(lib_path)) {
    tryCatch(
      {
        dir_create2(lib_path)
      },
      error = function(e) { NULL },
      warning = function(e) { NULL }
    )
    if(!dir.exists(lib_path)) {
      lib_path <- NULL
    }
  }

  # Get os information
  os_type <- get_os()
  os_arch <- get_arch()

  # Get R version info
  if(os_type %in% c("windows", "darwin") && os_arch %in% c("x86")) {
    tryCatch({
      r_ver <- get_latest_R_version()
      latest_ver <- package_version(r_ver$latest_R_version)
      current_ver <- package_version(r_ver$current_R_version)

      if(identical(current_ver$major, latest_ver$major)) {
        if( latest_ver$minor - current_ver$minor <= 1 ) {

          options("ravemanager.binary_available" = TRUE)
        }
      }
    }, error = function(e){})
  }

  clear_uninstalled()

  # ravemanager upgrade
  if( upgrade_manager ) {
    if( os_type == "windows" ) {
      message("Cannot upgrade RAVE installer on Windows. Please the following command to upgrade ravemanager instead:\n  install.packages('ravemanager', repos = 'https://beauchamplab.r-universe.dev')")
      return(invisible())
    } else {
      needs_restart <- upgrade_installer()
      if(isTRUE(needs_restart)) {
        return(invisible())
      }
    }
  }
  ravemanager <- asNamespace("ravemanager")
  manager_version <- ravemanager$ravemanager_version()
  message("Current `ravemanager` version: ", manager_version)

  switch(
    os_type,
    "darwin" = {
      ravemanager$install_rave_osx(nightly = nightly, libpath = lib_path, force = force, ...)
    },
    "windows" = {
      ravemanager$install_rave_windows(nightly = nightly, libpath = lib_path, force = force, ...)
    },
    "linux" = {
      ravemanager$install_rave_linux(nightly = nightly, libpath = lib_path, force = force, ...)
    }
  )

  if(finalize) {
    message("Packages have been installed. Finalizing settings.")

    packages_to_install <- c(ravemanager$rave_depends, "rave",
                             ravemanager$rave_packages)

    ravemanager$finalize_installation(
      packages = packages_to_install,
      upgrade = 'config-only', async = FALSE)
  } else {
    message("Done installing/updating RAVE! Please close all your R/RStudio sessions and restart. If you want to update package add-ons, please run `ravemanager::finalize_installation()` after restart.")
  }


}

#' @rdname RAVE-install
#' @export
update <- install

#' @rdname RAVE-install
#' @export
upgrade_installer <- function() {
  v1 <- ravemanager_version()
  v2 <- ravemanager_latest_version()
  if(utils::compareVersion(v1, v2) < 0) {
    # Make sure ravemanager is the latest
    message("Upgrade ravemanager")

    tryCatch({
      upgrade_ravemanager()

      v1 <- package_version(v1)
      v2 <- package_version(v2)
      if(v1$major < v2$major) {
        message(sprintf(
          "[ravemanager] The installer's major version has been updated (from %s -> %s). \nPlease close all R & RStudio sessions, restart R, and run the following command again:\n\n\t\travemanager::install()",
          v1, v2
        ))
        return(invisible(TRUE))
      }
    }, error = function(e) {
      message("Failed to upgrade `ravemanager`: using current version")
    })

  } else {
    message("The installer has the latest version.")
  }
  return(invisible(FALSE))
}

install_rave_windows <- function(libpath, nightly = TRUE, force = FALSE, ...) {

  packages_to_install <- c(
    rave_depends, "rave", rave_packages
  )

  loaded <- packages_to_install[packages_to_install %in% loadedNamespaces()]

  if(length(loaded)) {

    for(nm in loaded) {
      try(
        expr = {
          unload_namespace(nm)
        },
        silent = TRUE
      )
    }
  }
  loaded <- packages_to_install[packages_to_install %in% loadedNamespaces()]
  if(length(loaded)) {
    stop("The following packages are found that cannot be unloaded. Please make sure you CLOSE ALL running R & RStudio before installing/upgrading RAVE. The packages unable to unload:\n  ", paste(shQuote(loaded), collapse = ", "))
  }

  repos <- get_mirror(nightly = nightly)

  # binary <- isTRUE(getOption("ravemanager.binary_available", FALSE))

  # type <- ifelse(binary, "binary", "source")

  if(missing(libpath) || !length(libpath)) {
    libpath <- NULL
  }

  # Fast install binary deps
  install_packages(
    packages_to_install, lib = libpath,
    repos = repos, type = "binary", force = force
  )

  # Make sure the source package is compiled and updated
  install_packages(
    packages_to_install, lib = libpath,
    repos = repos, type = "source", force = force
  )

}

install_rave_osx <- function(libpath, nightly = TRUE, force = FALSE, ...) {

  packages_to_install <- c(
    rave_depends, "rave", rave_packages
  )

  loaded <- packages_to_install[packages_to_install %in% loadedNamespaces()]

  if(length(loaded)) {

    for(nm in loaded) {
      try(
        expr = {
          unload_namespace(nm)
        },
        silent = TRUE
      )
    }
  }
  loaded <- packages_to_install[packages_to_install %in% loadedNamespaces()]
  if(length(loaded)) {
    stop("The following packages are found that cannot be unloaded. Please make sure you CLOSE ALL running R & RStudio before installing/upgrading RAVE. The packages unable to unload:\n  ", paste(shQuote(loaded), collapse = ", "))
  }

  repos <- get_mirror(nightly = nightly)

  # binary <- isTRUE(getOption("ravemanager.binary_available", FALSE))

  # type <- ifelse(binary, "binary", "source")

  if(missing(libpath) || !length(libpath)) {
    libpath <- NULL
  }

  # Fast install binary deps
  install_packages(
    packages_to_install, lib = libpath,
    repos = repos, type = "binary", force = force
  )

  # Make sure the source package is compiled and updated
  install_packages(
    packages_to_install, lib = libpath,
    repos = repos, type = "source",  force = force
  )

}

install_rave_linux <- function(libpath, nightly = TRUE, force = FALSE, use_rspm = TRUE, ...) {

  packages_to_install <- c(
    rave_depends, "rave", rave_packages
  )

  loaded <- packages_to_install[packages_to_install %in% loadedNamespaces()]

  if(length(loaded)) {

    for(nm in loaded) {
      try(
        expr = {
          unload_namespace(nm)
        },
        silent = TRUE
      )
    }
  }

  loaded <- packages_to_install[packages_to_install %in% loadedNamespaces()]
  if(length(loaded)) {
    stop("The following packages are found that cannot be unloaded. Please make sure you CLOSE ALL running R & RStudio before installing/upgrading RAVE. The packages unable to unload:\n  ", paste(shQuote(loaded), collapse = ", "))
  }

  # install the CRAN dependencies with dev repos
  repos <- get_mirror(nightly = nightly)
  if(missing(libpath) || !length(libpath)) {
    libpath <- NULL
  }

  # Make sure `rspm` is installed
  if(use_rspm && system.file(package = "rspm") == "") {
    install_packages("rspm", lib = libpath)
  }

  rspm_enabled <- FALSE
  if(use_rspm && system.file(package = "rspm") != "") {
    rspm <- asNamespace("rspm")

    try({
      rspm$enable()
      rspm_enabled <- TRUE
    })
    on.exit({
      try({ rspm$disable() })
    }, after = FALSE, add = TRUE)

    if( rspm_enabled ){
      message("Trying to install binary (pre-built) dependence")
      rspm_toinstall <- rspm_install
      rspm_toinstall <- rspm_toinstall[vapply(rspm_toinstall, function(pkg){
        system.file(package = pkg) == ""
      }, FALSE)]
      if(length(rspm_toinstall)) {
        install_packages(
          rspm_toinstall, lib = libpath
        )
      }

    } else {
      message("RSPM disabled: fallback to normal installation")
    }

    try({ rspm$disable() })

  }




  install_packages(
    packages_to_install, lib = libpath, repos = repos, force = force
  )

}
