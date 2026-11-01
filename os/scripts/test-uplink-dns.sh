#!/bin/bash
# Test /usr/lib/tind/uplink-dns (tind-desktop) with faked ip and resolvectl: it must say when the link
# that carries the internet has no DNS server, as on the desktop on 31 Oct 2026 (the card got a new
# name, its new profile had no DNS, only the tunnel's link had one).
set -u
cd "$(dirname "$0")/.." || exit 1
script="$PWD/packages/tind-desktop/usr/lib/tind/uplink-dns"
rc=0
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin"
# TD_V4 / TD_V6: default-route lines; TD_GLOBAL: global DNS; TD_LINKDNS: "dev=servers" pairs
cat > "$work/bin/ip" <<'F'
#!/bin/sh
case "$*" in
    "-4 route show default") [ -n "${TD_V4:-}" ] && echo "$TD_V4" ;;
    "-6 route show default") [ -n "${TD_V6:-}" ] && echo "$TD_V6" ;;
esac
exit 0
F
cat > "$work/bin/resolvectl" <<'F'
#!/bin/sh
[ "$1" = dns ] || exit 1
if [ -z "${2:-}" ]; then echo "Global: ${TD_GLOBAL:-}"; exit 0; fi
for pair in ${TD_LINKDNS:-}; do
    [ "${pair%%=*}" = "$2" ] && { echo "Link 2 ($2): ${pair#*=}" | tr ',' ' '; exit 0; }
done
echo "Link 2 ($2):"
F
chmod +x "$work/bin/"*
run() { PATH="$work/bin:$PATH" "$script"; }
check() { # check NAME EXPECTED_RC PATTERN (output must match)
    local out r
    out="$(run)"; r=$?
    if [ "$r" = "$2" ] && grep -qE "$3" <<< "$out"; then echo "ok   $1"; else echo "FAIL $1 (rc $r: $out)"; rc=1; fi
}

TD_V4="default via 192.168.1.1 dev enp10s0 proto dhcp metric 100" TD_LINKDNS="enp10s0=192.168.1.37" \
    check "card with DNS" 0 '^enp10s0: 192\.168\.1\.37$'
export TD_V4="default via 192.168.1.1 dev enp10s0 proto dhcp metric 100"
TD_LINKDNS="tind-servr=10.0.0.1" check "31 Oct: card without DNS, tunnel's DNS does not count" 1 '^enp10s0: NONE'
TD_GLOBAL="1.1.1.1" check "card without DNS but a global server" 0 'global: 1\.1\.1\.1'
TD_V6="default via fe80::1 dev wlan0 proto ra" TD_LINKDNS="enp10s0=192.168.1.37" \
    check "IPv6-only link without DNS is caught" 1 '^wlan0: NONE'
unset TD_V4
check "offline: no default route, no warning" 0 '^no default route'

exit "$rc"
