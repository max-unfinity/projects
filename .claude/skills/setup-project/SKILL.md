---
name: setup-project
description: Set up a 3rd-party GitHub project for local development.
argument-hint: <github-url-or-repo-name>
disable-model-invocation: true
model: opus
effort: xhigh
allowed-tools: Bash Read Write Edit WebFetch WebSearch Grep Glob
---

## Context

The skill assumes the current working directory is the parent "projects" directory that holds all base `*.Dockerfile`s and where each cloned project lives as a subdirectory.

### Available base images

!`ls ./*.Dockerfile -1 | sort`

### Example docker-compose

!`cat ./examples/docker-compose-example.yml`

### Example project Dockerfile (FROM a base)

!`cat ./examples/project-example.Dockerfile`

### Example base-image Dockerfile (minimal skeleton)

Reference: `./examples/base-image-example.Dockerfile` — read it on demand whenever the task touches a base image.

### Required dev packages / libs

Reference: `./include.md` — the canonical list of extra packages, CLIs, and libraries that must be installed inside every project Dockerfile. Read it during step 3.

---

## Task: set up the requested project

### 1 — Clone

If the input is ambiguous (short name, multiple matches), confirm with the user before cloning.

Clone into `./{repo_name}/` (relative to CWD). Use the URL's final path segment (no `.git`) as `{repo_name}` throughout.

### 2 — Select base image

Base images follow the naming convention shown above (e.g. `cu12.4-torch2.5-base`). The local tag is always `{base_name}:dev`.

**Prefer an existing image.** Compatibility rules:
- Accelerator libs (CUDA, ROCm, etc.) are forward-compatible within a major version.
- Framework versions (torch, jax, tf) are generally forward-compatible; only reject if the project hard-requires an older major version.

**Create a new base only as a last resort** — model it on the Example base-image Dockerfile reference (or the closest existing one), adjust versions, keep the naming convention, and explain why no existing image fit. New base Dockerfiles live in CWD as `./{name}-base.Dockerfile`.

Check if the chosen image is built (`docker image ls | grep {base_name}`); build it from CWD if not. The base has no user concept — it's a pure tooling layer — so no UID/GID build args are needed.

### 3 — Write the Dockerfile

Create `./{repo_name}/Dockerfile` modelled on the example project Dockerfile above.

Before writing, read `./include.md` and ensure every package/CLI/library listed there is installed in the project Dockerfile (in addition to whatever the project itself needs). Use the appropriate install path: `apt`/`apt-get` for system libs, the language manager for CLI tools (e.g. `pip install`, `npm i -g`), and the documented installer for anything else. If something in `include.md` is already provided by the chosen base image, skip it.

Key practices (non-obvious ones):
- **Use the shared `setup-devuser.sh` helper.** All devuser/sudo-wrapper/venv-chown logic lives in `./setup-devuser.sh`. The project Dockerfile pulls it and invokes (see example project Dockerfile above).
- **The base ships a Python venv at `/opt/venv` already on `PATH`.** The helper script chowns it to devuser, after which plain `pip install ...` lands inside the venv. Base + project packages share `/opt/venv`, which is on a system path so it survives home-dir volume mounts at runtime.
- **Copy dependency manifests before source** so the install layer isn't invalidated by source changes.
- Do **not** pass `--no-cache-dir` on project installs; reserve that flag for pushed base images.
- Prefer runtime accelerator images over devel unless the project compiles native extensions inside the container at runtime.
- Pass UID/GID to cache mounts (`uid=${UID},gid=${GID}`) and `COPY --chown=${UID}:${GID}` so devuser can write to caches and owns the source.
- For non-Python stacks (npm, yarn, pnpm, cargo, go, …), the same `setup-devuser.sh` script is reusable — its venv chown is guarded, so non-Python projects just chown their own toolchain root in a follow-up `RUN` after invoking the script.

### 4 — Build and verify

Build the image. Fix any errors and retry until the build succeeds.

### 5 — Write docker-compose.yml

Copy most of the fields from the example docker-compose above (no `extends`). Adjust:
- **service name / `image`**: `{repo_name}` / `{repo_name}:dev`
- **`build.context`**: `.`, **`build.dockerfile`**: `Dockerfile`
- **`entrypoint`**: `["tail", "-f", "/dev/null"]` — keep this dev default
- everything else as needed based on the project.

### 6 — Report

Tell the user:
1. Which base image was chosen and why (or why a new one was created).
2. Notable compatibility decisions.
3. Start command: `docker compose -f ./{repo_name}/docker-compose.yml up -d`

---

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
