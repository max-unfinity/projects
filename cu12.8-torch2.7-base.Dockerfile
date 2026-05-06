FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive

# System deps — cache apt archives across base rebuilds
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        python3.10 \
        python3.10-dev \
        python3.10-venv \
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

# Project-writable venv at /opt/venv — base deps go here, projects extend it
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:${PATH}"

# Torch — pip cache mount keeps the wheel cache outside the image
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --upgrade setuptools==80.10.2 wheel \
 && pip install \
        torch==2.7.1 \
        torchvision==0.22.1 \
        --index-url https://download.pytorch.org/whl/cu128 \
   && du -sh /root/.cache/pip /root/.cache/pip/http* 2>/dev/null || true

ENV TORCH_CUDA_ARCH_LIST="8.0 8.6 8.9 9.0 12.0+PTX"
