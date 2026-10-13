#!/bin/bash
# Fetch third-party apt keys and write live-build archive config for them (currently Proton VPN).
# Needs network and gpg. Shows the key fingerprint so a human can compare it with the vendor's page.
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck disable=SC1091
. ./third-party.env
mkdir -p config/archives config/package-lists
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

echo "Fetching Proton VPN repository key from $PROTON_KEY_URL"
curl -fsSL "$PROTON_KEY_URL" -o "$tmp/proton.asc"
gpg --show-keys --with-fingerprint "$tmp/proton.asc"
echo
echo "Compare the fingerprint above with the one on Proton's official Linux install page."
if [ "${TIND_ASSUME_KEYS_OK:-0}" != 1 ]; then
    read -r -p "Does it match? [y/N] " ans
    [ "$ans" = y ] || { echo "Aborted." >&2; exit 1; }
fi
# live-build imports *.key.chroot into the chroot's trusted keys itself, so no signed-by is needed here
cp "$tmp/proton.asc" config/archives/protonvpn.key.chroot
echo "deb $PROTON_REPO_URL $PROTON_SUITE $PROTON_COMPONENT" > config/archives/protonvpn.list.chroot
echo "$PROTON_PACKAGE" > config/package-lists/protonvpn.list.chroot
echo "Proton VPN repository configured for the build."
