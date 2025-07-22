PYTHON_PACKAGES <- list(
  # "nibabel" = "nibabel==4.0.2",
  "ants" = "antspyx"
)

get_python_package_name <- function(lib) {
  unlist(lapply(unlist(lib), function(x) {
    re <- PYTHON_PACKAGES[[x]]
    if(is.null(re)) { re <- x }
    re
  }))
}


#' @name configure-python
#' @title Install & Configure 'python' environment for 'RAVE'
#' @description Installs 'python' environment for 'RAVE'
#' @param python_ver python version; default is automatically determined. If
#' a specific python version is needed, please specify explicitly, for example,
#' \code{python_ver='3.8'}
#' @param env_name 'conda' environment to use; set to \code{NA} to verify
#' the default environment
#' @param verbose whether to verbose messages
#' @param ask whether to ask before resetting the 'python' environment
#' @details Use \code{ravemanager::configure_python()} to install and configure
#' python environment using \code{miniconda}. The \code{conda} binary and
#' environment will be completely isolated. This means the installation will be
#' safe and it will not affect any existing configurations on the computer.
#'
#' In this isolated environment, the following packages will be installed:
#' \code{numpy}, \code{scipy}, \code{pandas}, \code{h5py}, \code{jupyterlab},
#' \code{pynwb}, \code{mat73}, \code{mne}. You can always
#' add more \code{conda} packages via \code{rpymat::add_packages(...)} or
#' \code{pip} packages via \code{rpymat::add_packages(..., pip = TRUE)}.
#'
#' To use the 'python' environment, please run \code{rpymat::ensure_rpymat()}
#' to activate in your current session. If you are running via
#' \code{'RStudio'}, open any 'python' script and use \code{'ctrl/cmd+enter'}
#' to run line-by-line. To switch from \code{R} to \code{python} mode,
#' using command \code{rpymat::repl_python()}
#'
#' A \code{jupyterlab} will be automatically installed during the
#' configuration. To launch the \code{jupyterlab}, use
#' \code{rpymat::jupyter_launch()}
#'
#' If you want to remove this \code{conda} environment, use R command
#' \code{rpymat::remove_conda()}. This procedure is absolutely safe and
#' will not affect your other installations.
#'
#' @examples
#'
#' \dontrun{
#'
#' # -------- Install & Configure python environment for RAVE --------
#' ravemanager::configure_python()
#'
#' # Add conda packages
#' rpymat::add_packages("numpy")
#'
#' # Add pip packages
#' rpymat::add_packages("nipy", pip = TRUE)
#'
#' # -------- Activate RAVE-python environment --------
#' rpymat::ensure_rpymat()
#'
#' # run script from a temporary file
#' f <- tempfile(fileext = ".py")
#' writeLines(c(
#'   "import numpy",
#'   "print(f'numpy installed: {numpy.__version__}')"
#' ), f)
#' rpymat::run_script(f)
#'
#' # run terminal command within the environment
#' rpymat::run_command("pip list")
#'
#' # run python interactively, remember to use `exit` to exit
#' # python mode
#' rpymat::repl_python()
#'
#'
#'
#' }
#'
#' @export
validate_python <- function(verbose = TRUE, env_name = NA) {
  callr <- asNamespace("callr")

  f <- function() {}
  body(f) <- bquote({

    verbose <- .(verbose)
    env_name <- .(env_name)

    verb <- function(expr) {
      if(verbose) {
        force( expr )
      }
    }
    verb(message("Initializing python environment: "))

    rpymat <- asNamespace("rpymat")
    support_custom_env <- tryCatch({ isTRUE(rpymat$custom_env_support()) }, error = { FALSE })

    if( support_custom_env ) {
      cleaned_env_name <- rpymat$clean_env_name(env_name = env_name)
      verb({
        message("==== Environment Name: ", cleaned_env_name, " ================================")
      })
      rpymat$ensure_rpymat(verbose = verbose, env_name = cleaned_env_name)
    } else {
      env_name <- rpymat$CONDAENV_NAME()
      verb({
        message("==== Environment Name: ", env_name, " ================================")
      })
      rpymat$ensure_rpymat(verbose = verbose)
    }


    reticulate <- asNamespace("reticulate")

    # verb({
    #   message("Trying to get installed packages...")
    # })
    # tbl <- reticulate$py_list_packages(envname = rpymat$env_path())
    # pkgs <- tbl$package
    # pkgs <- pkgs[grepl("^[a-zA-Z0-9]", pkgs)]

    # verb({
    #   message("Installed packages: ", paste(pkgs, collapse = ", "), "\n")
    # })

    # Check environment
    verb({
      message("Trying to validate packages...")
    })

    package_missing <- NULL
    for(package in c("numpy", "h5py", "mat73", "cython", "pandas", "scipy", "jupyterlab", "pynwb", "mne", "nibabel", "nipy", "ants", "antspynet")) {
      tryCatch({
        verb({ message(sprintf("  %s: ", package), appendLF = FALSE) })
        module <- reticulate$import(package)
        switch(
          package,
          mat73 = {
            verb({ message("  ", package, ": ", module$core$`__version__`) })
          }, {
            verb({ message("  ", package, ": ", module$`__version__`) })
          }
        )

      }, error = function(e) {
        verb({ message("  ", package, ": N/A") })
        package_missing <<- c(package_missing, package)
      })
    }

    verb({
      message("========================================================================")
    })
    package_missing
  })

  package_missing <- callr$r(
    func = f,
    show = TRUE,
    spinner = interactive()
  )

  return(invisible(package_missing))
}

