#!/bin/bash
# Collect the facts the plan could not verify offline. Run on a Debian 13 machine and read the output.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
echo "== release"; # shellcheck disable=SC1091
. /etc/os-release; echo "$PRETTY_NAME"
[ "${VERSION_CODENAME:-}" = trixie ] || echo "WARNING: not trixie"
echo; echo "== disk (need ~25 GB free here)"; df -h . | tail -1
echo; echo "== KVM"; [ -e /dev/kvm ] && echo "available" || echo "not available (VM tests will be slow)"
echo; echo "== live-build"; command -v lb >/dev/null && lb --version || echo "not installed"
if command -v lb >/dev/null; then
    echo; echo "== lb config options used by auto/config"
    for o in $(grep -o -- '--[a-z-]*' auto/config | sort -u); do
        lb config --help 2>&1 | grep -q -- "$o" && echo "ok       $o" || echo "UNKNOWN  $o"
    done
fi
echo; echo "== uBlock Origin package: where does it install?"
dpkg -L webext-ublock-origin-firefox 2>/dev/null | head -20 || apt-cache show webext-ublock-origin-firefox | head -5
echo; echo "== Firefox ESR: policy locations it will read (after install)"
ls -ld /etc/firefox/policies /usr/lib/firefox-esr/distribution 2>&1
echo "(open about:policies in Firefox ESR: Active should list Tind's policies)"
echo; echo "== Calamares branding setting"
grep -n '^branding' /etc/calamares/settings.conf 2>&1
echo; echo "== Dash to Dock package / UUID"
apt-cache policy gnome-shell-extension-dashtodock | head -3
ls /usr/share/gnome-shell/extensions 2>&1 | head
echo; echo "== package names"; ./scripts/check-packages.sh || true
