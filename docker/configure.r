

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
  ),
  threeBrain = list(
    ensure_templates = c(
      "cvs_avg35_inMNI152"
      # "N27",
      # "fsaverage_inCIT168",
      # "fsaverage"
    )
  ),
  rpyANTs = list(
    ensure_templates = c(
      # "mni_icbm152_nlin_asym_09a",
      "mni_icbm152_nlin_asym_09b"
      # "fsaverage"
    )
  )
)



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

  ravepipeline$raveio_setopt(key = "threeBrain_template_subject", value = "cvs_avg35_inMNI152")


  # parallel computing
  # ravepipeline$raveio_setopt(key = "max_worker", value = parallel::detectCores())

  # set 3D viewer
  rave_viewerdir <- dir_create2(tools::R_user_dir("threeBrain", "data"))
  options('threeBrain.template_dir' = normalizePath(rave_viewerdir, winslash = "/"))

  config$threeBrain$ensure_templates <- unique(c(
    "cvs_avg35_inMNI152", config$threeBrain$ensure_templates))

  for(subj in config$threeBrain$ensure_templates) {
    template_subjpath <- file.path(rave_viewerdir, subj)
    if(!dir.exists(template_subjpath)) {
      asNamespace('threeBrain')$download_template_subject(subject_code = subj, template_dir = rave_viewerdir)
    }
  }

  # YAEL
  for(subj in config$rpyANTs$ensure_templates) {
    template_path <- file.path(tools::R_user_dir(package = "rpyANTs",
                                                 which = "data"), "templates", subj)
    if(!dir.exists(template_path)) {
      asNamespace("rpyANTs")$ensure_template(subj)
    }
  }
}

setup_rave(config)

# R -q -e "ravemanager::configure_python()"
# /opt/shared/rave/lib/conda/condabin/conda clean --all --yes

ravemanager::finalize_installation()
ravemanager:::pak_cache_remove()
pak::cache_clean()


# echo "source('/opt/shared/rave/etc/rave_profile.r')" >> $HOME/.Rprofile
writeLines("source('/opt/shared/rave/etc/rave_profile.r')", con = "~/.Rprofile")
