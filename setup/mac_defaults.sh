#!/bin/bash
set -e

source "$(dirname "$0")/lib.sh"

say "macOS defaults"

# Reports failed writes
set_default() {
    defaults write "$@" 2>/dev/null || skip "could not write $1 $2"
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

info "applied, restarting Finder and Dock"
killall Finder Dock 2>/dev/null || true
