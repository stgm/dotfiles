##############################################################################

# History
HISTFILE=$HOME/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY          # share history between running shells
setopt HIST_IGNORE_ALL_DUPS   # keep only the most recent copy of a command
setopt HIST_IGNORE_SPACE      # a leading space keeps a command out of history
setopt HIST_VERIFY            # expand a !! into the line instead of running it
setopt EXTENDED_HISTORY       # record timestamps

setopt AUTO_LIST              # list the choices on an ambiguous completion
setopt NO_BEEP                # no terminal bell

autoload -Uz compinit && compinit

source ${${(%):-%N}:A:h}/work.zsh

eval "$(rv shell init zsh)"
eval "$(rv shell completions zsh)"

##############################################################################

# The branch name after the path, and nothing else from vcs_info. The leading
# space lives in the format, so a directory outside a repo -- where vcs_info
# clears the message -- doesn't leave a gap before the %.
autoload -Uz vcs_info
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' formats ' %b'
precmd_functions+=(vcs_info)   # appended, so it can't displace another precmd
setopt PROMPT_SUBST            # re-expand ${vcs_info_msg_0_} on every prompt

PS1='%F{green}%~%f%F{221}${vcs_info_msg_0_}%f %% '
