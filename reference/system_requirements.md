# Get system requirements for 'RAVE'

Get system requirements for 'RAVE'

## Usage

``` r
system_requirements(
  os = NULL,
  os_release = NULL,
  curl = Sys.which("curl"),
  sudo = FALSE,
  ...
)
```

## Arguments

- os, os_release:

  operating system and release version, currently only supports
  `'ubuntu'`, `'centos'`, `'redhat'`, `'opensuse'`, and `'sle'`; see
  <https://github.com/rstudio/r-system-requirements#operating-systems>

- curl:

  the location of the curl binary on your system

- sudo:

  whether to pre-pend `'sudo'` to the commands

- ...:

  reserved for future use

## Examples

``` r

if("remotes" %in% loadedNamespaces()) {
# Please check your operating system & version!!!

# =============== On Ubuntu Linux ===============

# Ubuntu 20
ravemanager::system_requirements("ubuntu", "20")

# Ubuntu 18
ravemanager::system_requirements("ubuntu", "18")

# Ubuntu 16
ravemanager::system_requirements("ubuntu", "16")

# =============== On Red Hat Enterprise Linux ===============

# Red Hat Enterprise Linux 8
ravemanager::system_requirements("redhat", "8")

# Red Hat Enterprise Linux 7
ravemanager::system_requirements("redhat", "7")

# =============== On CentOS ===============

# Red Hat Enterprise Linux 8
ravemanager::system_requirements("centos", "8")

# Red Hat Enterprise Linux 7
ravemanager::system_requirements("centos", "7")

# =============== On OpenSUSE ===============

# openSUSE 42.3
ravemanager::system_requirements("opensuse", "42")

# =============== On SUSE Linux Enterprise ===============

# SUSE Linux Enterprise 12.3
ravemanager::system_requirements("sle", "12")

}

```
