# Shared setup, sourced by the setup scripts.

# These scripts call brew-installed commands (uv, gh, rv, mas) by bare name, and
# each runs as its own process: a PATH set by one does not reach the next. A
# shell that predates the Homebrew install has none of them, so put brew on PATH
# here, where every setup script picks it up however it was started. Guarded,
# because on a fresh Mac this runs once before Homebrew exists.
if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

if [ -t 1 ]; then
    _BOLD=$'\033[1m'; _BLUE=$'\033[34m'; _DIM=$'\033[2m'; _RESET=$'\033[0m'
else
    _BOLD=; _BLUE=; _DIM=; _RESET=
fi

# Section heading
say() { printf '\n%s==> %s%s\n' "$_BLUE$_BOLD" "$1" "$_RESET"; }

# Something is being done
info() { printf '    %s\n' "$1"; }

# Nothing to do, already in order
skip() { printf '    %s- %s%s\n' "$_DIM" "$1" "$_RESET"; }
