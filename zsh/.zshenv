##############################################################################
# .zshenv
#
# Read by every zsh: login shells, interactive shells and scripts alike, before
# any other startup file. So it holds only static values that cost nothing and
# cannot be got wrong. PATH is built in .zprofile

##############################################################################
# Clean up the path list, removing dupes
typeset -U path PATH

##############################################################################
# Default editor
export EDITOR="zed --wait"

##############################################################################
# C compiler paths
export C_INCLUDE_PATH=/opt/homebrew/include
export LIBRARY_PATH=/opt/homebrew/lib
