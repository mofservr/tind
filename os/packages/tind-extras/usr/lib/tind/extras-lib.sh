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

apt_install() { apt-get install -y --no-install-recommends "$@"; }
