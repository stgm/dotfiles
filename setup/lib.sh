# Shared output helpers, sourced by the setup scripts.

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
