#!/bin/bash
set -e

source "$(dirname "$0")/lib.sh"

say "SSH key"
if [ -f ~/.ssh/id_ed25519 ]; then
    skip "~/.ssh/id_ed25519 already exists"
else
    ssh-keygen -t ed25519 -C "martijn@stgm.nl" -f ~/.ssh/id_ed25519
fi

ssh-add --apple-use-keychain ~/.ssh/id_ed25519

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

if gh ssh-key list | grep -q "$(awk '{print $2}' ~/.ssh/id_ed25519.pub)"; then
    skip "key already registered with GitHub"
else
    gh ssh-key add ~/.ssh/id_ed25519.pub --title "$(scutil --get ComputerName 2>/dev/null || hostname)"
fi
