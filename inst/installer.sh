#!/bin/bash

set -e
set -u

SCRIPT_DIR=$(dirname "$0")
R_CMD=$(which Rscript || echo $1)
OS_TYPE=$(/usr/bin/uname)

if [ "$2" == "--skip-sysreq" ]; then
  echo "Skipping system requisites"
elif [ "$OS_TYPE" == "Darwin" ]; then
    echo "Operating System: macOS"
    . "${SCRIPT_DIR}/shell/installer-prerequisites-osx.sh"
elif [ "$OS_TYPE" == "Linux" ]; then
    echo "Operating System: Linux"
    # . "${SCRIPT_DIR}/shell/installer-prerequisites-linux.sh"
fi


# Load installer commons
. "${SCRIPT_DIR}/shell/installer-common.sh"


ohai "Operating System: ${OS_TYPE}"
ohai "R binary path: ${R_CMD}"


# Create a temporary directory
tmpdir=$(mktemp -d -t "rave-installer")
cd "${tmpdir}"

ohai "Current directory: ${tmpdir}"

# Install ravemanager
lib_path=$(${R_CMD} --no-save --no-restore -e 'cat(Sys.getenv("RAVE_LIB_PATH", unset = Sys.getenv("R_LIBS_USER", unset = .libPaths()[[1]])))')

ohai "R Library path: $lib_path"

mkdir -p "$lib_path"


cmd_str="
lib_path <- '$lib_path'
if( system.file(package = 'ravemanager', lib.loc = lib_path) == '' ) {
  install.packages('ravemanager', repos = 'https://rave-ieeg.r-universe.dev', lib = lib_path)
}
loadNamespace('ravemanager', lib.loc = lib_path)
ravemanager::install(allow_cache = FALSE)
"
ohai "Running R command: ${cmd_str}"
${R_CMD} --no-save --no-restore -e "${cmd_str}"



