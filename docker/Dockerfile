# syntax=docker/dockerfile:1

FROM rocker/r-ver:4

LABEL maintainer="RAVE Developers <help@rave.wiki>" \
  org.label-schema.license="GPL-3.0" \
  org.label-schema.vcs-url="https://rave.wiki" \
  org.label-schema.vendor="RAVE"

EXPOSE 22

# reserved for rstudio
EXPOSE 8787

# reserved for RAVE
EXPOSE 8788

# reserved for jupyter
EXPOSE 8789

# reserved
EXPOSE 8790

ARG DEBIAN_FRONTEND=noninteractive
ARG DEFAULT_USER=raveuser
ARG DEFAULT_UID=1000
ARG DEFAULT_GID=1000
ARG DEFAULT_GROUP=raveuser

COPY docker/Renviron.site /usr/local/lib/R/etc/Renviron.site
COPY docker/Rprofile.site /usr/local/lib/R/etc/RAVE.site
COPY --chmod=755 docker/pre-install.sh /usr/local/bin/pre-install.sh
COPY --chmod=600 docker/ssh_host_keys/ssh_host_* /etc/ssh/

RUN --mount=type=cache,id=apt-cache,target=/var/cache/apt \
    --mount=type=cache,id=r-cache,target=/root/.cache/R \
    /usr/local/bin/pre-install.sh

# Ensure sshd uses these specific keys
RUN echo "HostKey /etc/ssh/ssh_host_ed25519_key" >> /etc/ssh/sshd_config && \
    echo "HostKey /etc/ssh/ssh_host_rsa_key" >> /etc/ssh/sshd_config

USER ${DEFAULT_USER}

COPY --chmod=755 docker/install.sh /usr/local/bin/rave-install.sh
RUN /usr/local/bin/rave-install.sh

# Post install might be subject to change
COPY --chown=${DEFAULT_USER} --chmod=665 docker/configure.r /opt/shared/rave/etc/configure.r
COPY --chown=${DEFAULT_USER} --chmod=665 docker/startup.r /opt/shared/rave/etc/rave_profile.r
COPY --chmod=755 docker/post-install.sh /usr/local/bin/post-install.sh
RUN /usr/local/bin/post-install.sh

USER root

# boot script: sets password from env (or generates), then starts sshd
COPY --chmod=755 docker/boot-sshd.sh /usr/local/bin/boot-sshd.sh
CMD ["/usr/local/bin/boot-sshd.sh"]

# DOCKER_BUILDKIT=1 docker build --no-cache -t rave-local:dev -f docker/Dockerfile .

# docker run --rm -ti -p 2222:22 rave-local:dev bash
