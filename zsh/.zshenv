# Keep PATH free of duplicates when shells nest or configs are re-sourced
typeset -U path PATH

export PATH="$HOME/.local/bin:$PATH"

# Headers and libraries for building native extensions against Homebrew
export C_INCLUDE_PATH=/opt/homebrew/include
export LIBRARY_PATH=/opt/homebrew/lib

# Needed by the pg gem
export PATH="/opt/homebrew/opt/libpq/bin:$PATH"

export EDITOR="zed --wait"
