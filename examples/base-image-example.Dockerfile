FROM <base-image>

ENV TORCH_CUDA_ARCH_LIST="8.0 8.6 8.9 9.0 12.0+PTX"
ENV DEBIAN_FRONTEND=noninteractive

# System deps
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
        python3.10 \
        python3.10-dev \
        python3.10-venv \
        python3-pip \
        sudo \
    && ln -sf /usr/bin/python3.10 /usr/bin/python3 \
    && ln -sf /usr/bin/python3 /usr/bin/python \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Project-writable venv at /opt/venv
RUN python3.10 -m venv /opt/venv
ENV PATH="/opt/venv/bin:${PATH}"

# Toolchain example: base Python deps with pip cache mount
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --upgrade setuptools==80.10.2 wheel \
 && pip install torch==2.7.1 torchvision==0.22.1 --index-url https://download.pytorch.org/whl/cu128
