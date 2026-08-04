#!/bin/bash
set -e

source "$(dirname "$0")/lib.sh"

say "Python"
# Latest CPython, managed by uv. --default also creates python/python3
# in ~/.local/bin, which .zprofile already puts on PATH.
if [ -x "$HOME/.local/bin/python" ] &&
    uv python list --only-installed 2>/dev/null | grep -qF "$HOME/.local/bin/python "; then
    skip "a uv-managed default python is already installed"
else
    uv python install --default --preview-features python-install-default
fi
info "python is now $("$HOME/.local/bin/python" -V 2>&1)"
