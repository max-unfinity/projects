#!/bin/sh
# Create a non-root devuser matched to host UID/GID, give it passwordless sudo,
# install apt/apt-get/dpkg auto-sudo wrappers, and (if present) hand /opt/venv
# to devuser so plain `pip install ...` works without sudo.
#
# Usage: setup-devuser.sh <UID> <GID>
set -eu
DEV_UID="${1:-1008}"
DEV_GID="${2:-1008}"

groupadd -g "$DEV_GID" devuser
useradd -m -u "$DEV_UID" -g "$DEV_GID" -s /bin/bash devuser
echo "devuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/devuser
chmod 0440 /etc/sudoers.d/devuser

for c in apt apt-get dpkg; do
  printf '#!/bin/sh\nexec sudo /usr/bin/%s "$@"\n' "$c" > /usr/local/bin/$c
  chmod +x /usr/local/bin/$c
done

# Hand the inherited Python venv to devuser. Guard makes the script reusable
# for non-Python bases that don't ship /opt/venv — they should chown their own
# toolchain root after invoking this script.
if [ -d /opt/venv ]; then
  find /opt/venv -type d -exec chown "$DEV_UID:$DEV_GID" {} +
fi