system_pkgpath <- function(package, ..., alternative = TRUE) {
  libpath <- get_libpaths(first = TRUE)
  re <- system.file(package = package, lib.loc = libpath)
  if(re == "" && alternative) {
    re <- system.file(package = package)
  }
  return(re)
}


#' @rdname configure-python
#' @export
configure_antspynet <- function() {
  # Internal function to configure ANTsPyx, assuming Python is configured

  rpymat <- asNamespace("rpymat")
  support_custom_env <- tryCatch({ isTRUE(rpymat$custom_env_support()) }, error = { FALSE })
  if(!support_custom_env) { return(invisible(FALSE)) }

  ants_env_path <- rpymat$env_path(env_name = "rave-ants")
  if(dir.exists(ants_env_path)) { return(TRUE) }

  tryCatch({
    reticulate <- asNamespace("reticulate")
    reticulate$conda_create(ants_env_path, python_version = "3.10")
    reticulate$conda_install(ants_env_path, packages = 'antspynet', pip = TRUE)
    return(invisible(TRUE))
  }, error = function(e) {
    message(e)
  })

  return(invisible(FALSE))
}



#' @rdname configure-python
#' @export
configure_python <- function(python_ver = "3.11", verbose = TRUE) {

  if(!is_installed("rpymat")) {
    install_packages("rpymat")
  }
  rpymat <- asNamespace("rpymat")


  # Install conda and create a conda environment
  # current_env <- Sys.getenv("R_RPYMAT_CONDA_PREFIX", unset = "")
  # conda_exe <- Sys.getenv("R_RPYMAT_CONDA_EXE", unset = "")
  if(!dir.exists(rpymat$env_path())) {
    conda_bin <- rpymat$conda_bin()
    standalone <- TRUE
    if(length(conda_bin) == 1 && !is.na(conda_bin) && file.exists(conda_bin)) {
      standalone <- FALSE
    }

    # # fix issue on intel max
    # if( python_ver %in% c("3.9", "auto") &&
    #     identical(get_os(), "darwin") &&
    #     isTRUE(startsWith(R.version$arch, "x86")) ) {
    #   python_ver <- "3.10"
    # }

    # Increase timeout to 30min
    options("timeout" = 60*30)
    tryCatch({
      rpymat$configure_conda(python_ver = python_ver, force = TRUE, standalone = standalone)
    }, error = function(e) {
      rpymat$set_conda(temporary = TRUE)
      rpymat$miniconda_installer_url()
      reticulate <- asNamespace("reticulate")
      reticulate$install_miniconda(path = rpymat$conda_path(),
                                   update = TRUE, force = TRUE)
      rpymat$configure_conda(python_ver = python_ver, force = TRUE)
    })
  }

  rpymat$ensure_rpymat(verbose = verbose)

  reticulate <- asNamespace("reticulate")
  installed_pkgs_tbl <- rpymat$list_pkgs()

  # install necessary libraries
  pkgs <- c("h5py", "mat73", "numpy", "scipy", "pandas", "cython", "pkg-config", "fftw", "cmake", "dcm2niix")
  if(!all(pkgs %in% installed_pkgs_tbl$package)) {
    rpymat$add_packages(get_python_package_name(pkgs))
  }

  # install jupyter lab to the conda environment
  pkgs <- c("notebook", "jupyterlab")
  if(!all(pkgs %in% installed_pkgs_tbl$package)) {
    try({
      rpymat$add_packages(packages = get_python_package_name(c("notebook", "numpy", "h5py", "matplotlib", "pandas", "jupyterlab")))
      rpymat$jupyter_register_R()
    })
  }

  # install pip-only packages if conda fails
  pkgs <- c("mne", "pynwb", "nibabel")
  pkgs <- pkgs[!pkgs %in% installed_pkgs_tbl$package]
  if(length(pkgs)) {
    for(pkg in get_python_package_name(pkgs)) {
      if( pkg %in% pkgs ) {
        try({
          rpymat$add_packages(packages = pkg, pip = TRUE)
        })
        installed_pkgs_tbl <- rpymat$list_pkgs()
        pkgs <- pkgs[!pkgs %in% installed_pkgs_tbl$package]
      }
    }
  }

  # Make sure antspy is installed
  # pkgs <- c("antspynet", "antspyx")
  pkgs <- c("antspyx")
  pkgs <- pkgs[!pkgs %in% installed_pkgs_tbl$package]
  if(length(pkgs)) {
    for(pkg in get_python_package_name(pkgs)) {
      if( pkg %in% pkgs ) {
        try({
          rpymat$add_packages(packages = pkg, pip = TRUE)
        })
        installed_pkgs_tbl <- rpymat$list_pkgs()
        pkgs <- pkgs[!pkgs %in% installed_pkgs_tbl$package]
      }
    }
  }


  # ants_configured <- configure_antspynet()

  # Initialize
  if( verbose ) {
    cat("\n\n\n")
    cat("\014")
    message("\014")
  }

  validate_python(verbose = verbose)
  # if( ants_configured ) {
  #   validate_python(verbose = verbose, env_name = "rave-ants")
  # }

  if( verbose ) {
    message("Done configuring Python for RAVE.")
  }


}


#' @rdname configure-python
#' @export
remove_conda <- function(ask = TRUE) {
  rpymat <- asNamespace("rpymat")
  rpymat$remove_conda(ask = ask)
}

#' @rdname configure-python
#' @export
ensure_rpymat <- function(env_name = NA) {
  rpymat <- asNamespace("rpymat")
  support_custom_env <- tryCatch({ isTRUE(rpymat$custom_env_support()) }, error = { FALSE })
  if( support_custom_env ) {
    rpymat$ensure_rpymat(env_name = env_name)
  } else {
    rpymat$ensure_rpymat()
  }

}

