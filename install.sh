#!/bin/bash
set -e

# This script is downloaded and run on its own, before the repo exists, so it
# cannot source setup/lib.sh -- keep these in step with it.
case "$(uname -s)" in
    Darwin) OS=mac ;;
    Linux)  OS=linux ;;
    *) printf 'unsupported OS: %s\n' "$(uname -s)" >&2; exit 1 ;;
esac

is_mac() { [ "$OS" = mac ]; }

if [ -t 1 ]; then
    _BOLD=$'\033[1m'; _BLUE=$'\033[34m'; _DIM=$'\033[2m'; _RESET=$'\033[0m'
else
    _BOLD=; _BLUE=; _DIM=; _RESET=
fi
say() { printf '\n%s==> %s%s\n' "$_BLUE$_BOLD" "$1" "$_RESET"; }
info() { printf '    %s\n' "$1"; }
skip() { printf '    %s- %s%s\n' "$_DIM" "$1" "$_RESET"; }

say "Prerequisites"
if is_mac; then
    # Xcode Command Line Tools (needed for Homebrew / compiling, and provides
    # git). The installer runs in a separate GUI process, so wait for it.
    if xcode-select -p >/dev/null 2>&1; then
        skip "Xcode Command Line Tools already installed"
    else
        xcode-select --install
        info "waiting for the installer to finish..."
        until xcode-select -p >/dev/null 2>&1; do
            sleep 10
        done
    fi
else
    # What Homebrew on Linux needs to build and run, plus zsh and git for the
    # rest of this script. util-linux-user is what provides chsh: Fedora does
    # not install it by default.
    packages=(curl file git procps-ng util-linux-user zsh)

    if ! command -v dnf >/dev/null 2>&1; then
        info "this only knows how to install packages with dnf (Fedora/Asahi)"
        info "install these yourself, plus a C toolchain, then re-run:"
        info "${packages[*]}"
        exit 1
    fi

    missing=()
    for package in "${packages[@]}"; do
        rpm -q "$package" >/dev/null 2>&1 || missing+=("$package")
    done
    if ! dnf group list --installed 2>/dev/null | grep -qi 'development tools'; then
        missing+=(@development-tools)
    fi

    if [ ${#missing[@]} -eq 0 ]; then
        skip "all packages already installed"
    else
        info "installing: ${missing[*]}"
        sudo dnf install -y "${missing[@]}"
    fi

    # macOS already uses zsh, Fedora defaults to bash. Read the passwd entry
    # rather than $SHELL, which only says what the current shell was started as.
    login_shell="$(getent passwd "$(id -un)" | awk -F: '{print $NF}')"
    if [ "${login_shell##*/}" = zsh ]; then
        skip "zsh is already the login shell"
    else
        info "making zsh the login shell -- takes effect at the next login"
        chsh -s "$(command -v zsh)"
    fi
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
for brew in /opt/homebrew/bin/brew /home/linuxbrew/.linuxbrew/bin/brew "$HOME/.linuxbrew/bin/brew"; do
    if [ -x "$brew" ]; then
        eval "$("$brew" shellenv)"
        break
    fi
done

./setup/python.sh
./setup/zed.sh

if is_mac; then
    ./setup/mac_defaults.sh
    ./setup/terminal.sh
    ./setup/touchid_sudo.sh
else
    say "macOS-only steps"
    skip "mac_defaults.sh, terminal.sh and touchid_sudo.sh do not apply here"
fi

# GitHub auth, needed before cloning over SSH below
./setup/github.sh

# Install course-site dev repo + ruby and Rails
./setup/rails.sh

say "Done"
info "open a new shell to pick up the new configuration"
