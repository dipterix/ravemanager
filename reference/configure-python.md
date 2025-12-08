# Install & Configure 'python' environment for 'RAVE'

Installs 'python' environment for 'RAVE'

## Usage

``` r
validate_python(verbose = TRUE, env_name = NA)

configure_antspynet()

configure_python(python_ver = "3.11", verbose = TRUE)

remove_conda(ask = TRUE)

ensure_rpymat(env_name = NA)
```

## Arguments

- verbose:

  whether to verbose messages

- env_name:

  'conda' environment to use; set to `NA` to verify the default
  environment

- python_ver:

  python version; default is automatically determined. If a specific
  python version is needed, please specify explicitly, for example,
  `python_ver='3.8'`

- ask:

  whether to ask before resetting the 'python' environment

## Details

Use `ravemanager::configure_python()` to install and configure python
environment using `miniconda`. The `conda` binary and environment will
be completely isolated. This means the installation will be safe and it
will not affect any existing configurations on the computer.

In this isolated environment, the following packages will be installed:
`numpy`, `scipy`, `pandas`, `h5py`, `jupyterlab`, `pynwb`, `mat73`,
`mne`. You can always add more `conda` packages via
`rpymat::add_packages(...)` or `pip` packages via
`rpymat::add_packages(..., pip = TRUE)`.

To use the 'python' environment, please run `rpymat::ensure_rpymat()` to
activate in your current session. If you are running via `'RStudio'`,
open any 'python' script and use `'ctrl/cmd+enter'` to run line-by-line.
To switch from `R` to `python` mode, using command
`rpymat::repl_python()`

A `jupyterlab` will be automatically installed during the configuration.
To launch the `jupyterlab`, use `rpymat::jupyter_launch()`

If you want to remove this `conda` environment, use R command
`rpymat::remove_conda()`. This procedure is absolutely safe and will not
affect your other installations.

## Examples

``` r
if (FALSE) { # \dontrun{

# -------- Install & Configure python environment for RAVE --------
ravemanager::configure_python()

# Add conda packages
rpymat::add_packages("numpy")

# Add pip packages
rpymat::add_packages("nipy", pip = TRUE)

# -------- Activate RAVE-python environment --------
rpymat::ensure_rpymat()

# run script from a temporary file
f <- tempfile(fileext = ".py")
writeLines(c(
  "import numpy",
  "print(f'numpy installed: {numpy.__version__}')"
), f)
rpymat::run_script(f)

# run terminal command within the environment
rpymat::run_command("pip list")

# run python interactively, remember to use `exit` to exit
# python mode
rpymat::repl_python()



} # }
```
