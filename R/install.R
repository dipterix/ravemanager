#' @name RAVE-install
#' @title Install or upgrade 'RAVE'
#' @description Installs the newest version of 'RAVE' and its dependence
#' packages; executes the scripts to finalize installation to update
#' configuration files.
#' @param allow_cache whether to allow cache; default is true
#' @param upgrade_manager whether to upgrade the installer (\code{ravemanager})
#' before updating other packages
#' @param force whether to force updating packages even the installed have
#' the latest versions
#' @param finalize whether to run finalizing installation scripts
#' @param packages packages to run finalizing installation scripts
#' @param upgrade upgrade type
#' @param async whether to execute finalizing installation scripts in other
#' processes
#' @param python whether to install python; default is false
#' @param reload whether to reload \code{ravemanager} after installation;
#' default is true. This tries to load the upgraded \code{ravemanager}
#' without restarting the R session; however, this solution not always
#' works. In such case, restarting R session is always the solution.
#' @param ... passed to internal functions
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
        repos = 'https://rave-ieeg.r-universe.dev',
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
                             ..., INSTALL_opts = '--no-lock', force = TRUE,
                             verbose = TRUE, use_pak = TRUE) {

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

  if(!length(pkgs)) { return() }
  pkgs2 <- pkgs
  installed <- FALSE
  tryCatch({
    if(use_pak && system.file(package = "pak") != "") {
      pak <- asNamespace("pak")
      current_repos <- pak$repo_get(bioc = FALSE)
      repos[current_repos$name] <- current_repos$url
      options(repos = repos)

      pkgs3 <- pkgs
      if(!identical(type, "source")) {
        pkgs3 <- sprintf("any::%s", pkgs)
      }
      pak$pkg_install(pkg = pkgs3, ask = FALSE, lib = lib,
                      upgrade = FALSE, dependencies = NA)
      installed <- TRUE
    }
  }, error = function(e) {
    if(detect_gh_ci()) {
      stop(e)
    }
    if(!force) {
      pkgs2 <<- pkgs[sapply(pkgs, function(pkg) {
        re <- isFALSE(package_needs_update(pkg, lib = lib))
        !re
      })]
    }
    message("Try the native installation methods. \n[Original Error]: ", e$message)
  })

  if(!installed && length(pkgs2)) {
    utils::install.packages(pkgs2, lib = lib, repos = repos, ..., INSTALL_opts = INSTALL_opts, type = type)
  }
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

  # Make sure critical packages have higher priority
  critical_packages <- c("threeBrain", "raveio")
  critical_packages <- critical_packages[critical_packages %in% packages]
  packages <- unique(c(critical_packages, packages))

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

      message("Finalizing installation: ", pkg, "\r", appendLF = FALSE)

      tryCatch({
        withRestarts({
          do.call(fun, args)
        }, abort = function() {})
      }, error = function(e) {
        warning(e)
      })


      if(async) {
        message(sprintf(
          "[%s] finalizing installation in the background.\r",
          pkg
        ), appendLF = FALSE)
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
clear_cache <- function() {
  config_libpath <- tools::R_user_dir(package = "ravemanager", which = "config")
  cache_path <- tools::R_user_dir("ravemanager", which = "cache")
  if(file.exists(config_libpath)) { unlink(config_libpath, recursive = TRUE, force = TRUE) }
  if(file.exists(cache_path)) { unlink(cache_path, recursive = TRUE, force = TRUE) }
  invisible()
}


assert_r_version <- function(min = "4.0.0") {
  # check R version
  rversion <- R.Version()
  rversion <- sprintf("%s.%s", rversion$major, rversion$minor)
  if(utils::compareVersion(rversion, min) < 1) {
    stop(sprintf("Your R version (%s) is too low. Please install the latest R on your machine\n  Please check https://cran.r-project.org/ for more information.", rversion))
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
        if( latest_ver$minor == current_ver$minor ) {
          options("ravemanager.binary_available" = TRUE)
        }
      }
    }, error = function(e){})
  }
  return(TRUE)
}

pak_cache_dir <- function() {
  tools <- asNamespace("tools")
  tools$R_user_dir("ravemanager", which = "cache")
}

