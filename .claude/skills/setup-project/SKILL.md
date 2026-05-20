---
name: setup-project
description: Set up a 3rd-party GitHub project for local development.
argument-hint: <github-url-or-repo-name>
disable-model-invocation: true
model: claude-opus-4-6
effort: high
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

### Additional user packages/libs

The list of extra packages that must be installed inside every project Dockerfile.

!`cat ./include.md`

### Non-Python stacks

Reference: `./.claude/skills/setup-project/stacks.md` — toolchain layout (chown target, cache mount path, PATH line) for npm / yarn / pnpm bases. Read on demand when setting up a non-Python project.

---

## Task: set up the requested project

### 1 — Clone

If the input is ambiguous (short name, multiple matches), confirm with the user before cloning.

Clone into `./{repo_name}/` (relative to CWD). Use the URL's final path segment (no `.git`) as `{repo_name}` throughout.

### 2 — Select base image

Base images follow the naming convention shown above (e.g. `cu12.8-torch2.7-base.Dockerfile`). Treat `{base_name}` as the filename without `.Dockerfile` (e.g. `cu12.8-torch2.7-base`); the local tag is always `{base_name}:dev`.

**Prefer an existing image.** Compatibility rules:
- Accelerator libs (CUDA, ROCm, etc.) are forward-compatible within a major version.
- Framework versions (torch, jax, tf) are generally forward-compatible; only reject if the project hard-requires an older major version.

**Create a new base only as a last resort** — model it on the Example base-image Dockerfile reference (or the closest existing one), adjust versions, keep the naming convention, and explain why no existing image fit. New base Dockerfiles live in CWD as `./{base_name}.Dockerfile`.

Check if the chosen image is built (`docker image ls | grep {base_name}`); build it from CWD if not. The base has no user concept — it's a pure tooling layer — so no UID/GID build args are needed.

### 3 — Write the Dockerfile

Create `./{repo_name}/Dockerfile` modelled on the example project Dockerfile above.

Ensure every package/CLI/library from the "Additional user packages/libs" list above is installed in the project Dockerfile (in addition to whatever the project itself needs). Skip anything already provided by the chosen base image.

Key practices (non-obvious ones):
- **Use the shared `setup-devuser.sh` helper.** All devuser/sudo-wrapper/venv-chown logic lives in `./setup-devuser.sh`. The project Dockerfile pulls it and invokes (see example project Dockerfile above).
- **The base ships a Python venv at `/opt/venv` already on `PATH`.** The helper script chowns it to devuser, after which plain `pip install ...` lands inside the venv. Base + project packages share `/opt/venv`, which is on a system path so it survives home-dir volume mounts at runtime.
- **Pull host auth state from the `home` build context** (see example) so claude/codex auto-login as the host user. Sync-needed paths (`~/.claude/skills`, `~/mcp-servers`, `~/.tmux.conf`, `~/.secrets`) are bind-mounted at runtime — do not COPY them. After copying `settings.json`, strip the host-specific `env` field (it contains host paths that are wrong inside the container) — see the example Dockerfile's `python -c` one-liner.
- **Always end the Dockerfile with `COPY --chown=${UID}:${GID} . .`** (after dependency install) so the image runs standalone and `pip install -e .` registers against a real tree. The runtime volume mount overlays this for live-edit.
- **Do NOT compile native extensions in the Dockerfile.** Defer `build_ext --inplace`/CMake/etc. to step 6 — the runtime volume mount hides anything emitted into the project tree at build time.
- **Copy dependency manifests before source** so the install layer isn't invalidated by source changes.
- Do **not** pass `--no-cache-dir` on project installs; reserve that flag for pushed base images.
- Prefer runtime accelerator images over devel unless the project compiles native extensions inside the container at runtime.
- Pass UID/GID to cache mounts (`uid=${UID},gid=${GID}`) and `COPY --chown=${UID}:${GID}` so devuser can write to caches and owns the source.
- For non-Python stacks (npm, yarn, pnpm, cargo, go, …), the same `setup-devuser.sh` script is reusable — its venv chown is guarded, so non-Python projects just chown their own toolchain root in a follow-up `RUN` after invoking the script.

### 4 — Build and verify

Build the image. Fix any errors and retry until the build succeeds.

### 5 — Write docker-compose.yml

Copy most of the fields from the example docker-compose above (no `extends`). The example already wires `additional_contexts.home` and the host-overlay bind mounts — keep those verbatim. Adjust:
- **service name / `image`**: `{repo_name}` / `{repo_name}:dev`
- **`build.context`**: `.`, **`build.dockerfile`**: `Dockerfile`
- **`entrypoint`**: `["tail", "-f", "/dev/null"]` — keep this dev default
- everything else as needed based on the project.

### 6 — Run and compile native extensions

`docker compose up -d`, then verify imports of key libraries.

If the project has native extensions (C/C++/CUDA — check for `setup.py` with `Extension`/`CUDAExtension`, `pyproject.toml` with `cibuildwheel`/`scikit-build`, or `CMakeLists.txt`), compile them now via `docker compose exec`. Because the project dir is volume-mounted, the resulting `.so` files land on the host and survive container rebuilds.

### 7 — Start claude in the container

Run `./setup-claude-in-container.sh {repo_name}-{repo_name}-1` (or pass the actual container name) to spin up a tmux session with `claude --dangerously-skip-permissions --remote-control` inside the container, reusing the host login. The script's keystroke walk-through matches `~/.claude/skills/start-claude/SKILL.md`.

### 8 — Report

Briefly summarise your work and report any issues you encountered. If you had to create a new base image, explain why.