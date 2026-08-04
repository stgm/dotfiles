#!/bin/bash
set -e

source "$(dirname "$0")/lib.sh"

is_mac || { skip "the Terminal profile is macOS only"; exit 0; }

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

# Read both keys first, so a re-run leaves the preferences untouched
for key in "Default Window Settings" "Startup Window Settings"; do
    if [ "$(defaults read com.apple.Terminal "$key" 2>/dev/null || true)" = "$PROFILE" ]; then
        skip "$key is already $PROFILE"
    else
        defaults write com.apple.Terminal "$key" -string "$PROFILE"
        info "$key set to $PROFILE -- restart Terminal to pick it up"
    fi
done
