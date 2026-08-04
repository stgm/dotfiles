##############################################################################
# .zprofile
#
# Read by login shells only, after /etc/zprofile has run path_helper. Note that
# on Mac OS each terminal tab opens as a login shell! On Linux they are not, so
# .zshrc sources this file itself when the login shell has not already run it.
#
# We build the path here because path_helper puts the system directories right
# in front in the path. Everything here is exported, so shells started from a
# login shell inherit it without running any of this again.

##############################################################################
# Homebrew PATH and HOMEBREW_* variables. Called by full path and guarded just
# in case Homebrew isn't installed yet. The candidates are the Mac prefix, the
# system-wide Linux one and the per-user Linux one.
for brew in /opt/homebrew/bin/brew /home/linuxbrew/.linuxbrew/bin/brew "$HOME/.linuxbrew/bin/brew"; do
    if [[ -x $brew ]]; then
        eval "$($brew shellenv)"
        break
    fi
done
unset brew

##############################################################################
# C compiler paths, so headers and libraries from Homebrew are found
if [[ -n $HOMEBREW_PREFIX ]]; then
    export C_INCLUDE_PATH="$HOMEBREW_PREFIX/include"
    export LIBRARY_PATH="$HOMEBREW_PREFIX/lib"
fi

##############################################################################
# ~/.local/bin contains, among other things, the default uv python and, on
# Linux, zed
path=("$HOME/.local/bin" $path)

##############################################################################
# rv PATH, GEM_HOME and GEM_PATH for the Ruby version in use
if command -v rv >/dev/null; then
    eval "$(rv shell env zsh)"
fi

##############################################################################
# Marks this file as having run, so .zshrc does not source it a second time
export DOTFILES_PROFILE=1