pak_cache_remove <- function() {
  cache_path <- pak_cache_dir()
  if(file.exists(cache_path)) {
    message("Removing package cache...")
    unlink(cache_path, recursive = TRUE)
  }
  invisible()
}

try_setup_pak <- function(lib_path = get_libpaths(check = TRUE)) {
  cdir <- NULL
  tryCatch({

    cdir <- dir_create2(pak_cache_dir())

    # Try to install package `pak`
    if(system.file(package = "pak") == "") {
      install_packages("pak", lib = lib_path, use_pak = FALSE)
      pak <- asNamespace("pak")
      tryCatch({
        extras <- pak$extra_packages()
        install_packages(extras, lib = lib_path, use_pak = FALSE)
      }, error = function(e){})
    }

  }, error = function(e) {})

  return(cdir)
}

installer_unload_packages <- function() {

  # Try to unload packages, may not always work but they should be unloaded anyway
  packages_to_install <- c(
    rave_depends, "rave", rave_packages,
    rave_suggests[!vapply(rave_suggests, is_installed, FALSE)]
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
    warning("The following packages are found that cannot be unloaded. Please make sure you CLOSE ALL running R & RStudio before installing/upgrading RAVE. The packages unable to unload:\n  ", paste(shQuote(loaded), collapse = ", "))
  }
}

