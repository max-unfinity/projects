FROM {base}:dev

# UID/GID come from compose build.args; needed so the cache mount is owned by devuser
ARG UID=1008
ARG GID=1008

WORKDIR /home/devuser/{project-repo}

# System deps — `apt-get` is wrapped to auto-sudo, so no `sudo` prefix needed
RUN apt-get update && apt-get install -y --no-install-recommends ffmpeg

# Python deps — manifest before source so this layer is cached across source edits
COPY --chown=${UID}:${GID} pyproject.toml ./
RUN --mount=type=cache,target=/home/devuser/.cache/pip,uid=${UID},gid=${GID} \
    pip install -e ".[dev]"

COPY --chown=${UID}:${GID} . .
