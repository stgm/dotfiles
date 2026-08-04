#!/bin/bash
set -e

# This script is downloaded and run on its own, before the repo exists, so it
# cannot source setup/lib.sh -- keep these in step with it.
if [ -t 1 ]; then
    _BOLD=$'\033[1m'; _BLUE=$'\033[34m'; _DIM=$'\033[2m'; _RESET=$'\033[0m'
else
    _BOLD=; _BLUE=; _DIM=; _RESET=
fi
say() { printf '\n%s==> %s%s\n' "$_BLUE$_BOLD" "$1" "$_RESET"; }
info() { printf '    %s\n' "$1"; }
skip() { printf '    %s- %s%s\n' "$_DIM" "$1" "$_RESET"; }

# Xcode Command Line Tools (needed for Homebrew / compiling, and provides git).
# The installer runs in a separate GUI process, so wait for it to finish.
say "Xcode Command Line Tools"
if xcode-select -p >/dev/null 2>&1; then
    skip "already installed"
else
    xcode-select --install
    info "waiting for the installer to finish..."
    until xcode-select -p >/dev/null 2>&1; do
        sleep 10
    done
fi

say "Dotfiles"
mkdir -p ~/dev/stgm
if [ -d ~/dev/stgm/dotfiles ]; then
    skip "already cloned"
else
    git clone https://github.com/stgm/dotfiles.git ~/dev/stgm/dotfiles
fi
cd ~/dev/stgm/dotfiles

say "Symlinking configs"
./link.sh

./setup/homebrew.sh

# homebrew.sh ran as its own process, so the PATH it set went with it. This
# script cannot source setup/lib.sh, which does the same for the setup scripts,
# so it needs its own copy before it calls anything Homebrew installed.
if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

./setup/python.sh
./setup/mac_defaults.sh
./setup/terminal.sh
./setup/touchid_sudo.sh

# GitHub auth, needed before cloning over SSH below
./setup/github.sh

# Install course-site dev repo + ruby and Rails
./setup/rails.sh

say "Done"
info "open a new shell to pick up the new configuration"
