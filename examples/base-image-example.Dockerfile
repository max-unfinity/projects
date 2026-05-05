FROM <base-image>

ENV DEBIAN_FRONTEND=noninteractive

# System deps
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
        python3.10 \
        python3.10-dev \
        python3-pip \
    && ln -sf /usr/bin/python3.10 /usr/bin/python3 \
    && ln -sf /usr/bin/python3 /usr/bin/python \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Toolchain example
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install torch==2.7.1 torchvision==0.22.1 --index-url https://download.pytorch.org/whl/cu128

# Non-root devuser with passwordless sudo, matching host UID/GID
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

# Default the language package manager to user-mode installs (pip shown here)
RUN mkdir -p /home/devuser/.config/pip \
 && printf '[install]\nuser = true\n' > /home/devuser/.config/pip/pip.conf
