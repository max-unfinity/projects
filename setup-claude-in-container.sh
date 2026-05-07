#!/bin/sh
# Set up `claude` in a detached tmux session inside a running dev container,
# reusing the host user's Claude Code login + settings.
#
# Usage: setup-claude-in-container.sh <container> [tmux-session-name]
#   container         docker container name (e.g. dam4sam-dam4sam-1)
#   tmux-session-name optional, defaults to "claude"
#
# Prereqs:
#   - host is already logged in to Claude Code (~/.claude.json exists)
#   - container has a `devuser` with passwordless sudo (setup-devuser.sh layout)
#   - container has `claude` on PATH (e.g. installed via claude.ai/install.sh)
set -eu

CONTAINER="${1:?container name required}"
SESSION="${2:-claude}"

HOST_CLAUDE_JSON="$HOME/.claude.json"
HOST_CREDS="$HOME/.claude/.credentials.json"

[ -f "$HOST_CLAUDE_JSON" ] || { echo "missing $HOST_CLAUDE_JSON — log in on host first" >&2; exit 1; }
[ -f "$HOST_CREDS" ]       || { echo "missing $HOST_CREDS — log in on host first" >&2; exit 1; }

docker exec "$CONTAINER" sh -c 'command -v tmux >/dev/null 2>&1' || \
    docker exec "$CONTAINER" sh -c 'sudo apt-get update -qq && sudo apt-get install -y -qq tmux'

docker exec "$CONTAINER" sh -c 'mkdir -p ~/.claude'
docker cp "$HOST_CLAUDE_JSON" "$CONTAINER:/home/devuser/.claude.json"
docker cp "$HOST_CREDS"       "$CONTAINER:/home/devuser/.claude/.credentials.json"
docker exec "$CONTAINER" sh -c 'chmod 600 ~/.claude.json ~/.claude/.credentials.json'

docker exec "$CONTAINER" sh -c "tmux kill-session -t $SESSION 2>/dev/null || true"
docker exec "$CONTAINER" bash -lc \
    "tmux new-session -d -s $SESSION 'claude --verbose --remote-control \"$CONTAINER\" --dangerously-skip-permissions'"

# Walk the first-run prompts: trust folder (Enter) → accept bypass (Down, Enter).
sleep 3
docker exec "$CONTAINER" tmux send-keys -t "$SESSION" Enter
sleep 2
docker exec "$CONTAINER" tmux send-keys -t "$SESSION" Down
sleep 1
docker exec "$CONTAINER" tmux send-keys -t "$SESSION" Enter
sleep 3

echo "claude tmux session '$SESSION' started in $CONTAINER"
echo "attach:  docker exec -it $CONTAINER bash -lc 'tmux attach -t $SESSION'"
echo "stop:    docker exec $CONTAINER tmux kill-session -t $SESSION"
