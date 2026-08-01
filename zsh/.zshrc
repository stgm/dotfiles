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

autoload -Uz compinit && compinit

source ${${(%):-%N}:A:h}/work.zsh

eval "$(rv shell init zsh)"
eval "$(rv shell completions zsh)"

##############################################################################

PS1='%F{221}%~ %f%% '
