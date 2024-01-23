#!/bin/bash

set -u

SCRIPT_DIR=$(dirname "$0")
OS_TYPE=$(/usr/bin/uname)
R_CMD=$(/usr/bin/which Rscript)
SYSREQ="1"

while getopts ":s:r:" opt; do
  case $opt in
    s)
      SYSREQ="$OPTARG"
      ;;
    r)
      R_CMD="$OPTARG"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

# Load installer commons
. "${SCRIPT_DIR}/shell/installer-common.sh"
ohai "Operating System: ${OS_TYPE}"
ohai "R binary path: ${R_CMD}"

if [ "${SYSREQ}" == "1" ]; then
  if [ "$OS_TYPE" == "Darwin" ]; then
      ohai "Operating System: macOS"
      . "${SCRIPT_DIR}/shell/installer-prerequisites-osx.sh"
  elif [ "$OS_TYPE" == "Linux" ]; then
      ohai "Operating System: Linux"
      # . "${SCRIPT_DIR}/shell/installer-prerequisites-linux.sh"
  fi
else
  ohai "Skipping system requisites"
fi


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



