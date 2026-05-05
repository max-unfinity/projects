FROM {base}:dev

# Come from compose build.args, matched to the host user
ARG UID=1008
ARG GID=1008

# Devuser, sudo wrappers, and venv ownership all set up by the shared script.
# `helpers` is the additional build context wired in docker-compose.yml.
COPY --from=helpers setup-devuser.sh /tmp/
RUN /tmp/setup-devuser.sh ${UID} ${GID} && rm /tmp/setup-devuser.sh

USER devuser
WORKDIR /home/devuser/{project-dir}

# <Install project dependencies here with cache mounts>
