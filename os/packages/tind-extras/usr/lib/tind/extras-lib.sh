# shellcheck shell=bash
# Shared helpers for the Tind extras scripts.
export DEBIAN_FRONTEND=noninteractive

need_root() { [ "$(id -u)" -eq 0 ] || { echo "run as root" >&2; exit 1; }; }

# Make sure Debian's contrib, non-free and non-free-firmware are enabled (Steam needs non-free).
ensure_components() {
    local f
    for f in /etc/apt/sources.list.d/*.sources; do
        [ -f "$f" ] || continue
        grep -qiE '^URIs:.*debian\.org' "$f" || continue
        sed -i -E '/^Components:/{s/$/ /; /contrib/! s/ $/ contrib /; /non-free /! s/ $/ non-free /; /non-free-firmware/! s/ $/ non-free-firmware /; s/ +$//}' "$f"
    done
    if [ -f /etc/apt/sources.list ]; then
        sed -i -E '/^deb .*debian\.org/{/ non-free( |$)/! s/$/ contrib non-free non-free-firmware/}' /etc/apt/sources.list
    fi
}

# First boot often overlaps with another apt run (PackageKit, daily timers). Wait for the lock
# instead of failing, but only retry on lock errors, never on real failures.
apt-get() {
    local n=0 out rc
    while :; do
        out="$(command apt-get -o DPkg::Lock::Timeout=600 "$@" 2>&1)"; rc=$?
        printf '%s\n' "$out"
        if [ "$rc" -ne 0 ] && grep -q 'Could not get lock' <<<"$out" && [ $((n += 1)) -lt 60 ]; then
            echo "apt is busy, waiting (try $n)..." >&2; sleep 10; continue
        fi
        return "$rc"
    done
}

apt_install() { apt-get install -y --no-install-recommends "$@"; }

# Small apps come from Flathub, system-wide (same remote as Tind Apps uses).
flatpak_install() {
    command -v flatpak >/dev/null 2>&1 || apt_install flatpak
    flatpak remote-add --system --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak install --system -y --noninteractive flathub "$@"
}

# Run a nice-to-have step: a failure is logged but does not fail the whole stack.
optional() {
    local what="$1"; shift
    "$@" || echo "WARNING: $what failed; continuing" >&2
}

# apt_or_flatpak PACKAGE FLATPAK_ID: Debian's package when this release has one, Flathub otherwise.
apt_or_flatpak() {
    if apt-cache show "$1" >/dev/null 2>&1; then apt_install "$1"; else flatpak_install "$2"; fi
}
