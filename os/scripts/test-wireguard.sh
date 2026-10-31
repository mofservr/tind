#!/bin/bash
# shellcheck disable=SC2034  # variables are read inside the eval'd check conditions
# Test how tind-enroll picks the tunnel's endpoint address, with faked nmcli, resolvectl, ip and logger:
#  - the endpoint name is looked up only through the DNS of the links that carry the default route,
#    never through the tunnel's own link (which gives the public address and hairpins at home);
#  - refresh writes the new address into the profile and reconnects only when it changed;
#  - a profile from 0.3.1 or older (name in the profile) is taken over;
#  - no answer on this network keeps the address the profile has;
#  - with a LAN_ENDPOINT: tried once per network (told apart by the gateway's MAC), kept only if the
#    server answers through it, so at home it wins even when the router's DNS gives the public address.
# It tests Tind's logic, not real NetworkManager or systemd-resolved.
set -u
cd "$(dirname "$0")/.." || exit 1
enroll="$PWD/packages/tind-wireguard/usr/bin/tind-enroll"
watchdog="$PWD/packages/tind-wireguard/usr/lib/tind/wireguard-watchdog"
rc=0
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# setup DIR ENDPOINT_IN_PROFILE: a fake world where wlan0 and the tunnel both carry routes
setup() {
    local d="$1"
    mkdir -p "$d/bin" "$d/keys"
    cat > "$d/profile" <<P
[connection]
id=tind-servr
type=wireguard
interface-name=tind-servr

[wireguard-peer.SERVERKEYSERVERKEYSERVERKEYSERVERKEYSERVERK=]
endpoint=$2
allowed-ips=10.0.0.0/24;
persistent-keepalive=25

[ipv4]
dns=10.0.0.1;
method=manual
P
    echo "${2}" > "$d/wg-endpoint"
    cat > "$d/bin/nmcli" <<F
#!/bin/sh
echo "\$*" >> "$d/nmcli.calls"
case "\$*" in
    "-t -f NAME,FILENAME connection show") echo "Wired:/x/Wired.nmconnection"; echo "tind-servr:$d/profile" ;;
    "-t -f NAME connection show") echo Wired; echo tind-servr ;;
    "-t -g GENERAL.STATE connection show tind-servr") echo activated ;;
esac
exit 0
F
    cat > "$d/bin/ip" <<F
#!/bin/sh
case "\$*" in
    "neigh show"*) echo "192.168.1.1 lladdr \${TD_GWMAC:-aa:aa:aa:00:00:01} REACHABLE"; exit 0 ;;
esac
[ -n "\${TD_NOROUTE:-}" ] && exit 0
echo "default via 192.168.1.1 dev wlan0 proto dhcp metric 600"
echo "default dev tind-servr scope link metric 50"
F
    # the running tunnel: its endpoint lives in a file; the handshake age comes from TD_HSAGE
    cat > "$d/bin/wg" <<F
#!/bin/sh
k=SERVERKEYSERVERKEYSERVERKEYSERVERKEYSERVERK=
case "\$*" in
    "show tind-servr peers") echo "\$k" ;;
    "show tind-servr endpoints") printf '%s\\t%s\\n' "\$k" "\$(cat "$d/wg-endpoint")" ;;
    "show tind-servr latest-handshakes") echo "\$k \$(( \$(date +%s) - \${TD_HSAGE:-10} ))" ;;
    "set tind-servr peer \$k endpoint "*) echo "\$6" > "$d/wg-endpoint"; echo "\$*" >> "$d/wg.calls" ;;
    *) exit 1 ;;
esac
F
    # the server answers a tunnel ping only if the running endpoint is reachable from here:
    # its LAN address only at home (TD_HOME=1), any other address always
    cat > "$d/bin/ping" <<F
#!/bin/sh
echo "\$*" >> "$d/ping.calls"
ep="\$(cat "$d/wg-endpoint")"
case "\$ep" in 192.168.1.37:*) [ -n "\${TD_HOME:-}" ] ;; *) exit 0 ;; esac
F
    # the tunnel's DNS answers with the public address, the home network's DNS with the LAN address
    cat > "$d/bin/resolvectl" <<'F'
#!/bin/sh
dev=""; while [ $# -gt 0 ]; do [ "$1" = "-i" ] && dev="$2"; shift; done
case "$dev" in
    tind-servr) echo "vpn.servr.no: 203.0.113.7 -- link: tind-servr" ;;
    wlan0) [ -n "${TD_NODNS:-}" ] && exit 1; echo "vpn.servr.no: ${TD_ANSWER:-192.168.1.37} -- link: wlan0" ;;
    *) exit 1 ;;
esac
F
    printf '#!/bin/sh\necho "$*" >> "%s/log"\n' "$d" > "$d/bin/logger"
    chmod +x "$d/bin/"*
}

