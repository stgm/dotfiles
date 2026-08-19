#!/bin/bash
# SessionStart hook: tells Claude to activate the adhd skill at the start of
# every session. Registered into ~/.claude/settings.json by setup/claude.sh.
cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"Invoke the Skill tool with skill: \"adhd\" right now, before responding to the user's first message, to activate ADHD-friendly output shaping for this entire session."}}
JSON
