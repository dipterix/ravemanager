# module load miniconda
# Sys.setenv("R_RPYMAT_CONDA_EXE" = Sys.which("conda"))

# Sys.setenv("R_RPYMAT_CONDA_PREFIX" = conda_env_path)
# ravemanager::configure_python()

normalize_path <- function(path, ...) {
  path <- normalizePath(path = path, ...)
  gsub("[/|\\\\]+", "/", path)
}

file_path <- function(...) {
  path <- file.path(...)
  gsub("[/|\\\\]+", "/", path)
}

default_config_home <- function() {
  p <- Sys.getenv("XDG_CONFIG_HOME")
  if (nzchar(p)) { return(p) }

  path <- switch(get_os(),
    "windows" = {
      file.path(Sys.getenv("APPDATA"), "R", "config")
    },
    "darwin" = {
      file.path("~", "Library", "Preferences", "org.R-project.R")
    },
    {
      file.path("~", ".config")
    }
  )
  normalize_path(path, mustWork = FALSE)
}

shared_profile <- function(python = "3.11", share_root = NA) {

  if (is_installed("rpymat")) {
    conda_bin <- asNamespace("rpymat")$conda_bin()
  } else {
    conda_bin <- Sys.which("conda")
  }

  if (is_installed("rpymat")) {
    quarto_bin <- asNamespace("quarto")$quarto_path()
  } else {
    quarto_bin <- Sys.which("quarto")
  }

  if (is.na(share_root)) {
    if (is_installed("ravepipeline")) {
      share_root <- dirname(asNamespace("ravepipeline")$raveio_getopt("data_dir"))
    } else {
      share_root <- "~/rave_data/"
    }
  }

  config <- list(
    paths = list(
      profile_root = profile_root(),
      share_root = file_path(share_root),
      runtime_root = file_path(share_root, "cache_dir"),
      data = file_path(share_root, "data_dir"),
      raw = file_path(share_root, "raw_dir"),
      bids = file_path(share_root, "bids_dir"),

      conda = file_path(conda_bin),
      quarto = file_path(quarto_bin)
    ),
    conda = list(
      python = python
    ),
    shidashi = list(
      chat_provider = NULL,
      chat_base_url = NULL
    ),
    threeBrain = list(
      ensure_templates = c(
        "cvs_avg35_inMNI152",
        "fsaverage",
        "N27"
      )
    ),
    rpyANTs = list(
      ensure_templates = c(
        "mni_icbm152_nlin_asym_09a",
        "mni_icbm152_nlin_asym_09b",
        "mni_icbm152_nlin_asym_09c"
      )
    )
  )

  return(config)
}

profile_root <- function(check = FALSE) {
  path <- file_path(default_config_home(), "R", "ravemanager", "profiles")
  if (check) {
    dir_create2(path)
    path <- normalize_path(path)
  }
  path
}

#' @name rave-profile
#' @title Make a profile allowing portable `RAVE` configurations
#' @param profile profile configurations
#' @param profile_name name of the profile
#' @param auto_install whether to automatically install RAVE with the
#' profile; default is `TRUE`
#'
#' @examples
#' \dontrun{
#'
#' # Make a template profile first. You may edit this profile
#' # to redirect paths to shared drive, SSD etc.
#' # Make sure you have the write permissions
#'
#' make_profile()
#'
#' # Test and install the profile
#' use_profile()
#'
#' # Edit in your .Rprofile via `usethis::edit_r_profile()`
#' # add this line
#' ravemanager::use_profile(auto_install = FALSE)
#'
#' }
#'
#' @export
make_profile <- function(profile = shared_profile(), profile_name = "default") {
  if (!endsWith(profile_name, ".yaml")) {
    profile_name <- sprintf("%s.yaml", profile_name)
  }
  profile_path <- file_path(profile_root(check = TRUE), profile_name)
  if (!is_installed("yaml")) {
    add_r_package("yaml")
  }

  yaml <- asNamespace("yaml")
  yaml$write_yaml(profile, profile_path)
  profile_path
}

