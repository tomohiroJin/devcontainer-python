# syntax=docker/dockerfile:1
FROM python:3.15.2-slim-trixie@sha256:65a65fc7b30b06cb6df4930fd4650697cb23f4c2698ab81fc87e4b031bc36928

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# C.UTF-8 ships with glibc, so Japanese text works without the locales package.
ENV LANG=C.UTF-8 \
    LESSCHARSET=utf-8

# Selection criteria and the reason for each package are in the README.
RUN apt-get update \
    && apt-get upgrade -y --no-install-recommends \
    && apt-get install -y --no-install-recommends \
        bash-completion \
        ca-certificates \
        curl \
        gh \
        git \
        jq \
        less \
        make \
        nano \
        openssh-client \
        procps \
        tree \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY .devcontainer/shell/bashrc /etc/devcontainer/bashrc
COPY .devcontainer/shell/gitconfig /etc/gitconfig
# github.com host keys: no trust-on-first-use prompt, and no silent acceptance
# of another key. Keys of other hosts go to the user's ~/.ssh/known_hosts.
COPY --chmod=644 .devcontainer/ssh/ssh_known_hosts /etc/ssh/ssh_known_hosts

# /commandhistory is the mount point of the shell-history volume. A new named
# volume copies this directory's mode. It is world-writable with the sticky bit
# (like /tmp) because Dev Containers may change the user's UID to match the
# host, and that change only re-owns the home directory.
# Debian's ~/.profile would put ~/.local/bin in front of PATH in login shells;
# that block is removed because ENV PATH below adds the directory at the end.
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID --shell /bin/bash -m $USERNAME \
    && printf '\n# Dev Container shell settings (prompt, history, aliases).\n[ -r /etc/devcontainer/bashrc ] && . /etc/devcontainer/bashrc\n' >> /home/$USERNAME/.bashrc \
    && sed -i '/^if \[ -d "\$HOME\/\.local\/bin" \] ; then$/,/^fi$/d' /home/$USERNAME/.profile \
    && ! grep -q '\.local/bin' /home/$USERNAME/.profile \
    && install -d -m 1777 /commandhistory

# `pip install` as the non-root user puts commands in ~/.local/bin. Debian adds
# that directory to PATH only in login shells (~/.profile), and only when it
# already exists, so a VS Code terminal would not find those commands.
# It goes last: a command of the same name there (for example the `ptw` of the
# unmaintained pytest-watch) must not replace a pinned tool of the image.
ENV PATH=$PATH:/home/$USERNAME/.local/bin

COPY requirements-bootstrap.txt requirements.txt /tmp/
RUN --mount=type=secret,id=proxy_ca \
    if [ -f /run/secrets/proxy_ca ]; then export PIP_CERT=/run/secrets/proxy_ca; fi; \
    python -m pip install --no-cache-dir --require-hashes --upgrade -r /tmp/requirements-bootstrap.txt \
    && python -m pip install --no-cache-dir --require-hashes --only-binary :all: -r /tmp/requirements.txt \
    && rm /tmp/requirements-bootstrap.txt /tmp/requirements.txt

USER $USERNAME