install_internal <- function(nightly = FALSE, upgrade_manager = FALSE,
                             finalize = TRUE, force = FALSE, python = FALSE, ...) {

  # DIPSAUS DEBUG START
  # list2env(list(nightly = FALSE, upgrade_manager = FALSE,
  #               finalize = TRUE, force = FALSE, python = FALSE), envir=.GlobalEnv)


  if( nightly ) {
    options("ravemanager.nightly" = TRUE)
  } else {
    options("ravemanager.nightly" = FALSE)
  }

  # Get os information
  os_type <- get_os()
  os_arch <- get_arch()
  repos <- get_mirror(nightly = nightly)

  assert_r_version(min = "4.0.0")

  # make sure RAVE is installed in path defined by `R_LIBS_USER` system env
  lib_path <- get_libpaths(check = TRUE)

  # set system environments
  cdir <- try_setup_pak()
  rdir <- Sys.getenv("R_USER_CACHE_DIR", "")
  on.exit({
    Sys.setenv(R_USER_CACHE_DIR = rdir)
    if(detect_gh_ci()) {
      if(length(cdir) == 1 && file.exists(cdir)) {
        unlink(cdir, recursive = TRUE, force = TRUE)
      }
    }
  })
  if(length(cdir) == 1 && is.character(cdir)) {
    Sys.setenv(R_USER_CACHE_DIR = cdir)
  }

  clear_uninstalled()

  # ravemanager upgrade
  if( upgrade_manager ) {
    if( os_type == "windows" ) {
      # TODO: try pkgload
      message("Cannot upgrade RAVE installer on Windows. Please restart R and run the following command to upgrade ravemanager instead:\n  install.packages('ravemanager', repos = 'https://rave-ieeg.r-universe.dev')")
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

  installer_unload_packages()

  packages_to_install <- c(
    rave_depends, "rave", rave_packages,
    rave_suggests[!vapply(rave_suggests, is_installed, FALSE)]
  )

  repos <- get_mirror(nightly = nightly)


  # Fast install binary deps
  message("Installing RAVE... This might take a while...")
  tryCatch({
    install_packages(
      packages_to_install, lib = lib_path,
      repos = repos, type = "binary", force = force
    )
  }, error = function(e) {
    message("Unable to install compiled packages. Trying to build from source (will take a while)...")
  })


  # Make sure the source package is compiled and updated for core packages
  packages_to_install <- c(
    rave_depends, "rave", rave_packages,
    rave_suggests[!vapply(rave_suggests, is_installed, FALSE)]
  )
  install_packages(
    packages_to_install, lib = lib_path,
    repos = repos, type = "source",  force = force,
    use_pak = FALSE
  )

  # Configure python
  if( python ) {
    try({
      message("Configuring python...")
      install_packages("rpymat", lib = lib_path,
                       repos = repos, force = FALSE)
      configure_python()
    })
  }

  if(finalize) {
    message("Packages have been installed. Finalizing settings.")

    packages_to_install <- c(ravemanager$rave_depends, "rave",
                             ravemanager$rave_packages,
                             ravemanager$rave_suggests)

    suppressWarnings({
      ravemanager$finalize_installation(
        packages = packages_to_install,
        upgrade = 'config-only', async = FALSE)
    })

  } else {
    message("Done installing/updating RAVE! Please close all your R/RStudio sessions and restart. If you want to update package add-ons, please run `ravemanager::finalize_installation()` after restart.")
  }


}

#' @rdname RAVE-install
#' @export
install <- function(allow_cache = FALSE, upgrade_manager = FALSE,
                    finalize = TRUE, force = FALSE, python = FALSE, ...) {

  if(!allow_cache) {
    pak_cache_remove()
  }


  nightly <- FALSE
  tryCatch({
    install_internal(
      nightly = nightly,
      upgrade_manager = upgrade_manager,
      finalize = finalize,
      force = force,
      python = python,
      ...
    )
  }, error = function(e) {

    line_width <- as.integer(getOption("width", 80L))
    if( !isTRUE(line_width <= 80L) ) { line_width <- 80L }
    if( line_width < 20 ) { line_width <- 20 }

    message(paste(rep("=", line_width), collapse = ""), appendLF = TRUE)

    error_verbosed <- FALSE
    on.exit({
      if(!error_verbosed) {
        message("# ", paste(rep("-", 4), collapse = ""),
                " RAVE installer detects the following error(s): ", paste(rep("-", 8), collapse = ""),
                appendLF = TRUE)
        message(e$message)
      }
    }, add = FALSE)

    msg_troubleshoot <- NULL

    os <- get_os()

    tryCatch({
      if(os == "darwin") {
        has_brew <- brew_installed()
        if(!has_brew) {
          msg_troubleshoot <- c(msg_troubleshoot, 'It seems that you haven\'t installed Homebrew (open-source pacakge manager for MacOS) yet. Please go to https://brew.sh/ or copy-paste-run the following shell terminal command:\n\n  /usr/bin/env bash\n  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"\n\n\n* For the first time installer, you will need to enter your user login password (your password will not show up on typing), and hit `return` key. Then hit `return` key again to accept default installation options.\n* If you believe you have installed Homebrew, please contact RAVE developers (slack or help@rave.wiki) for troubleshooting')
        }
        brew_packages <- c("fftw", "hdf5", "libpng", "pkg-config", "cmake")
        brew_packages <- brew_packages[!brew_installed(brew_packages)]
        if(length(brew_packages)) {
          msg_troubleshoot <- c(msg_troubleshoot, sprintf("The following **system packages** are missing. RAVE does not install system packages. You need to install them by yourself since they may require admin/sudo account privilege. If you have Homebrew installed, copy-paste-run the following terminal commands to install these libraries:\n\n  brew install %s\n\n", paste(brew_packages, collapse = " ")))
        }
      } else if( os == "linux" ){
        # suppressWarnings({
        #   missing_pkg <- system_requirements(sudo = TRUE)
        #   if(length(missing_pkg)) {
        #
        #     msg_troubleshoot <- c(msg_troubleshoot, sprintf("You are using Linux operating system. It is most likely that some system packages are missing. RAVE does not install system packages. You need to install them by yourself since they usually require sudo account privilege. Please consider installing the following libraries first:\n\n%s\n\n", paste("  ", missing_pkg, collapse = "\n")))
        #
        #   }
        # })
      }
    }, error = function(e){})


    if(length(msg_troubleshoot)) {
      message("# ", paste(rep("-", 4), collapse = ""),
              " Toubleshoot ", paste(rep("-", 8), collapse = ""),
              appendLF = TRUE)
      message("Failure to install RAVE is often caused by missing system libraries. Please make sure you have installed necessary: https://openwetware.org/wiki/RAVE:Install_prerequisites\n")
      lapply(seq_along(msg_troubleshoot), function(ii) {
        msg <- unlist(strsplit(msg_troubleshoot[[ii]], "\n"))
        prefix <- rep("    ", length(msg))
        prefix[[1]] <- sprintf("%d. ", ii)
        message(paste(prefix, msg, collapse = "\n"), appendLF = TRUE)
      })

    }

    message("# ", paste(rep("-", 4), collapse = ""),
            " RAVE installer detects the following error(s): ", paste(rep("-", 8), collapse = ""),
            appendLF = TRUE)
    message(e$message)
    error_verbosed <- TRUE

  })
}

#' @rdname RAVE-install
#' @export
update_rave <- install

#' @rdname RAVE-install
#' @export
upgrade_installer <- function(reload = TRUE) {
  v1 <- ravemanager_version()
  v2 <- ravemanager_latest_version()
  updated <- FALSE
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
        updated <- TRUE
      }
    }, error = function(e) {
      message("Failed to upgrade `ravemanager`: using current version")
    })

  } else {
    message("The installer has the latest version.")
  }
  if(reload && system.file(package = "pkgload") != '') {
    lib_path <- get_libpaths(first = TRUE, check = TRUE)
    path <- system.file(package = "ravemanager", lib.loc = lib_path)
    if(path == "") {
      path <- system.file(package = "ravemanager")
    }
    if(path != "") {
      pkgload::load_all(path)
    }
  }
  return(invisible(FALSE))
}

