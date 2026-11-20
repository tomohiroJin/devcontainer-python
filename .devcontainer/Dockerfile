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
        git \
        jq \
        less \
        make \
        nano \
        procps \
        tree \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY .devcontainer/shell/bashrc /etc/devcontainer/bashrc
COPY .devcontainer/shell/gitconfig /etc/gitconfig

# /commandhistory is the mount point of the shell-history volume. A new named
# volume copies this directory's ownership, so the non-root user can write to it.
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID --shell /bin/bash -m $USERNAME \
    && printf '\n# Dev Container shell settings (prompt, history, aliases).\n[ -r /etc/devcontainer/bashrc ] && . /etc/devcontainer/bashrc\n' >> /home/$USERNAME/.bashrc \
    && install -d -o $USERNAME -g $USERNAME /commandhistory

COPY requirements-bootstrap.txt requirements.txt /tmp/
RUN --mount=type=secret,id=proxy_ca \
    if [ -f /run/secrets/proxy_ca ]; then export PIP_CERT=/run/secrets/proxy_ca; fi; \
    python -m pip install --no-cache-dir --require-hashes --upgrade -r /tmp/requirements-bootstrap.txt \
    && python -m pip install --no-cache-dir --require-hashes --only-binary :all: -r /tmp/requirements.txt \
    && rm /tmp/requirements-bootstrap.txt /tmp/requirements.txt

USER $USERNAME
