#' @name configure-python
#' @title Install & Configure 'python' environment for 'RAVE'
#' @description Installs 'python' environment for 'RAVE'
#' @param python_ver python version; default is automatically determined. If
#' a specific python version is needed, please specify explicitly, for example,
#' \code{python_ver='3.8'}
#' @param verbose whether to verbose messages
#' @details Use \code{ravemanager::configure_python()} to install and configure
#' python environment using \code{miniconda}. The \code{conda} binary and
#' environment will be completely isolated. This means the installation will be
#' safe and it will not affect any existing configurations on the computer.
#'
#' In this isolated environment, the following packages will be installed:
#' \code{numpy}, \code{scipy}, \code{pandas}, \code{h5py}, \code{jupyterlab},
#' \code{pynwb}, \code{nipype}, \code{dipy}, \code{nibabel}, \code{nipy},
#' \code{nitime}, \code{nilearn}, \code{mne}, \code{niwidgets}. You can always
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
validate_python <- function(verbose = TRUE) {
  if(verbose) {
    message("Initializing python environment: ")
  }

  rpymat <- asNamespace("rpymat")
  rpymat$ensure_rpymat(verbose = verbose)

  reticulate <- asNamespace("reticulate")

  if( verbose ) {
    message("Trying to get installed packages...")
    Sys.sleep(3)
  }
  tbl <- reticulate$py_list_packages(envname = rpymat$env_path())
  pkgs <- tbl$package
  pkgs <- pkgs[grepl("^[a-zA-Z0-9]", pkgs)]

  if( verbose ) {
    cat("Installed packages:", paste(pkgs, collapse = ", "), "\n")
  }

  # Check environment
  if( verbose ) {
    message("Trying to validate packages...")
    Sys.sleep(1)
    cat("numpy: ...")
  }
  numpy <- reticulate$import("numpy")
  if( verbose ) {
    cat("\b\b\b", numpy$`__version__`, "\n", sep = "")

    cat("h5py: ...")
  }
  h5py <- reticulate$import("h5py")
  if( verbose ) {
    cat("\b\b\b", h5py$`__version__`, "\n", sep = "")

    cat("cython: ...")
  }
  cython <- reticulate$import("cython")
  if( verbose ) {
    cat("\b\b\b", cython$`__version__`, "\n", sep = "")

    cat("pandas: ...")
  }
  pandas <- reticulate$import("pandas")
  if( verbose ) {
    cat("\b\b\b", pandas$`__version__`, "\n", sep = "")

    cat("scipy: ...")
  }
  scipy <- reticulate$import("scipy")
  if( verbose ) {
    cat("\b\b\b", scipy$`__version__`, "\n", sep = "")
    cat("jupyterlab: ...")
  }
  jupyterlab <- reticulate$import("jupyterlab")
  if( verbose ) {
    cat("\b\b\b", jupyterlab$`__version__`, "\n", sep = "")
    cat("pynwb: ...")
  }
  pynwb <- reticulate$import("pynwb")
  if( verbose ) {
    cat("\b\b\b", pynwb$`__version__`, "\n", sep = "")
    cat("mne: ...")
  }
  mne <- reticulate$import("mne")
  if( verbose ) {
    cat("\b\b\b", mne$`__version__`, "\n", sep = "")
    cat("nibabel: ...")
  }
  nibabel <- reticulate$import("nibabel")
  if( verbose ) {
    cat("\b\b\b", nibabel$`__version__`, "\n", sep = "")
    cat("nipy: ...")
  }
  nipy <- reticulate$import("nipy")
  if( verbose ) {
    cat("\b\b\b", nipy$`__version__`, "\n", sep = "")
  }
  return(invisible(TRUE))
}

#' @rdname configure-python
#' @export
configure_python <- function(python_ver = "auto", verbose = TRUE) {

  rpymat <- asNamespace("rpymat")

  # Install conda and create a conda environment
  if(!dir.exists(rpymat$env_path())) {
    rpymat$configure_conda(python_ver = python_ver, force = TRUE)
  }
  rpymat$ensure_rpymat(verbose = verbose)

  reticulate <- asNamespace("reticulate")
  installed_pkgs_tbl <- reticulate$py_list_packages(envname = rpymat$env_path())

  # install necessary libraries
  pkgs <- c("h5py", "numpy", "scipy", "pandas", "cython")
  if(!all(pkgs %in% installed_pkgs_tbl$package)) {
    rpymat$add_packages(pkgs)
  }

  # install jupyter lab to the conda environment
  pkgs <- c("jupyter", "jupyter_server", "jupyterlab", "jupyterlab_server")
  if(!all(pkgs %in% installed_pkgs_tbl$package)) {
    rpymat$add_jupyter()
  }

  # install nipy family
  pkgs <- c("nibabel", "nipy", "pynwb")
  pkgs <- pkgs[!pkgs %in% installed_pkgs_tbl$package]
  if(length(pkgs)) {
    rpymat$add_packages(packages = pkgs, pip = TRUE)
  }

  # Initialize
  if( verbose ) {
    cat("\n\n\n")
    cat("\014")
    message("\014")
  }

  validate_python(verbose = verbose)
  if( verbose ) {
    message("Done. Use `rpymat::ensure_rpymat()` to activate this environment.")
  }
}
