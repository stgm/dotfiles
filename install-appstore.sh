#!/bin/bash
set -e

source "$(dirname "$0")/setup/lib.sh"

APPSTORE="$(dirname "$0")/setup/Appstore"

# Not part of install.sh: the App Store cannot tell us whether an app is in the
# signed-in Apple Account, so installing one it never bought pops up a
# "redownload is not possible" dialog. Run this by hand on a Mac where the apps
# are actually bought.
say "App Store apps"

installed="$(mas list | awk '{print $1}')"

while read -r id name; do
    if printf '%s\n' "$installed" | grep -qx "$id"; then
        skip "$name already installed"
        continue
    fi

    info "installing $name..."
    mas install "$id" || skip "$name could not be installed -- see: mas open $id"
done < <(grep -E '^[0-9]+' "$APPSTORE")
