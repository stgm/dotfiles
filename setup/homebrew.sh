#!/bin/bash
set -e

source "$(dirname "$0")/lib.sh"

say "Homebrew"
if which brew >/dev/null 2>&1; then
    skip "already installed"
else
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# brew is not on PATH yet during a fresh install
eval "$(/opt/homebrew/bin/brew shellenv)"

say "Homebrew packages"
# --adopt takes over apps that are already in /Applications but not yet
# managed by Homebrew, instead of failing on them
export HOMEBREW_CASK_OPTS="--adopt"

if brew bundle check --file="$(dirname "$0")/Brewfile" >/dev/null 2>&1; then
    skip "everything in the Brewfile is installed"
else
    brew bundle --file="$(dirname "$0")/Brewfile"
fi
