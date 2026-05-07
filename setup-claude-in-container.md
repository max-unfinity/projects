# Claude Code in a tmux container session

Spin up `claude` inside a running dev container, reusing the host user's
Claude Code login so no in-container OAuth is needed. Runs detached in tmux
with `--remote-control`, so you can drive it from `claude.ai/code` or attach
from any terminal.

## Prereqs

- Host is logged in to Claude Code — `~/.claude.json` and
  `~/.claude/.credentials.json` exist.
- Container has a `devuser` with passwordless sudo (the standard
  `setup-devuser.sh` layout used by all projects here).
- `claude` is on PATH inside the container — the project Dockerfiles in this
  tree install it via `curl -fsSL https://claude.ai/install.sh | bash` as
  devuser, landing in `~/.local/bin`.

## Usage

```sh
./setup-claude-in-container.sh <container> [session-name]
```

Example:

```sh
./setup-claude-in-container.sh dam4sam-dam4sam-1
```

The script:

1. Installs tmux in the container if missing.
2. Copies `~/.claude.json` and `~/.claude/.credentials.json` from the host to
   `/home/devuser/`, with `0600` perms.
3. Kills any prior tmux session of the same name.
4. Starts a detached tmux session running:
   ```
   claude --verbose --remote-control "<container>" --dangerously-skip-permissions
   ```
   The container name is passed as the remote-control session label so it's
   easy to find in the cloud session list.
5. Walks the first-run prompts (trust folder → accept bypass-permissions).

## Working with the session

```sh
# attach (Ctrl-b d to detach)
docker exec -it <container> bash -lc 'tmux attach -t claude'

# peek at what's on screen without attaching
docker exec <container> tmux capture-pane -t claude -p | tail -40

# stop
docker exec <container> tmux kill-session -t claude
```

The session URL printed by claude (e.g.
`https://claude.ai/code/session_…`) is also reachable from the host browser
since `--remote-control` registers with the cloud session router.

## Notes / gotchas

- The credentials file is plain JSON containing OAuth tokens — treat the
  container as trusted.
- Re-running the script overwrites both state files, which logs out any
  in-container changes you made (shell snapshots, conversation history). If
  you want to keep that state across rebuilds, mount `~/.claude` and
  `~/.claude.json` as volumes instead of copying.
- `--dangerously-skip-permissions` is appropriate inside a sandboxed dev
  container; do not enable it on a host shell.
