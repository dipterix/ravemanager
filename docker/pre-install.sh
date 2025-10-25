#! /bin/bash
# Save to /usr/local/bin/

set -e

UNAME_M="$(uname -m)"
case "$UNAME_M" in
  x86_64)  ARCH="x86_64" ;;
  aarch64) ARCH="aarch64" ;;
  *) echo "Unsupported arch: $UNAME_M" >&2; exit 1 ;;
esac;

apt-get update -qq
apt-get install -y --no-install-recommends \
    acl bzip2 ca-certificates curl file git gnupg dirmngr locales tzdata \
    build-essential gfortran libcurl4-openssl-dev libjpeg-dev libpng-dev \
    libssl-dev libxml2-dev libgit2-dev zlib1g-dev \
    openssh-server openssh-client pandoc psmisc procps wget software-properties-common sudo

# Create non-root user and group
groupadd -g ${DEFAULT_GID} ${DEFAULT_GROUP} && \
    useradd -m -u ${DEFAULT_UID} -g ${DEFAULT_GROUP} -s /bin/bash ${DEFAULT_USER} && \
    echo "${DEFAULT_USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${DEFAULT_USER} && \
    chmod 0440 /etc/sudoers.d/${DEFAULT_USER}

# SSH server setup
mkdir -p /var/run/sshd && \
    sed -ri 's/^#?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    sed -ri 's|^#?PermitRootLogin .*|PermitRootLogin no|' /etc/ssh/sshd_config && \
    sed -i 's/^#\?UsePAM .*/UsePAM yes/' /etc/ssh/sshd_config

mkdir -p /etc/ssh/sshd_config.d
cat >/etc/ssh/sshd_config.d/99-password.conf <<EOF
PasswordAuthentication yes
KbdInteractiveAuthentication yes
UsePAM yes
# Ensure we do NOT require publickey
AuthenticationMethods any
EOF

echo "HostKey /etc/ssh/ssh_host_ed25519_key" >> /etc/ssh/sshd_config && \
echo "HostKey /etc/ssh/ssh_host_rsa_key" >> /etc/ssh/sshd_config

# Prepare SSH directory
mkdir -p /home/${DEFAULT_USER}/.ssh && \
    chmod 700 /home/${DEFAULT_USER}/.ssh && \
    chown -R ${DEFAULT_UID}:${DEFAULT_GID} /home/${DEFAULT_USER}

# Set up RAVE folder
mkdir -p /opt/shared/rave
chown -R ${DEFAULT_USER}:${DEFAULT_GROUP} /opt/shared/rave
setfacl -R -d -m g::rwx -m o::rx -m mask::rwx /opt/shared/rave
chmod -R 2775 /opt/shared/rave
mkdir -p /opt/shared/rave/lib/R
mkdir -p /opt/shared/rave/data
mkdir -p /opt/shared/rave/shared
mkdir -p /opt/shared/rave/etc
mkdir -p /opt/shared/rave/bin
chmod -R g+rwXs /opt/shared/rave/lib
chmod -R g+rwXs /opt/shared/rave/bin

# Inject RAVE Startup script
echo "source('/usr/local/lib/R/etc/RAVE.site')" >> /usr/local/lib/R/etc/Rprofile.site

# Install conda
CONDA_PREFIX=/opt/shared/rave/lib/conda
CONDA_BIN="$CONDA_PREFIX/condabin/conda"
if [ -x "$CONDA_BIN" ]; then
    echo "✅ Conda already exists at $CONDA_BIN — skipping installation.";
else
    echo "⚙️ Installing Miniforge3...";
    mkdir -p "$(dirname "$CONDA_PREFIX")";
    rm -rf "$CONDA_PREFIX";
    curl -fsSL -o /tmp/miniforge.sh "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-${ARCH}.sh"
    bash /tmp/miniforge.sh -b -p /opt/shared/rave/lib/conda
    rm -f /tmp/miniforge.sh
fi
${CONDA_BIN} clean --all --yes

# Install package pak so the packages can be installed easier & faster
install2.r --error --skipinstalled --deps FALSE pak

# Install ravemanager
R -q -e "pak::pak_install_extra()"
R -q -e "pak::pak('dipterix/ravemanager')"

# Let ravemanager automatically determine the system requirements to install
R -q -e "writeLines(ravemanager::system_requirements(), '/usr/local/bin/install_sysreqs.sh')"

# Install extra system requirements
chmod +x /usr/local/bin/install_sysreqs.sh
bash /usr/local/bin/install_sysreqs.sh

chown -R ${DEFAULT_USER}:${DEFAULT_GROUP} /opt/shared/rave/lib

# pak::repo_add(pak::repo_resolve('PPM@latest'));
# Clean up
R -q -e "pak::cache_clean(); ravemanager:::pak_cache_remove()"
rm -rf /var/lib/apt/lists/*
rm -rf /opt/shared/rave/etc/*
rm -rf /tmp/*
