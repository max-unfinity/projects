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

Check if the chosen image is built (`docker image ls | grep {base_name}`); build it from CWD if not. When building, pass `--build-arg UID=$(id -u) --build-arg GID=$(id -g)` so the baked-in `devuser` matches the host user.

### 3 — Write the Dockerfile

Create `./{repo_name}/Dockerfile` modelled on the example project Dockerfile above.

Before writing, read `./include.md` and ensure every package/CLI/library listed there is installed in the project Dockerfile (in addition to whatever the project itself needs). Use the appropriate install path: `apt`/`apt-get` for system libs, the language manager for CLI tools (e.g. `pip install`, `npm i -g`), and the documented installer for anything else. If something in `include.md` is already provided by the chosen base image, skip it.

Key practices (non-obvious ones):
- **Copy dependency manifests before source** so the install layer isn't invalidated by source changes.
- Do **not** pass `--no-cache-dir` on project installs; reserve that flag for pushed base images.
- Prefer runtime accelerator images over devel unless the project compiles native extensions inside the container at runtime.
- Stay on `USER devuser` from the base. `apt`/`apt-get`/`dpkg` are wrapped to auto-sudo, and the language package manager preconfigured in the base (pip in the Python base) defaults to user-mode installs — neither needs an explicit `sudo` prefix or user/global flag.
- Re-declare `ARG UID` / `ARG GID` and pass them to cache mounts (`uid=${UID},gid=${GID}`) and `COPY --chown=${UID}:${GID}` so devuser can write to caches and owns the source.
- For non-Python stacks (npm, yarn, pnpm, cargo, go, …), see the cache-target table below; the rest of the conventions are unchanged.

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

The `devuser` / sudo-wrapper / UID-matching machinery in the base is language-agnostic. When creating a new base for a different stack (Node, Rust, Go, …), copy the closest existing base, swap **only** the toolchain install, and keep the user/sudo/wrapper block identical. In that base, configure the manager so its **default** install mode lands under `/home/devuser` (no sudo needed) — analogous to pip's `[install] user = true`.

In project Dockerfiles, point the cache mount at the manager's cache dir:

| Manager | User-install setup (in base)            | Cache mount target                                                                   |
| ------- | --------------------------------------- | ------------------------------------------------------------------------------------ |
| pip     | `[install] user = true` in `pip.conf`   | `/home/devuser/.cache/pip`                                                           |
| npm     | `npm config set prefix ~/.local`        | `/home/devuser/.npm`                                                                 |
| yarn    | `yarn config set prefix ~/.local`       | `/home/devuser/.cache/yarn` (v1) or `/home/devuser/.yarn/berry/cache` (v2+)          |
| pnpm    | `pnpm config set global-bin-dir ~/.local/bin` | `/home/devuser/.local/share/pnpm/store`                                        |
