#!/bin/bash
set -e

cd "$(dirname "$0")"
source setup/lib.sh

while IFS= read -r line; do
    [ -z "$line" ] && continue

    src=$(echo "$line" | awk '{print $1}')
    dest=$(echo "$line" | awk '{print $3}')
    dest="${dest/#\~/$HOME}"
    src="$(pwd)/$src"

    if [ "$(readlink "$dest" 2>/dev/null)" = "$src" ]; then
        skip "${dest/#$HOME/~}"
        continue
    fi

    mkdir -p "$(dirname "$dest")"
    ln -sf "$src" "$dest"
    info "${dest/#$HOME/~}"
done < config.symlinks

# ssh refuses a config in a directory others can read
if [ -d "$HOME/.ssh" ] && [ "$(mode_of "$HOME/.ssh")" != 700 ]; then
    info "tightening permissions on ~/.ssh"
    chmod 700 "$HOME/.ssh"
fi
