#!/usr/bin/env bash

set -e

# inputs:
#   SSH_PASSWORD            direct value
#   SSH_PASSWORD_FILE       path to file containing password (Docker secret)
#   SSH_PASSWORD_GENERATE   if "1", generate a random password when none provided
# uses DEFAULT_USER from the image (you already define it)

: "${DEFAULT_USER:=raveuser}"
: "${SSH_PASSWORD_GENERATE:=1}"

# pick password source
pw="${SSH_PASSWORD:-}"
if [ -z "${pw}" ] && [ -n "${SSH_PASSWORD_FILE:-}" ] && [ -f "${SSH_PASSWORD_FILE}" ]; then
  pw="$(cat "${SSH_PASSWORD_FILE}")"
fi
if [ -z "${pw}" ] && [ "${SSH_PASSWORD_GENERATE:-0}" = "1" ]; then
  pw="$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 20)"
  echo "INFO: generated SSH password for ${DEFAULT_USER}: ${pw}"
fi
if [ -z "${pw}" ]; then
  echo "ERROR: no SSH password provided. Set SSH_PASSWORD, or SSH_PASSWORD_FILE, or SSH_PASSWORD_GENERATE=1."
  exit 1
fi

# ensure user exists (yours does already, but keep this safe)
if ! id -u "${DEFAULT_USER}" >/dev/null 2>&1; then
  useradd -m -s /bin/bash "${DEFAULT_USER}"
fi

echo "${DEFAULT_USER}:${pw}" | chpasswd

# harden a bit
passwd -l root >/dev/null 2>&1 || true

# host keys (idempotent)
ssh-keygen -A

# needed by sshd
mkdir -p /var/run/sshd

# start sshd (let it daemonize). If your distro's sshd doesn't daemonize,
# use the "nohup ... &" fallback below.
if command -v /usr/sbin/sshd >/dev/null 2>&1 ; then
  /usr/sbin/sshd -E /var/log/sshd.log || {
    # fallback: run in background via nohup if sshd refuses to daemonize
    nohup /usr/sbin/sshd -D > /var/log/sshd.log 2>&1 &
  }
else
  echo "ERROR: sshd not found" >&2
  exit 1
fi

# optional: follow sshd log in background for debugging (won't block)
[ -f /var/log/sshd.log ] && ( tail -n +1 -F /var/log/sshd.log 2>/dev/null & )

# drop to the default user for interactive shell.
if [ "$(id -u)" -eq 0 ]; then
  # use the DEFAULT_USER env var (set earlier in Dockerfile)
  exec su - "${DEFAULT_USER:-raveuser}" -s /bin/bash
else
  exec /bin/bash --login
fi

