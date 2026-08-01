#!/bin/bash
set -e

cd "$(dirname "$0")"

while IFS= read -r line; do
    [ -z "$line" ] && continue

    src=$(echo "$line" | awk '{print $1}')
    dest=$(echo "$line" | awk '{print $3}')
    dest="${dest/#\~/$HOME}"
    src="$(pwd)/$src"

    mkdir -p "$(dirname "$dest")"
    ln -sf "$src" "$dest"
    printf '    %s\n' "${dest/#$HOME/~}"
done < config.symlinks

chmod 700 "$HOME/.ssh"
