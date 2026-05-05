FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive

# System deps — cache apt archives across base rebuilds
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        python3.10 \
        python3.10-dev \
        python3-pip \
        sudo \
        git \
        curl \
        wget \
        ffmpeg \
        libgl1 \
        libglib2.0-0 \
        libsm6 \
        libxext6 \
        libxrender-dev \
        libmagic-dev \
        libexiv2-dev \
        libgomp1 \
    && ln -sf /usr/bin/python3.10 /usr/bin/python3 \
    && ln -sf /usr/bin/python3 /usr/bin/python \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Torch — pip cache mount keeps the wheel cache outside the image
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install \
        torch==2.7.1 \
        torchvision==0.22.1 \
        --index-url https://download.pytorch.org/whl/cu128

# Non-root devuser with passwordless sudo, matching host UID/GID (baked at base build)
ARG UID=1008
ARG GID=1008
RUN groupadd -g ${GID} devuser \
 && useradd -m -u ${UID} -g ${GID} -s /bin/bash devuser \
 && echo "devuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/devuser \
 && chmod 0440 /etc/sudoers.d/devuser

# Transparent sudo wrappers: `apt`, `apt-get`, `dpkg` run as root without explicit sudo
RUN for c in apt apt-get dpkg; do \
      printf '#!/bin/sh\nexec sudo /usr/bin/%s "$@"\n' "$c" > /usr/local/bin/$c \
      && chmod +x /usr/local/bin/$c; \
    done

USER devuser
ENV PATH=/home/devuser/.local/bin:${PATH}

# Default pip to user installs so `pip install foo` always works without sudo
RUN mkdir -p /home/devuser/.config/pip \
 && printf '[install]\nuser = true\n' > /home/devuser/.config/pip/pip.conf
