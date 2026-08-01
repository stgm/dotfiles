#!/bin/bash
set -e

source "$(dirname "$0")/lib.sh"

PROFILE=Stegeman

say "Terminal profile"

if defaults read com.apple.Terminal "Window Settings" 2>/dev/null | grep -q "name = $PROFILE;"; then
    skip "$PROFILE is already installed"
else
    open "$(dirname "$0")/../terminal/$PROFILE.terminal"

    # The import happens over in Terminal, so wait for the profile to appear
    # before pointing the defaults below at a name that isn't there yet.
    for _ in $(seq 1 20); do
        if defaults read com.apple.Terminal "Window Settings" 2>/dev/null | grep -q "name = $PROFILE;"; then
            break
        fi
        sleep 0.5
    done
    info "imported"
fi

defaults write com.apple.Terminal "Default Window Settings" -string "$PROFILE"
defaults write com.apple.Terminal "Startup Window Settings" -string "$PROFILE"
info "set as the default profile -- restart Terminal to pick it up"
