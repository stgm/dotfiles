#!/bin/bash
set -e

source "$(dirname "$0")/lib.sh"

say "Claude Code hooks"

settings="$HOME/.claude/settings.json"
hook_cmd="$HOME/.claude/hooks/adhd-session-start.sh"

mkdir -p "$HOME/.claude"
[ -f "$settings" ] || echo '{}' > "$settings"

if jq -e --arg cmd "$hook_cmd" \
    '[.hooks.SessionStart[]?.hooks[]?.command] | index($cmd) != null' \
    "$settings" >/dev/null 2>&1; then
    skip "adhd SessionStart hook already registered"
else
    info "registering adhd SessionStart hook"
    tmp="$(mktemp)"
    jq --arg cmd "$hook_cmd" '
        .hooks.SessionStart = ((.hooks.SessionStart // []) +
            [{"hooks": [{"type": "command", "command": $cmd}]}])
    ' "$settings" > "$tmp"
    mv "$tmp" "$settings"
fi