run() { # run DIR ARGS...: tind-enroll with the fakes first in PATH
    local d="$1"; shift
    PATH="$d/bin:$PATH" TIND_WG_KEYDIR="$d/keys" "$enroll" "$@"
}

check() { # check NAME 'SHELL CONDITION' (evaluated whole, so && and ! stay inside the check)
    if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; rc=1; fi
}
ups() { grep -c "^connection up" "$1/nmcli.calls" 2>/dev/null || true; }
pings() { [ -f "$1/ping.calls" ] && wc -l < "$1/ping.calls" || echo 0; }
ep() { sed -n 's/^endpoint=//p' "$1/profile"; }

# 1. old profile with the name: taken over, LAN address from wlan0 (not the tunnel's public answer)
d="$work/1"; setup "$d" vpn.servr.no:51820
out="$(run "$d" refresh)"
check "old profile: name saved" 'grep -qx '\''vpn.servr.no:51820'\'' "$d/keys/endpoint"'
check "old profile: LAN address from the uplink, not the tunnel" 'grep -qx '\''endpoint=192.168.1.37:51820'\'' "$d/profile"'
check "old profile: reported changed and reconnected" '[ "$out" = changed ] && [ "$(ups "$d")" = 1 ]'
check "old profile: profile reloaded" 'grep -q "^connection load $d/profile" "$d/nmcli.calls"'

# 2. same answer again: nothing touched
out="$(run "$d" refresh)"
check "unchanged: no reconnect" '[ -z "$out" ] && [ "$(ups "$d")" = 1 ]'

# 3. another network answers with the public address: profile follows
out="$(TD_ANSWER=198.51.100.9 run "$d" refresh)"
check "moved: new address written" 'grep -qx '\''endpoint=198.51.100.9:51820'\'' "$d/profile"'
check "moved: reconnected once more" '[ "$out" = changed ] && [ "$(ups "$d")" = 2 ]'

# 4. no DNS answer on this network: keep the address, no reconnect
out="$(TD_NODNS=1 run "$d" refresh)"
check "no answer: address kept" 'grep -qx '\''endpoint=198.51.100.9:51820'\'' "$d/profile"'
check "no answer: no reconnect, logged" '[ -z "$out" ] && [ "$(ups "$d")" = 2 ] && grep -q "could not look up" "$d/log"'

# 5. offline (no default route): keep the address
out="$(TD_NOROUTE=1 run "$d" refresh)"
check "offline: address kept" '[ -z "$out" ] && grep -qx '\''endpoint=198.51.100.9:51820'\'' "$d/profile"'

# 6. no tunnel installed: refresh does nothing and succeeds
d="$work/6"; setup "$d" x:1
printf '#!/bin/sh\necho "$*" >> "%s/nmcli.calls"\nexit 0\n' "$d" > "$d/bin/nmcli"
out="$(run "$d" refresh)"; r=$?
check "no tunnel: exit 0, nothing written" '[ "$r" = 0 ] && [ -z "$out" ] && [ ! -e "$d/keys/endpoint" ]'

# 7. the watchdog resets its handshake clock after a refresh that reconnected, and does not bounce
d="$work/7"; setup "$d" vpn.servr.no:51820
printf '#!/bin/sh\necho changed\n' > "$d/bin/fake-enroll"; chmod +x "$d/bin/fake-enroll"
# a stale clock (no handshake for 1000 s) would make it bounce; after a reconnect it must not
mkdir -p "$d/state"; echo $(( $(date +%s) - 1000 )) > "$d/state/ref"
PATH="$d/bin:$PATH" TD_HSAGE=1000 TIND_ENROLL="$d/bin/fake-enroll" TIND_WG_STATE="$d/state" "$watchdog"
check "watchdog: clock reset after a reconnect, no bounce" '[ "$(cat "$d/state/ref")" -ge $(( $(date +%s) - 5 )) ] && ! grep -q "^connection down" "$d/nmcli.calls"'
# control: with nothing changed, the same stale clock does bounce
d="$work/8"; setup "$d" vpn.servr.no:51820
printf '#!/bin/sh\nexit 0\n' > "$d/bin/fake-enroll"; chmod +x "$d/bin/fake-enroll"
mkdir -p "$d/state"; echo $(( $(date +%s) - 1000 )) > "$d/state/ref"
PATH="$d/bin:$PATH" TD_HSAGE=1000 TIND_ENROLL="$d/bin/fake-enroll" TIND_WG_STATE="$d/state" "$watchdog"
check "watchdog: stale tunnel still bounces" 'grep -q "^connection down" "$d/nmcli.calls"'

