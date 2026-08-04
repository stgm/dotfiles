#!/bin/bash
set -e

source "$(dirname "$0")/lib.sh"

say "Python"
# Latest CPython, managed by uv. --default also creates python/python3
# in ~/.local/bin, which .zprofile already puts on PATH.
uv python install --default --preview-features python-install-default
info "python is now $(~/.local/bin/python -V 2>&1)"
