FROM nvidia/cuda:13.2.0-cudnn-devel-ubuntu24.04

ENV DEBIAN_FRONTEND=noninteractive

# System deps — cache apt archives across base rebuilds
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        software-properties-common \
    && add-apt-repository -y ppa:deadsnakes/ppa \
    && apt-get update && apt-get install -y --no-install-recommends \
        python3.10 \
        python3.10-dev \
        python3.10-venv \
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

# pip — not bundled with deadsnakes python3.10
RUN curl -fsSL https://bootstrap.pypa.io/get-pip.py | python

# Project-writable venv at /opt/venv — base deps go here, projects extend it
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:${PATH}"

# Torch — pip cache mount keeps the wheel cache outside the image
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --upgrade pip setuptools==80.10.2 wheel \
 && pip install \
        torch==2.12.0 \
        torchvision==0.27.0 \
        torchaudio==2.11.0 \
        --index-url https://download.pytorch.org/whl/cu130 \
        --extra-index-url https://pypi.org/simple \
   && du -sh /root/.cache/pip /root/.cache/pip/http* 2>/dev/null || true

ENV TORCH_CUDA_ARCH_LIST="8.0 8.6 8.9 9.0 12.0+PTX"
