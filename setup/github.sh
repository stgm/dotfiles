#!/bin/bash
set -e

source "$(dirname "$0")/lib.sh"

say "SSH key"
if [ -f ~/.ssh/id_ed25519 ]; then
    skip "~/.ssh/id_ed25519 already exists"
else
    ssh-keygen -t ed25519 -C "martijn@stgm.nl" -f ~/.ssh/id_ed25519
fi

# On Linux there may be no agent running yet; on macOS launchd always provides
# one. `ssh-add -l` exits 2 when it cannot reach an agent at all, 1 when the
# agent is there but holds no keys.
agent_status=0
ssh-add -l >/dev/null 2>&1 || agent_status=$?
if [ "$agent_status" -eq 2 ]; then
    info "starting an ssh-agent"
    eval "$(ssh-agent -s)" >/dev/null
fi

# Read the key's fingerprint and only add it if the agent doesn't have it
fingerprint="$(ssh-keygen -lf ~/.ssh/id_ed25519.pub | awk '{print $2}')"
if ssh-add -l 2>/dev/null | awk '{print $2}' | grep -qxF "$fingerprint"; then
    skip "already loaded in the ssh-agent"
elif is_mac; then
    # --apple-use-keychain stores the passphrase in the login keychain, so the
    # key is reloaded automatically after a reboot. Apple's ssh-add only.
    ssh-add --apple-use-keychain ~/.ssh/id_ed25519
else
    ssh-add ~/.ssh/id_ed25519
fi

say "GitHub"
# Skipped when already logged in, so this is safe to re-run
if gh auth status >/dev/null 2>&1; then
    skip "already authenticated"
else
    gh auth login --git-protocol ssh --hostname github.com --scopes admin:public_key
fi

# Ensure API access for keys if previously auth'ed without that
if ! gh api user/keys --silent >/dev/null 2>&1; then
    info "gh needs the admin:public_key scope, opening the browser"
    gh auth refresh --hostname github.com --scopes admin:public_key
fi

# Use the API directly: `gh ssh-key list` also queries the signing-key
# endpoint, which warns unless the token has admin:ssh_signing_key.
if gh api user/keys --jq '.[].key' | awk '{print $2}' |
    grep -qxF "$(awk '{print $2}' ~/.ssh/id_ed25519.pub)"; then
    skip "key already registered with GitHub"
else
    gh ssh-key add ~/.ssh/id_ed25519.pub --title "$(scutil --get ComputerName 2>/dev/null || hostname)"
fi
