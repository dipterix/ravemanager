#' Update RAVE from the local source for users without internet access

# ---- Global variables: please carefully read and set -------------------------

# Please set the ravemanager.Rproj path
ravemanager_rproj_path <- "./ravemanager.Rproj"

# How many cores to use when installing packages; recommended 1 for
# troubleshooting and 4 for parallel installation
ncpu <- 1


# ---- Update: assuming you have RAVE installed --------------------------------
# set paths
ravemanager_rproj_path <- normalizePath(ravemanager_rproj_path, winslash = "/", mustWork = TRUE)
ravemanager_path <- dirname(ravemanager_rproj_path)
packaged_path <- file.path(ravemanager_path, "inst/packaged", fsep = "/")
repos_path <- normalizePath(file.path(packaged_path, "repository"), mustWork = TRUE, winslash = "/")

# For installing from local repository
CRANLocal <- sprintf("file://%s", repos_path)

# Update repository registry (optional)
# tools::write_PACKAGES(file.path(repos_path, "src/contrib/"))

# For installing RAVE, there are some system dependencies. you might need to
# sort them out depending on the operating systems
# install.packages("ravemanager", type = "source", repos = CRANLocal)
# install.packages("pak", type = "source", repos = CRANLocal)
# # brew install libpng
# # download and compile https://mac.r-project.org/src/freetype-2.10.0.tar.bz2
# install.packages("systemfonts", type = "source", repos = CRANLocal)
# install.packages("hdf5r", type = "source", repos = CRANLocal)
# # brew install nlopt hdf5@10.0
# install.packages("nloptr", type = "source", repos = CRANLocal)
#
# install.packages("ragg", type = "source", repos = CRANLocal)
#
# install.packages("devtools", type = "source", repos = CRANLocal)

# Make sure the pipeline dependencies are installed
pipeline_deps <- ravemanager:::rave_suggests
pipeline_deps <- pipeline_deps[!pipeline_deps %in% utils::installed.packages()[,1]]
pkgs_to_install <- unique(c(
  "ravemanager",
  ravemanager:::rave_depends,
  ravemanager:::rave_packages,
  pipeline_deps
))

# update RAVE (only hard-dependencies)
install.packages(pkgs_to_install, type = "source", repos = CRANLocal, Ncpus = ncpu)

# Update snippets
raveio::install_snippet(file.path(packaged_path, "rave-gist.zip"))

# Update pipelines
tmpdir <- tempfile()
utils::unzip(zipfile = file.path(packaged_path, "rave-pipelines.zip"), overwrite = TRUE, exdir = tmpdir)
raveio::pipeline_install_local(file.path(tmpdir, "rave-pipelines-main/"))

#' What's next?
#' Unzip ravemanager/inst/packaged/xxx_fs.zip to
#' `threeBrain::default_template_directory()` to update template brain
#'
#' * This is optional if you already have the template brains

