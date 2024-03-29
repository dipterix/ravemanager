#!/bin/bash

set -u

SYSREQ="1"
while getopts ":s:" opt; do
  case $opt in
    s)
      SYSREQ="$OPTARG"
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

# SCRIPT_DIR=$(dirname "$0")
#
# # Load installer commons
# . "${SCRIPT_DIR}/installer-common.sh"

UNAME_MACHINE="$(/usr/bin/uname -m)"
if [[ "$UNAME_MACHINE" == "arm64" ]]; then
  # On ARM macOS, this script installs to /opt/homebrew only
  HOMEBREW_PREFIX="/opt/homebrew"
  HOMEBREW_REPOSITORY="${HOMEBREW_PREFIX}"
else
  # On Intel macOS, this script installs to /usr/local only
  HOMEBREW_PREFIX="/usr/local"
  HOMEBREW_REPOSITORY="${HOMEBREW_PREFIX}/Homebrew"
fi

if [ "${SYSREQ}" == "2" ]; then
  ohai "Checking sudo access (may require your password): "
  have_sudo_access true

  # Install brew
  execute_sudo echo | /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi




# Add brew to zsh (z-shell), bash, and sh
# execute echo "eval \"\$($HOMEBREW_PREFIX/bin/brew shellenv)\"" >> "$HOME/.zprofile"
# execute echo "eval \"\$($HOMEBREW_PREFIX/bin/brew shellenv)\"" >> "$HOME/.bash_profile"
# execute echo "eval \"\$($HOMEBREW_PREFIX/bin/brew shellenv)\"" >> "$HOME/.profile"
# Activate brew
eval "$($HOMEBREW_PREFIX/bin/brew shellenv)"

execute $HOMEBREW_PREFIX/bin/brew install hdf5 fftw libgit2 libxml2 pkg-config libjpeg libpng libtiff cmake
