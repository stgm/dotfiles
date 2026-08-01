eval "$(/opt/homebrew/bin/brew shellenv)"

# /etc/zprofile runs path_helper, which rebuilds PATH with the system
# directories first and pushes everything .zshenv set behind /usr/bin. That
# is why an old /usr/bin/python3 would win over uv's. Put ours back in front;
# `typeset -U path` in .zshenv makes this move rather than duplicate.
path=("$HOME/.local/bin" /opt/homebrew/opt/libpq/bin $path)
