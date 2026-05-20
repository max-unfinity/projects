#!/bin/sh
# Start claude in a detached tmux session inside a dev container.
# Usage: setup-claude-in-container.sh <container> [session-name]
set -eu

CONTAINER="${1:?container name required}"
SESSION="${2:-claude}"

HOST_CLAUDE_JSON="$HOME/.claude.json"
HOST_CREDS="$HOME/.claude/.credentials.json"

[ -f "$HOST_CLAUDE_JSON" ] || { echo "missing $HOST_CLAUDE_JSON — log in on host first" >&2; exit 1; }
[ -f "$HOST_CREDS" ]       || { echo "missing $HOST_CREDS — log in on host first" >&2; exit 1; }

docker exec "$CONTAINER" sh -c 'command -v tmux >/dev/null 2>&1' || \
    docker exec "$CONTAINER" sh -c 'sudo apt-get update -qq && sudo apt-get install -y -qq tmux'

# Refresh auth state (host may have re-logged in since image build).
docker exec "$CONTAINER" sh -c 'mkdir -p ~/.claude'
docker cp "$HOST_CLAUDE_JSON" "$CONTAINER:/home/devuser/.claude.json"
docker cp "$HOST_CREDS"       "$CONTAINER:/home/devuser/.claude/.credentials.json"
docker exec "$CONTAINER" sh -c 'chmod 600 ~/.claude.json ~/.claude/.credentials.json'

docker exec "$CONTAINER" sh -c "tmux kill-session -t $SESSION 2>/dev/null || true"
docker exec -w /home/devuser "$CONTAINER" bash -lc \
    "tmux new-session -d -s $SESSION 'claude --verbose --remote-control \"$CONTAINER\" --dangerously-skip-permissions'"

# Walk first-run prompts (matches start-claude skill).
sleep 2
docker exec "$CONTAINER" tmux send-keys -t "$SESSION" Enter
sleep 1
docker exec "$CONTAINER" tmux send-keys -t "$SESSION" Down
sleep 1
docker exec "$CONTAINER" tmux send-keys -t "$SESSION" Enter

echo "claude tmux session '$SESSION' started in $CONTAINER"
echo "attach:  docker exec -it $CONTAINER bash -lc 'tmux attach -t $SESSION'"
echo "stop:    docker exec $CONTAINER tmux kill-session -t $SESSION"
