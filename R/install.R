#' @name RAVE-install
#' @title Install or upgrade 'RAVE'
#' @description Installs the newest version of 'RAVE' and its dependence
#' packages; executes the scripts to finalize installation to update
#' configuration files.
#' @param nightly whether to install the nightly build
#' @param packages packages to run finalizing installation scripts
#' @param upgrade upgrade type
#' @param async whether to execute finalizing installation scripts in other
#' processes
#' @param ... reserved for future use
#' @return Nothing
NULL

#' @rdname RAVE-install
#' @export
finalize_installation <- function(
  packages = NULL,
  upgrade = c('config-only', 'ask', 'always', 'never', 'data-only'),
  async = FALSE, ...
) {
  upgrade <- match.arg(upgrade)

  # Get all packages with rave.yaml
  lib_path <- get_libpaths()

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
  packages <- allpackages[sel]

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
    message("Done")
  }
}

#' @rdname RAVE-install
#' @export
install <- function(nightly = TRUE) {
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
  if(os_type %in% c("windows", "darwin") && os_arch %in% c("x64")) {
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


  switch(
    os_type,
    "darwin" = {
      install_rave_osx(nightly = nightly, libpath = lib_path)
    },
    "windows" = {
      install_rave_windows(nightly = nightly, libpath = lib_path)
    },
    "linux" = {
      install_rave_linux(nightly = nightly, libpath = lib_path)
    }
  )

  message("Packages have been installed. Finalizing settings.")

  packages_to_install <- c(
    rave_depends, "rave", rave_packages
  )
  finalize_installation(packages = packages_to_install,
                        upgrade = 'config-only', async = FALSE)

}

install_rave_osx <- function(libpath, nightly = TRUE) {

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

  binary <- isTRUE(getOption("ravemanager.binary_available", FALSE))

  type <- ifelse(binary, "binary", "source")

  if(missing(libpath) || !length(libpath)) {
    utils::install.packages(
      packages_to_install, repos = repos, Ncpus = 4, type = type
    )
  } else {
    utils::install.packages(
      packages_to_install, lib = libpath, repos = repos, Ncpus = 4, type = type
    )
  }

  message("Packages have been installed. Finalizing settings.")

  finalize_installation(packages = packages_to_install,
                        upgrade = 'config-only', async = FALSE)

}

install_rave_linux <- function(libpath, nightly = TRUE) {

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
  if(missing(libpath)) {
    libpath <- NULL
  }

  # Make sure `rspm` is installed
  if(system.file(package = "rspm") == "") {
    utils::install.packages("rspm", lib = get_libpaths())
  }

  rspm_enabled <- FALSE
  if(system.file(package = "rspm") != "" && is_loaded("rspm")) {
    rspm <- asNamespace("rspm")

    try({
      rspm$enable()
      rspm_enabled <- TRUE
    })
    on.exit({
      try({ rspm$disable() })
    }, after = FALSE, add = TRUE)

  }

  if( rspm_enabled ){
    message("Trying to install binary (pre-built) dependence")
  } else {
    message("RSPM disabled: fallback to normal installation")
  }


  if(!length(libpath)) {
    utils::install.packages(
      packages_to_install, repos = repos, Ncpus = 4
    )
  } else {
    utils::install.packages(
      packages_to_install, lib = libpath, repos = repos, Ncpus = 4
    )
  }

  try({ rspm$disable() })
}