# 9. LAN endpoint at home, where the router's DNS gives the PUBLIC address (the laptop's case)
d="$work/9"; setup "$d" 198.51.100.9:51820
mkdir -p "$d/keys"; echo vpn.servr.no:51820 > "$d/keys/endpoint"; echo 192.168.1.37:51820 > "$d/keys/lan-endpoint"
lan() { PATH="$d/bin:$PATH" TIND_WG_KEYDIR="$d/keys" TIND_WG_RUN="$d/run" TD_ANSWER=198.51.100.9 "$enroll" refresh; }
out="$(TD_HOME=1 lan)"
check "LAN at home: chosen although DNS says public" '[ "$out" = lan ] && [ "$(ep "$d")" = 192.168.1.37:51820 ]'
check "LAN at home: running tunnel on it, no reconnect" '[ "$(cat "$d/wg-endpoint")" = 192.168.1.37:51820 ] && [ "$(ups "$d")" = 0 ]'
check "LAN at home: proved through the tunnel" 'grep -q -- "-I tind-servr 10.0.0.1" "$d/ping.calls"'

# 10. same network a minute later: no new try
n="$(pings "$d")"; out="$(TD_HOME=1 lan)"
check "LAN at home again: kept without a new ping" '[ "$out" = lan ] && [ "$(pings "$d")" = "$n" ]'

# 11. at a friend's: same gateway address, other router (MAC); LAN does not answer, back to the lookup
out="$(TD_GWMAC=bb:bb:bb:00:00:02 lan)"
check "LAN away: falls back to the public address and reconnects" '[ "$out" = changed ] && [ "$(ep "$d")" = 198.51.100.9:51820 ] && [ "$(ups "$d")" = 1 ]'
check "LAN away: logged" 'grep -q "does not answer on its LAN address" "$d/log"'

# 12. still at the friend's: no new try, nothing changes
n="$(pings "$d")"; echo 198.51.100.9:51820 > "$d/wg-endpoint"; out="$(TD_GWMAC=bb:bb:bb:00:00:02 lan)"
check "LAN away again: no new try, no change" '[ -z "$out" ] && [ "$(pings "$d")" = "$n" ] && [ "$(ups "$d")" = 1 ]'

# 13. home again: tried again and taken, without a reconnect
out="$(TD_HOME=1 lan)"
check "LAN home again: back on the LAN address" '[ "$out" = lan ] && [ "$(ep "$d")" = 192.168.1.37:51820 ] && [ "$(ups "$d")" = 1 ]'

# 14. LAN in use but the handshake is stale: tried again, falls back when it no longer answers
out="$(TD_HSAGE=600 lan)"
check "LAN stale: tried again and dropped" '[ "$out" = changed ] && [ "$(ep "$d")" = 198.51.100.9:51820 ]'

# 15. something moved the running tunnel away from the profile: put back, no reconnect
d="$work/15"; setup "$d" 198.51.100.9:51820
mkdir -p "$d/keys"; echo vpn.servr.no:51820 > "$d/keys/endpoint"; echo 203.0.113.7:51820 > "$d/wg-endpoint"
out="$(TD_ANSWER=198.51.100.9 run "$d" refresh)"
check "drift: running tunnel put back on the profile" '[ -z "$out" ] && [ "$(cat "$d/wg-endpoint")" = 198.51.100.9:51820 ] && [ "$(ups "$d")" = 0 ]'

# 16. enrolment blocks: LAN_ENDPOINT stored; one inside the tunnel's own network refused
d="$work/16"; setup "$d" x:1; echo dummykey > "$d/keys/private.key"
block() { printf 'ADDRESS=10.0.0.12/32\nSERVER_ENDPOINT=vpn.servr.no:51820\nSERVER_PUBLIC_KEY=SERVERKEYSERVERKEYSERVERKEYSERVERKEYSERVERK=\nALLOWED_IPS=10.0.0.0/24\nDNS_SERVER=10.0.0.1\n%s\n' "$1" > "$d/block"; }
block LAN_ENDPOINT=10.0.0.1:51820
out="$(PATH="$d/bin:$PATH" TIND_WG_KEYDIR="$d/keys" TIND_WG_RUN="$d/run" "$enroll" apply "$d/block" 2>&1)"; r=$?
check "block: LAN_ENDPOINT inside ALLOWED_IPS refused" '[ "$r" != 0 ] && grep -q "must not be inside ALLOWED_IPS" <<< "$out"'
block LAN_ENDPOINT=192.168.1.37:51820
PATH="$d/bin:$PATH" TIND_WG_KEYDIR="$d/keys" TIND_WG_RUN="$d/run" "$enroll" apply "$d/block" >/dev/null 2>&1; r=$?
check "block: LAN_ENDPOINT stored" '[ "$r" = 0 ] && grep -qx 192.168.1.37:51820 "$d/keys/lan-endpoint"'
block ""
PATH="$d/bin:$PATH" TIND_WG_KEYDIR="$d/keys" TIND_WG_RUN="$d/run" "$enroll" apply "$d/block" >/dev/null 2>&1
check "block without it: LAN endpoint removed" '[ ! -e "$d/keys/lan-endpoint" ]'

exit "$rc"
