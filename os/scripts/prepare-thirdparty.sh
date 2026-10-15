#!/bin/bash
# Fetch Proton's release package, check its SHA-256 against the value on Proton's install page,
# and write the live-build archive config from the key and repo line inside it. Needs network.
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck disable=SC1091
. ./third-party.env
mkdir -p config/archives config/package-lists
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

echo "Fetching $PROTON_RELEASE_URL"
curl -fsSL "$PROTON_RELEASE_URL" -o "$tmp/proton-release.deb"
got="$(sha256sum "$tmp/proton-release.deb" | cut -d' ' -f1)"
if [ "$got" != "$PROTON_RELEASE_SHA256" ]; then
    echo "Proton release package checksum mismatch: got $got" >&2; exit 1
fi
dpkg-deb -x "$tmp/proton-release.deb" "$tmp/x"
echo "== contents of Proton's release package"; (cd "$tmp/x" && find . -type f | sort)
key="$(cd "$tmp/x" && find . -type f \( -name '*.gpg' -o -name '*.asc' -o -name '*.pgp' \) | head -1)"
src="$(cd "$tmp/x" && find ./etc/apt/sources.list.d -type f 2>/dev/null | head -1)"
[ -n "$key" ] || { echo "No key found in Proton's release package" >&2; exit 1; }
[ -n "$src" ] || { echo "No apt source found in Proton's release package" >&2; exit 1; }
echo "== key $key"; gpg --show-keys --with-fingerprint "$tmp/x/$key" || true
echo "== source $src"; cat "$tmp/x/$src"
# live-build imports *.key.chroot into the chroot's trusted keys itself, so no signed-by is needed.
if gpg --show-keys "$tmp/x/$key" >/dev/null 2>&1; then
    gpg --dearmor < "$tmp/x/$key" > config/archives/protonvpn.key.chroot 2>/dev/null \
        || cp "$tmp/x/$key" config/archives/protonvpn.key.chroot
fi
# take URI, suite and components from the packaged source (deb822 or one-line), drop signed-by
if grep -q '^URIs:' "$tmp/x/$src"; then
    uri="$(awk '/^URIs:/{print $2}' "$tmp/x/$src")"; suite="$(awk '/^Suites:/{print $2}' "$tmp/x/$src")"
    comps="$(sed -n 's/^Components: *//p' "$tmp/x/$src")"
    echo "deb $uri $suite $comps" > config/archives/protonvpn.list.chroot
else
    grep -E '^deb ' "$tmp/x/$src" | head -1 | sed -E 's/\[[^]]*\] *//' > config/archives/protonvpn.list.chroot
fi
cat config/archives/protonvpn.list.chroot
echo "$PROTON_PACKAGE" > config/package-lists/protonvpn.list.chroot
echo "Proton VPN repository configured for the build."
