#!/bin/bash
set -e

source "$(dirname "$0")/lib.sh"

say "course-site"
if [ -d ~/dev/stgm/course-site ]; then
    skip "already cloned"
else
    git clone git@github.com:stgm/course-site.git ~/dev/stgm/course-site
fi

mkdir -p ~/dev/stgm/course-site/config/credentials

if [ -f ~/dev/stgm/course-site/config/credentials/development.key ]; then
    skip "development credentials key already present"
else
    read -rsp "    Paste development.key for course-site dev credentials: " dev_key
    echo
    printf '%s' "$dev_key" > ~/dev/stgm/course-site/config/credentials/development.key
    chmod 600 ~/dev/stgm/course-site/config/credentials/development.key
fi

skip "edit credentials using: bin/rails credentials:edit --environment development"

cd ~/dev/stgm/course-site

say "Set up Ruby and gems in the course-site clone"
# Install the Ruby pinned in .ruby-version, then the gems. Both steps read
# their current state first so a re-run does nothing.
# .ruby-version may pin a series (3.4) rather than an exact release (3.4.10),
# so match the installed ruby-<version> directory on a component boundary.
ruby_version="$(tr -d '[:space:]' < .ruby-version 2>/dev/null || true)"
if [ -n "$ruby_version" ] &&
    rv ruby list --installed-only 2>/dev/null |
    grep -qE "ruby-${ruby_version//./\\.}([./]|$)"; then
    skip "Ruby $ruby_version already installed"
else
    rv ruby install
fi

if rv run bundle check >/dev/null 2>&1; then
    skip "gems already installed"
else
    rv ci
fi

say "Development database"
rv run bin/rails db:prepare
