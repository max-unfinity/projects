FROM {base}:dev

ARG UID=1008
ARG GID=1008

COPY --from=helpers setup-devuser.sh /tmp/
RUN /tmp/setup-devuser.sh ${UID} ${GID} && rm /tmp/setup-devuser.sh

USER devuser
WORKDIR /home/devuser/{project-dir}

# Host auth state from the `home` build context (sync-needed paths are bind-mounted at runtime).
RUN mkdir -p /home/devuser/.claude
COPY --from=home --chown=${UID}:${GID} .claude/settings.json          /home/devuser/.claude/settings.json
COPY --from=home --chown=${UID}:${GID} .claude/statusline-command.sh  /home/devuser/.claude/statusline-command.sh
COPY --from=home --chown=${UID}:${GID} .claude/setup-claude-remote.sh /home/devuser/.claude/setup-claude-remote.sh
COPY --from=home --chown=${UID}:${GID} .claude/.credentials.json      /home/devuser/.claude/.credentials.json
RUN chmod 600 /home/devuser/.claude/.credentials.json

# <Install project dependencies here with cache mounts>

# Source baked for standalone use; volume mount overlays at runtime.
COPY --chown=${UID}:${GID} . .

# Do NOT build native extensions here — volume mount hides baked artifacts.
