# syntax=docker/dockerfile:1
FROM python:3.15.2-slim-trixie@sha256:65a65fc7b30b06cb6df4930fd4650697cb23f4c2698ab81fc87e4b031bc36928

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN apt-get update \
    && apt-get upgrade -y --no-install-recommends \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME

COPY requirements-bootstrap.txt requirements.txt /tmp/
RUN --mount=type=secret,id=proxy_ca \
    if [ -f /run/secrets/proxy_ca ]; then export PIP_CERT=/run/secrets/proxy_ca; fi; \
    python -m pip install --no-cache-dir --require-hashes --upgrade -r /tmp/requirements-bootstrap.txt \
    && python -m pip install --no-cache-dir --require-hashes -r /tmp/requirements.txt \
    && rm /tmp/requirements-bootstrap.txt /tmp/requirements.txt

USER $USERNAME
