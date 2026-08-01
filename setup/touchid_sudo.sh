#!/bin/bash
set -e

source "$(dirname "$0")/lib.sh"

# Enable Touch ID for sudo. Apple's sudo_local file survives OS updates,
# unlike editing /etc/pam.d/sudo directly.
# Requires sudo, so this will prompt for your password.

say "Touch ID for sudo"
if grep -qs '^auth[[:space:]]*sufficient[[:space:]]*pam_tid.so' /etc/pam.d/sudo_local; then
    skip "already enabled"
else
    info "this needs your password"
    [ -f /etc/pam.d/sudo_local ] || sudo cp /etc/pam.d/sudo_local.template /etc/pam.d/sudo_local
    sudo sed -i '' 's|^#auth[[:space:]]*sufficient[[:space:]]*pam_tid.so|auth       sufficient     pam_tid.so|' /etc/pam.d/sudo_local
fi
