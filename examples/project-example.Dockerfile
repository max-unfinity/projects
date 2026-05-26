FROM {base}:dev

ARG UID=1008
ARG GID=1008

COPY --from=helpers setup-devuser.sh /tmp/
RUN /tmp/setup-devuser.sh ${UID} ${GID} && rm /tmp/setup-devuser.sh

USER devuser
WORKDIR /home/devuser/{project-dir}

# <Install project dependencies here with cache mounts>

# Source can be baked for standalone use if required; volume mount overlays at runtime.
# COPY --chown=${UID}:${GID} . .

# Host auth state from the `home` build context (sync-needed paths are bind-mounted at runtime).
RUN mkdir -p /home/devuser/.claude
COPY --from=home --chown=${UID}:${GID} .claude/settings.json          /home/devuser/.claude/settings.json
RUN python -c "import json,pathlib;p=pathlib.Path('/home/devuser/.claude/settings.json');d=json.loads(p.read_text());d.pop('env',None);p.write_text(json.dumps(d,indent=2)+'\n')"
COPY --from=home --chown=${UID}:${GID} .claude/statusline-command.sh  /home/devuser/.claude/statusline-command.sh
COPY --from=home --chown=${UID}:${GID} .claude/setup-claude-remote.sh /home/devuser/.claude/setup-claude-remote.sh
COPY --from=home --chown=${UID}:${GID} .claude/.credentials.json      /home/devuser/.claude/.credentials.json
COPY --from=home --chown=${UID}:${GID} .claude.json                   /home/devuser/.claude.json
RUN chmod 600 /home/devuser/.claude/.credentials.json

# Do NOT build native extensions here — volume mount hides baked artifacts.
