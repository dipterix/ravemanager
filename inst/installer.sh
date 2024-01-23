#!/bin/bash

set -u

SCRIPT_DIR=$(dirname "$0")
OS_TYPE=$(/usr/bin/uname)
R_CMD=$(/usr/bin/which Rscript || echo "Rscript")

# 0 no install; 1 assuming no sudo access; 2 have sudo
SYSREQ="1"

# remove already installed; for debug & test use
RM_INSTALLED="0"

while getopts ":s:r:c:" opt; do
  case $opt in
    s)
      SYSREQ="$OPTARG"
      ;;
    r)
      R_CMD="$OPTARG"
      ;;
    c)
      RM_INSTALLED="1"
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

if [ "${RM_INSTALLED}" == "1" ]; then
  cmd_str="
if( system.file(package = 'ravemanager') != '' ) {
  loadNamespace('ravemanager')
}
ravemanager::uninstall('all')
"
  ohai "Running R command: ${cmd_str}"
  ${R_CMD} --no-save --no-restore -e "${cmd_str}"
  rm -rf "$lib_path"
fi

mkdir -p "$lib_path"


cmd_str="
lib_path <- '$lib_path'
if( system.file(package = 'ravemanager', lib.loc = lib_path) == '' ) {
  install.packages('ravemanager', repos = 'https://rave-ieeg.r-universe.dev', lib = lib_path)
}
loadNamespace('ravemanager', lib.loc = lib_path)
ravemanager::install(allow_cache = FALSE, python = TRUE)
"
ohai "Running R command: ${cmd_str}"
${R_CMD} --no-save --no-restore -e "${cmd_str}"

ohai "Check python loading"

execute ${R_CMD} --no-save --no-restore -e "rpyANTs::load_ants()"

