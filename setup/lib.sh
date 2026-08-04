# shellcheck shell=bash
# Shared setup, sourced by the setup scripts.

case "$(uname -s)" in
    Darwin) OS=mac ;;
    Linux)  OS=linux ;;
    *) printf 'unsupported OS: %s\n' "$(uname -s)" >&2; exit 1 ;;
esac

is_mac() { [ "$OS" = mac ]; }
is_linux() { [ "$OS" = linux ]; }

# These scripts call brew-installed commands (uv, gh, rv, mas) by bare name, and
# each runs as its own process: a PATH set by one does not reach the next. A
# shell that predates the Homebrew install has none of them, so put brew on PATH
# here, where every setup script picks it up however it was started. Guarded,
# because on a fresh machine this runs once before Homebrew exists. The three
# prefixes are the Mac one, the Linux system-wide one and the Linux per-user one.
for _brew in /opt/homebrew/bin/brew /home/linuxbrew/.linuxbrew/bin/brew "$HOME/.linuxbrew/bin/brew"; do
    if [ -x "$_brew" ]; then
        eval "$("$_brew" shellenv)"
        break
    fi
done
unset _brew

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

# Permission bits of a file as an octal number. BSD and GNU stat disagree on
# which flag reports this.
mode_of() {
    if is_mac; then
        stat -f '%Lp' "$1"
    else
        stat -c '%a' "$1"
    fi
}
