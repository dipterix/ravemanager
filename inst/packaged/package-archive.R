#' Script to package RAVE, and all the source packages to ravemanager
#' `inst/packaged` for redistribution purposes.

setwd(rstudioapi::getActiveProject())
packaged_dir <- "inst/packaged"
repos_dir <- file.path(packaged_dir, "repository")

platforms <- c(
  'source'
  # 'x86_64-apple-darwin17.0',
  # "aarch64-apple-darwin20",
  # "x86_64-w64-mingw32",
  # 'x86_64-pc-linux-gnu-debian-10',
  # 'x86_64-pc-linux-musl-alpine-3.14.1⁠',
  # 's390x-ibm-linux-gnu-ubuntu-20.04',
  # 'amd64-portbld-freebsd12.1',
  # 'x86_64-pc-linux-gnu-unknown'
)

pak::repo_add(`rave-ieeg` = "https://rave-ieeg.r-universe.dev")
pak::pkg_download(
  c("ravebuiltins", "rutabaga", "ravemanager", "remotes",
    "pak", "zoo", "lmtest", pak:::extra_packages(),
    ravemanager:::rave_depends,
    ravemanager:::rave_packages,
    ravemanager:::rave_suggests),
  dest_dir = repos_dir,
  dependencies = TRUE,
  platforms = 'source'
)

# ignore the warnings
tools::write_PACKAGES(file.path(repos_dir, "src/contrib/"))

# package the rave-gist
utils::download.file(
  "https://github.com/rave-ieeg/rave-gists/archive/refs/heads/main.zip",
  destfile = file.path(packaged_dir, "rave-gist.zip"))

# rave-pipeline
utils::download.file(
  "https://github.com/rave-ieeg/rave-pipelines/archive/refs/heads/main.zip",
  destfile = file.path(packaged_dir, "rave-pipelines.zip"))

# threeBrain templates (N27, cvs)
threeBrain_template_path <- threeBrain::default_template_directory()
for(template in c("N27", "fsaverage", "cvs_avg35_inMNI152")) {
  template_zipname <- sprintf("%s_fs.zip", template)
  template_zip <- file.path(threeBrain_template_path, template_zipname)
  if(!file.exists(template_zip)) {
    threeBrain::download_template_subject(template)
  }
  file.copy(template_zip, file.path(packaged_dir, template_zipname), overwrite = TRUE)
}
