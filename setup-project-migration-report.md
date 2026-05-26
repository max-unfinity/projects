# Migration Report: setup-project skill → global (user-scope)

## Current state

The `setup-project` skill lives at `~/projects/.claude/skills/setup-project/SKILL.md` — it's project-scoped and only works when Claude's CWD is `~/projects/`. It depends on several files that live alongside the cloned projects in `~/projects/`:

| File | Role |
|------|------|
| `~/projects/examples/docker-compose-example.yml` | Template for project compose files |
| `~/projects/examples/project-example.Dockerfile` | Template for project Dockerfiles |
| `~/projects/examples/base-image-example.Dockerfile` | Template for base images |
| `~/projects/include.md` | Extra packages to install in every project |
| `~/projects/setup-devuser.sh` | Shared helper copied into Dockerfiles via `COPY --from=helpers` |
| `~/projects/setup-claude-in-container.sh` | Script to start claude in a container |
| `~/projects/*.Dockerfile` | Base images (e.g. `cu12.8-torch2.7-base.Dockerfile`) |
| `~/projects/.claude/skills/setup-project/stacks.md` | Non-Python stack reference |

## Target state

Skill at `~/.claude/skills/setup-project/SKILL.md` — user-scoped, works from any directory.

## What needs to change

### 1. Move supporting files into the skill directory

Move templates and references into `~/.claude/skills/setup-project/`:

```
~/.claude/skills/setup-project/
├── SKILL.md
├── stacks.md                          (move from ~/projects/.claude/skills/setup-project/)
├── templates/
│   ├── docker-compose-example.yml     (move from ~/projects/examples/)
│   ├── project-example.Dockerfile     (move from ~/projects/examples/)
│   └── base-image-example.Dockerfile  (move from ~/projects/examples/)
├── include.md                         (move from ~/projects/)
├── setup-devuser.sh                   (keep in ~/projects/, reference by absolute path)
└── setup-claude-in-container.sh       (keep in ~/projects/, reference by absolute path)
```

**Important:** `setup-devuser.sh` and `setup-claude-in-container.sh` must stay in `~/projects/` because:
- `setup-devuser.sh` is referenced via Docker `COPY --from=helpers` build context, which points to `..` (the projects dir) from each project's docker-compose
- `setup-claude-in-container.sh` is run from the host with `./setup-claude-in-container.sh`
- These are runtime artifacts, not just skill documentation

So we **copy** templates into the skill dir (for SKILL.md to inline them) but **keep originals** in `~/projects/` for Docker builds. OR: keep a single source of truth in `~/projects/` and reference by absolute path from SKILL.md.

### 2. Rewrite SKILL.md path references

All relative paths (`./*.Dockerfile`, `./examples/...`, `./include.md`, `./.claude/skills/...`) must become absolute or use a variable.

**Recommended approach:** Define `PROJECTS_DIR=~/projects` at the top of SKILL.md and use absolute paths in all `!`command`` injections:

| Before (relative, assumes CWD) | After (absolute) |
|---|---|
| `` !`ls ./*.Dockerfile -1 \| sort` `` | `` !`ls ~/projects/*.Dockerfile -1 \| sort` `` |
| `` !`cat ./examples/docker-compose-example.yml` `` | `` !`cat ~/projects/examples/docker-compose-example.yml` `` |
| `` !`cat ./examples/project-example.Dockerfile` `` | `` !`cat ~/projects/examples/project-example.Dockerfile` `` |
| `` !`cat ./include.md` `` | `` !`cat ~/projects/include.md` `` |
| `./examples/base-image-example.Dockerfile` | `~/projects/examples/base-image-example.Dockerfile` |
| `./.claude/skills/setup-project/stacks.md` | `~/.claude/skills/setup-project/stacks.md` |

### 3. Update SKILL.md instructions that assume CWD

Several instructions in the skill body reference CWD as the projects dir:

| Section | Current instruction | Change to |
|---|---|---|
| Context | "assumes CWD is the parent projects directory" | "Projects directory is `~/projects`" |
| Step 1 — Clone | "Clone into `./{repo_name}/`" | "Clone into `~/projects/{repo_name}/`" |
| Step 2 — Select base | "New base Dockerfiles live in CWD" | "New base Dockerfiles live in `~/projects/`" |
| Step 3 — Write Dockerfile | "Create `./{repo_name}/Dockerfile`" | "Create `~/projects/{repo_name}/Dockerfile`" |
| Step 5 — docker-compose | paths in `build.context` and `additional_contexts.helpers` | `helpers: ~/projects` (absolute, since compose file is now in a subdir) |
| Step 7 — Start claude | `./setup-claude-in-container.sh` | `~/projects/setup-claude-in-container.sh` |

### 4. Docker build context for `helpers`

The example docker-compose uses:
```yaml
additional_contexts:
  helpers: ..
```

This works because each project's docker-compose is at `~/projects/{repo}/docker-compose.yml` and `..` resolves to `~/projects/`. This stays correct — the compose file location hasn't moved, only the skill definition. **No change needed here.**

### 5. Clean up old location

After migration:
- Delete `~/projects/.claude/skills/setup-project/` (the old project-scoped skill)
- Keep `~/projects/.claude/` dir if other things use it, or delete if empty
- Keep all files in `~/projects/` root (Dockerfiles, scripts, examples) — they're still needed for Docker builds

## Summary of actions

1. **Create** `~/.claude/skills/setup-project/SKILL.md` — rewritten with absolute paths
2. **Move** `~/projects/.claude/skills/setup-project/stacks.md` → `~/.claude/skills/setup-project/stacks.md`
3. **Rewrite** all relative paths to absolute `~/projects/...` paths in SKILL.md
4. **Remove** `~/projects/.claude/skills/setup-project/` directory
5. **Keep** all files in `~/projects/` root — unchanged, still needed for Docker

## Risk assessment

- **Low risk:** The skill only changes where its definition lives and how it references paths. All Docker build infrastructure stays in place.
- **No breaking change for existing projects:** Dockerfiles, compose files, and scripts in `~/projects/` are untouched.
- **One caveat:** If you ever work from a different machine where `~/projects` doesn't exist, the skill will fail on the `!`command`` injections. Could be made more robust with fallback messages.