#' Uninstall RAVE components
#' @description
#' Remove cache, python, and/or all settings. Please be aware that
#' R, 'RStudio', and already installed R packages will not be uninstalled.
#' Please carefully read printed messages.
#' @param components which component to remove, see example for choices.
#' @examples
#'
#' if( FALSE ) {
#'
#'   # remove cache only
#'   ravemanager::uninstall("cache")
#'
#'   # remove python environment
#'   ravemanager::uninstall("python")
#'
#'   # remove all sample data, settings files
#'   ravemanager::uninstall("all")
#'
#' }
#'
#'
#' @export
uninstall <- function(components = c("cache", "python", "all")) {
  components <- match.arg(components)
  remove_cache <- components %in% c("cache", "all")
  remove_python <- components %in% c("python", "all")
  remove_all <- components %in% c("all")

  if( remove_all ) {
    ans <- utils::askYesNo("You are uninstalling RAVE. Please enter Y or yes to confirm: ")
    if(!isTRUE(ans)) {
      return(invisible())
    }
  }

  tools <- asNamespace("tools")
  R_user_dir <- tools$R_user_dir

  remove_files <- function(paths) {
    lapply(paths, function(path) {
      if(!file.exists(path)) { return() }
      if(dir.exists(path)) {
        unlink(path, recursive = TRUE)
      } else {
        unlink(path)
      }
      return()
    })
  }
  if( remove_cache ) {
    message("Removing cache...")

    # ravemanager
    pak_cache_remove()

    # raveio
    d <- R_user_dir(package = "raveio", which = "data")
    fs <- list.files(d, pattern = "^(dipterix|rave-ieeg)-rave-pipelines", include.dirs = TRUE, full.names = TRUE, recursive = FALSE)
    remove_files(fs)
    if(is_installed("raveio")) {
      raveio <- asNamespace("raveio")
      raveio$clear_cached_files()
    }
  }

  if( remove_python ) {
    message("Removing python...")
    remove_conda(ask = FALSE)

    # rpymat
    d <- R_user_dir(package = "rpymat", which = "config")
    remove_files(file.path(d, "jupyter-configurations"))
  }

  if( remove_all ) {
    message("Uninstalling RAVE (we are sorry to say goodbye)...")

    # remove ~/rave_modules
    remove_files("~/rave_modules")

    remove_files( R_user_dir("raveio", "data") )
    remove_files( R_user_dir("rpyANTs", "data") )
    remove_files( R_user_dir("threeBrain", "data") )

    remove_files( R_user_dir("raveio", "config") )
    remove_files( R_user_dir("ravemanager", "config") )
    remove_files( R_user_dir("rpymat", "config") )

    remove_files( R_user_dir("dipsaus", "cache") )
    remove_files( R_user_dir("ravemanager", "cache") )
    remove_files( R_user_dir("readNSx", "cache") )

    message("R and RStudio are not managed by RAVE. Please uninstall them by yourself if necessary.")
    msg <- paste(
      c(
        "There are some files that may contain your data or used other packages. ",
        "Please check them manually:\n",
        .libPaths(),
        normalizePath("~/rave_data", mustWork = FALSE)
      ),
      collapse = "\n"
    )
    message(msg)
  }
}
