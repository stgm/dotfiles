#!/bin/bash
set -e

source "$(dirname "$0")/lib.sh"

is_mac || { skip "macOS defaults do not apply here"; exit 0; }

say "macOS defaults"

changed=0
failed=0

# Reads the current value first, so a re-run writes nothing and leaves Finder
# and Dock running. Reports failed writes.
set_default() {
    local domain="$1" key="$2" type="$3" value="$4" want current

    # `defaults read` prints booleans as 0/1, so compare against that
    if [ "$type" = -bool ] && [ "$value" = true ]; then
        want=1
    elif [ "$type" = -bool ]; then
        want=0
    else
        want="$value"
    fi

    current="$(defaults read "$domain" "$key" 2>/dev/null || true)"
    [ "$current" = "$want" ] && return

    if defaults write "$domain" "$key" "$type" "$value" 2>/dev/null; then
        changed=1
    else
        failed=1
        skip "could not write $domain $key"
    fi
}

# Show window title bar icons everywhere (needs Full Disk Access)
set_default com.apple.universalaccess showWindowTitlebarIcons -bool true

# Do not convert double-space into space-dot!!!
set_default NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false

# Disable "smart" quotes and dashes everywhere, not just in TextEdit
set_default NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
set_default NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

# Show hidden files + all extensions in Finder
set_default com.apple.finder AppleShowAllFiles -bool true
set_default NSGlobalDomain AppleShowAllExtensions -bool true

# Folders at top of listings in Finder
set_default com.apple.finder _FXSortFoldersFirst -bool true

# Show path bar in Finder
set_default com.apple.finder ShowPathbar -bool true

# Show full url in Safari address bar
set_default com.apple.Safari ShowFullURLInSmartSearchField -bool true

if [ "$changed" -eq 1 ]; then
    info "applied, restarting Finder and Dock"
    killall Finder Dock 2>/dev/null || true
elif [ "$failed" -eq 0 ]; then
    skip "already set"
fi