validate_profile <- function(config) {


  is_pathish <- function(path, name = deparse1(substitute(path))) {
    name <- gsub("\\$", ".", name)
    if (!length(path)) {
      stop("Configuration `", name, "` is invalid: length of the path must be one")
    }
    if (!is.character(path) || is.na(path) || !nzchar(path) || startsWith(path, ".")) {
      stop("Configuration `", name, "` is invalid: the path must be a non-empty absolute path")
    }
  }

  is_pathish(config$paths$share_root)

  if (!dir.exists(config$paths$share_root)) {
    stop("Path `", config$paths$share_root, "` is missing. Please create this folder first")
  }

  is_pathish(config$paths$runtime_root)
  is_pathish(config$paths$data)
  is_pathish(config$paths$raw)
  is_pathish(config$paths$bids)
  # is_pathish(config$paths$quarto)

  config

}

#' @rdname rave-profile
#' @export
use_profile <- function(profile_name = "default", auto_install = TRUE) {
  if (!endsWith(profile_name, ".yaml")) {
    profile_name <- sprintf("%s.yaml", profile_name)
  }
  if (file.exists(profile_name)) {
    profile_path <- profile_name
  } else {
    profile_path <- file_path(profile_root(), profile_name)
  }
  if (!file.exists(profile_path)) {
    warning("Unable to find the profile: ", profile_name)
    return(invisible())
  }
  profile_path <- normalize_path(profile_path, mustWork = TRUE)

  if (!is_installed("yaml")) {
    add_r_package('yaml')
  }

  yaml <- asNamespace("yaml")
  config <- yaml$read_yaml(profile_path)

  config$conda$env_prefix <- gsub("-", "", gsub("\\.yaml$", "", tolower(basename(profile_name))))

  validate_profile(config)

  message("Loaded profile from: ", profile_path)
  message("Initializing profile...")

  old_opt <- options(timeout = 3600)
  on.exit(options(old_opt))
  whoami <- Sys.info()[["user"]]
  if (!length(whoami) || !nzchar(whoami)) {
    whoami <- "shared"
  }

  rave_root <- dir_create2(config$paths$share_root)
  r_data_path <- normalize_path(file_path(rave_root, "UserPreferences", "shared", "data"), mustWork = FALSE)

  conda_path <- config$paths$conda
  if (length(conda_path) != 1 || is.na(conda_path) || !nzchar(conda_path)) {
    conda_path <- Sys.which("conda")

    if (!nzchar(conda_path)) {
      conda_path <- "/opt/homebrew/anaconda3/bin/conda"
      if (!file.exists(conda_path)) {
        conda_path <- file.path(
          tools::R_user_dir("rpymat", which = "data"),
          "miniconda", "condabin", "conda")
      }
    }
  }

  conda_env_path <- file.path(r_data_path, "r-rpymat", "miniconda", "envs", config$conda$env_prefix)
  conda_env_path <- normalize_path(conda_env_path, winslash = "/", mustWork = FALSE)
  conda_env_path <- gsub("[/]{0,}$", "", conda_env_path)

  quarto_path <- config$paths$quarto
  if (length(quarto_path) != 1 || !file.exists(quarto_path)) {
    quarto_path <- Sys.which("quarto")
  } else {
    quarto_path <- normalizePath(quarto_path, winslash = "/")
  }

  version <- sprintf("%s.%s", R.version$major, gsub("\\..*$", "", R.version$minor))
  lib_name <- sprintf("%s-%s-%s", get_os(), version, R.version$arch)

  # set R_user_dir & conda
  Sys.setenv(
    RAVE_LIB_PATH = file.path(rave_root, "Library", lib_name, "R"),
    # data like pipeline templates can be shared
    R_USER_DATA_DIR = r_data_path,

    # config and cache are user-specific
    R_USER_CONFIG_DIR = file.path(rave_root, "UserPreferences", whoami, "config"),
    R_USER_CACHE_DIR = file.path(rave_root, "UserPreferences", whoami, "cache"),

    R_RPYMAT_CONDA_EXE = conda_path,
    R_RPYMAT_CONDA_PREFIX = conda_env_path,

    QUARTO_PATH = quarto_path
  )

  # Copilot settings
  chat_provider <- config$shidashi$chat_provider
  if (length(chat_provider) == 1) {
    options("shidashi.chat_provider" = chat_provider)
  }

  chat_base_url <- config$shidashi$chat_base_url
  if (length(chat_base_url) == 1) {
    options("shidashi.chat_base_url" = chat_base_url)
  }

  get_libpaths(check = TRUE)

  # Check if RAVE is installed?
  if (!is_installed("ravepipeline")) {
    if (auto_install) {
      # RAVE is not installed
      add_r_package("raveio")
      # add_r_package("ravepipeline")
      # add_r_package("ravecore")
      install()
      configure_python(python_ver = config$conda$python)
    } else {
      warning("RAVE is not installed. Please run `ravemanager::install()`")
      return()
    }
  }

  # Setup RAVE
  rave_root <- normalize_path(config$paths$share_root)
  rave_runtime <- normalizePath(config$paths$runtime_root, mustWork = FALSE)
  rave_datadir <- normalizePath(config$paths$data, mustWork = FALSE)
  rave_rawdir <- normalizePath(config$paths$raw, mustWork = FALSE)

  # set cache & session dir
  ravepipeline <- asNamespace("ravepipeline")
  ravepipeline$raveio_setopt(key = "tensor_temp_path", value = file.path(rave_runtime, "shared"))
  ravepipeline$raveio_setopt(key = "ravedash_session_root", value = file.path(rave_runtime, "sessions", whoami))

  # set data & raw dir
  ravepipeline$raveio_setopt(key = "data_dir", value = rave_datadir)
  ravepipeline$raveio_setopt(key = "raw_data_dir", value = rave_rawdir)

  # parallel computing
  max_cores <- min(asNamespace("parallel")$detectCores(), 12)
  ravepipeline$raveio_setopt(key = "max_worker", value = max_cores)

  # set 3D viewer
  rave_viewerdir <- tools::R_user_dir("threeBrain", "data")
  if (!dir.exists(rave_viewerdir)) { dir_create2(rave_viewerdir) }
  options('threeBrain.template_dir' = normalizePath(rave_viewerdir, winslash = "/"))

  if (auto_install) {
    for (subj in config$threeBrain$ensure_templates) {
      template_subjpath <- file.path(rave_viewerdir, subj)
      if (!dir.exists(template_subjpath)) {
        tryCatch({
          asNamespace('threeBrain')$download_template_subject(subject_code = subj, template_dir = rave_viewerdir)
        }, error = function(e) {})
      }
    }
  }

  # YAEL templates
  if (auto_install) {
    for (subj in config$rpyANTs$ensure_templates) {
      template_path <- file.path(tools::R_user_dir(package = "rpyANTs", which = "data"), "templates", subj)
      if (!dir.exists(template_path)) {
        tryCatch({
          asNamespace("rpyANTs")$ensure_template(subj)
        }, error = function(e) {})
      }
    }
  }

  # Modules & pipelines
  if (auto_install) {
    template_path <- ravepipeline$ravepipeline_data_dir("rave-pipelines")
    if (!dir.exists(template_path)) {
      ravepipeline$ravepipeline_finalize_installation(async = FALSE)
    }
  }

  ## Initialize RAVE
  if (!is_installed("rpymat")) {
    add_r_package("rpymat")
  }
  rpymat <- asNamespace("rpymat")
  if (!dir.exists(rpymat$env_path())) {
    tryCatch({
      configure_python(python_ver = config$conda$python)
    }, error = function(e) {})
  }
  rpymat$ensure_rpymat(verbose = FALSE)

  Sys.setenv(RAVE_INITIALIZED = "TRUE")


  cli <- asNamespace("cli")
  d <- cli$cli_div(theme = list(rule = list(
    color = "cyan",
    "line-type" = "double")))
  cli$cli_h1("{.pkg R} & {.pkg RAVE} paths")
  cli$cli_text("Library path: { .libPaths()[[1]] }")
  cli$cli_text("RAVE data directory root: { dirname(ravepipeline::raveio_getopt('raw_data_dir')) }")
  cli$cli_text("RAVE cache root: { ravecore::cache_root() }")
  cli$cli_h1("Functions to check/reset/update {.pkg RAVE}")
  cli$cli_li("  {.run ravemanager::version_info()}          - Check RAVE version")
  cli$cli_li("  {.run ravemanager::validate_python()}       - Check Python libraries")
  cli$cli_li("  {.run ravemanager::update_rave()}           - Update RAVE")
  cli$cli_li("  {.run ravemanager::configure_python()}      - Configure Python for RAVE")
  cli$cli_li("  {.run ravemanager::finalize_installation()} - Update templates & snippet code")
  cli$cli_li("  {.run ravecore::clear_cached_files()}       - Clear cache")
  cli$cli_h1("Quick start")
  cli$cli_li("{.run rave::start_rave(new=TRUE,as_job=FALSE)} - Start a new session")
  cli$cli_li("{.run rave::start_rave(as_job=FALSE)} - Start GUI (current console)")
  cli$cli_end(d)

}

