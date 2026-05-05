## Adapting to non-Python stacks

The pattern generalises: the **base** installs the toolchain at a system path (so it survives home-dir mounts) and puts that path on `PATH`; the **project** creates devuser, installs the sudo wrappers, and `chown`s the toolchain root so devuser can write to it.

When creating a new base for a different stack (Node, Rust, Go, …), copy the closest existing base and swap **only** the toolchain install + the `PATH` line. The devuser/sudo-wrapper block stays in the project Dockerfile (identical across stacks) — only the `chown` target changes.

**pip**
- Base toolchain root: venv at `/opt/venv` (already on `PATH`).
- Project chowns: `/opt/venv`.
- Cache mount target: `/home/devuser/.cache/pip`.

**npm**
- Base toolchain root: `/opt/npm-global`, set via `npm config set prefix /opt/npm-global -g`; add `/opt/npm-global/bin` to `PATH`.
- Project chowns: `/opt/npm-global`.
- Cache mount target: `/home/devuser/.npm`.

**yarn**
- Base toolchain root: `/opt/yarn-global`, set via `yarn config set prefix /opt/yarn-global`; add `/opt/yarn-global/bin` to `PATH`.
- Project chowns: `/opt/yarn-global`.
- Cache mount target: `/home/devuser/.cache/yarn` (v1) or `/home/devuser/.yarn/berry/cache` (v2+).

**pnpm**
- Base toolchain root: `/opt/pnpm-global`, set via `pnpm config set global-bin-dir /opt/pnpm-global/bin`; add `/opt/pnpm-global/bin` to `PATH`.
- Project chowns: `/opt/pnpm-global`.
- Cache mount target: `/home/devuser/.local/share/pnpm/store`.
