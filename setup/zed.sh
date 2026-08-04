#!/bin/bash
set -e

source "$(dirname "$0")/lib.sh"

say "Zed"

if is_mac; then
    skip "installed as a cask by Brewfile.mac"
    exit 0
fi

# Zed has no Homebrew cask on Linux. Its own installer unpacks into ~/.local,
# leaving the binary at ~/.local/bin/zed, which .zprofile already has on PATH.
# Zed reads ~/.config/zed on Linux, which is where link.sh puts the settings.
if [ -x "$HOME/.local/bin/zed" ] || command -v zed >/dev/null 2>&1; then
    skip "already installed"
else
    curl -fsSL https://zed.dev/install.sh | sh
fi
