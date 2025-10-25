# module load miniconda
# Sys.setenv("R_RPYMAT_CONDA_EXE" = Sys.which("conda"))

# Sys.setenv("R_RPYMAT_CONDA_PREFIX" = conda_env_path)
# ravemanager::configure_python()

local({

  dir_create2 <- function (x, showWarnings = FALSE, recursive = TRUE, check = TRUE, ...) {
    if (!dir.exists(x)) {
      dir.create(x, showWarnings = showWarnings, recursive = recursive, ...)
    }
    if (check && !dir.exists(x)) {
      stop("Cannot create directory at ", shQuote(x))
    }
    invisible(normalizePath(x))
  }

  rave_root <- dir_create2("/opt/shared/rave")

  config <- list(
    paths = list(
      root = rave_root,
      runtime = file.path(rave_root, "data", "cache_dir"),
      data = file.path(rave_root, "data", "data_dir"),
      raw = file.path(rave_root, "data", "raw_dir"),
      bids = file.path(rave_root, "data", "bids_dir")
      # quarto = "/Applications/RStudio.app/Contents/Resources/app/quarto/bin/quarto"
    )
  )

  options(timeout = 3600)
  whoami <- Sys.info()[["user"]]
  if(!length(whoami) || !nzchar(whoami)) {
    whoami <- "shared"
  }

  setup_rave <- function(config) {
    rave_runtime <- dir_create2(config$paths$runtime)
    rave_datadir <- dir_create2(config$paths$data)
    rave_rawdir <- dir_create2(config$paths$raw)
    rave_bidsdir <- normalizePath(config$paths$bids, mustWork = FALSE)

    # set cache & session dir
    ravepipeline <- asNamespace("ravepipeline")
    ravepipeline$raveio_setopt(key = "tensor_temp_path", value = file.path(rave_runtime, "shared"))

    # set data & raw dir
    ravepipeline$raveio_setopt(key = "data_dir", value = rave_datadir)
    ravepipeline$raveio_setopt(key = "raw_data_dir", value = rave_rawdir)
    ravepipeline$raveio_setopt(key = "bids_data_dir", value = rave_bidsdir)

    # parallel computing
    ravepipeline$raveio_setopt(key = "max_worker", value = parallel::detectCores())

    # set 3D viewer
    options('threeBrain.template_dir' = dir_create2(tools::R_user_dir("threeBrain", "data")))

  }


  initialize_impl <- function() {
    initialized <- Sys.getenv("RAVE_INITIALIZED", unset = "")
    if( identical(initialized, "TRUE") ) { return() }

    # source("renv/activate.R")
    Sys.setenv(RAVE_INITIALIZED = "TRUE")

    # RAVE might be missing
    tryCatch(
      {
        setup_rave(config)
      },
      error = function(e) {
        # ignore : D
      }
    )
  }
  initialize_impl()

  invisible()
})
