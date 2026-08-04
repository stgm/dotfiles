##############################################################################
# .zprofile
#
# Read by login shells only, after /etc/zprofile has run path_helper. Note that
# on Mac OS each terminal tab opens as a login shell!
#
# We build the path here because path_helper puts the system directories right
# in front in the path. Everything here is exported, so shells started from a
# login shell inherit it without running any of this again.

##############################################################################
# Homebrew PATH and HOMEBREW_* variables. Called by full path and guarded just
# in case Homebrew isn't installed yet.
if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

##############################################################################
# ~/.local/bin contains, among other things, the default uv python
path=("$HOME/.local/bin" $path)

##############################################################################
# rv PATH, GEM_HOME and GEM_PATH for the Ruby version in use
if command -v rv >/dev/null; then
    eval "$(rv shell env zsh)"
fi
