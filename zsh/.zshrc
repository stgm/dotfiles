##############################################################################
# .zshrc
#
# Read by every interactive shell. It holds what a child shell does not inherit
# from its parent: options, functions, completions, hooks, key bindings and the
# prompt. Environment variables are inherited, so they belong in .zprofile (or
# .zshenv) and setting them here would only repeat work.

##############################################################################
# HISTORY settings
HISTFILE=$HOME/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY          # share history between running shells
setopt HIST_IGNORE_ALL_DUPS   # keep only the most recent copy of a command
setopt HIST_IGNORE_SPACE      # a leading space keeps a command out of history
setopt HIST_VERIFY            # expand a !! into the line instead of running it
setopt EXTENDED_HISTORY       # record timestamps

##############################################################################
# COMPLETIONS
setopt AUTO_LIST              # list the choices on an ambiguous completion
setopt NO_BEEP                # no terminal bell
autoload -Uz compinit && compinit

##############################################################################
# WORK tool
source ${${(%):-%N}:A:h}/work.zsh

##############################################################################
# RUBY rv shell integration
# Adds a preexec hook that re-reads .ruby-version, so the Ruby follows
# the directory as you cd around, and completions need the compinit above.
if command -v rv >/dev/null; then
    eval "$(rv shell init zsh)"
    eval "$(rv shell completions zsh)"
fi

##############################################################################
# PROMPT
#
#    <current working dir> <git branch?> %
#
autoload -Uz vcs_info
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' formats ' %b'
precmd_functions+=(vcs_info)   # appended, so it can't displace another precmd
setopt PROMPT_SUBST            # re-expand ${vcs_info_msg_0_} on every prompt
PS1='%F{green}%~%f%F{221}${vcs_info_msg_0_}%f %% '
