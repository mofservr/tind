#!/bin/bash
# shellcheck disable=SC2034  # variables are read inside the eval'd check conditions
# Test /usr/lib/tind/wired-profiles (tind-desktop) with a faked NetworkManager, ip and /sys/class/net:
# saved wired settings must follow a card that got a new name (31 Oct 2026: an HBA was added, enp6s0
# became enp10s0, the saved DNS server was lost), and nothing else may be moved.
set -u
cd "$(dirname "$0")/.." || exit 1
script="$PWD/packages/tind-desktop/usr/lib/tind/wired-profiles"
rc=0
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin"
# State: $ST/p/<uuid> holds key=value lines (id, ifname, mac, autoconnect, master, file); $ST/active holds
# "dev uuid" lines; $ST/calls records every change. $TIND_SYSNET/<dev>/{device,type,mac,permaddr,wireless}.
cat > "$work/bin/nmcli" <<'F'
#!/bin/bash
get() { sed -n "s/^$2=//p" "$ST/p/$1"; }
args=("$@"); set --
for a in "${args[@]}"; do set -- "$@" "$a"; done
case "$*" in
    "-t -f UUID,TYPE,FILENAME connection show")
        for f in "$ST"/p/*; do [ -e "$f" ] || continue; u="${f##*/}"; echo "$u:$(get "$u" type):$(get "$u" file)"; done ;;
    "-e no -g "*" connection show "*)
        u="$7"; [ -e "$ST/p/$u" ] || exit 10
        case "$4" in
            connection.interface-name) get "$u" ifname ;; 802-3-ethernet.mac-address) get "$u" mac ;;
            connection.autoconnect) get "$u" autoconnect ;; connection.master) get "$u" master ;;
            connection.id) get "$u" id ;; *) exit 2 ;;
        esac ;;
    "connection modify "*)
        u="$3"; echo "modify $u $4=$5 $6=$7" >> "$ST/calls"
        [ -n "${TD_MODIFY_FAILS:-}" ] && exit 1
        sed -i -e "s/^ifname=.*/ifname=$5/" -e "s/^mac=.*/mac=$7/" "$ST/p/$u" ;;
    "-w 30 connection up "*)
        echo "up $5 $7" >> "$ST/calls"; echo "$7 $5" >> "$ST/active" ;;
    *) echo "fake nmcli: unhandled: $*" >&2; exit 99 ;;
esac
F
cat > "$work/bin/ip" <<'F'
#!/bin/sh
# ip -o link show dev N
d="$TIND_SYSNET/$5"
[ -e "$d" ] || exit 1
extra=""; [ -e "$d/permaddr" ] && extra=" permaddr $(cat "$d/permaddr")"
echo "2: $5: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP mode DEFAULT group default qlen 1000\    link/ether $(cat "$d/mac") brd ff:ff:ff:ff:ff:ff$extra"
F
printf '#!/bin/sh\nexit 0\n' > "$work/bin/logger"
chmod +x "$work/bin/"*

reset() {
    export ST="$work/st" TIND_SYSNET="$work/sys" TIND_WP_LOG="$work/st/log"
    rm -rf "$ST" "$TIND_SYSNET"; mkdir -p "$ST/p" "$TIND_SYSNET"; : > "$ST/calls"; : > "$ST/active"
    unset TD_MODIFY_FAILS
}
card() { # card NAME MAC [wifi|virtual]
    local d="$TIND_SYSNET/$1"; mkdir -p "$d"; echo "$2" > "$d/mac"; echo 1 > "$d/type"
    [ "${3:-}" = virtual ] || mkdir -p "$d/device"
    [ "${3:-}" = wifi ] && mkdir -p "$d/wireless"
    return 0
}
profile() { # profile UUID ID IFNAME MAC [autoconnect] [file] [master]
    printf 'type=802-3-ethernet\nid=%s\nifname=%s\nmac=%s\nautoconnect=%s\nfile=%s\nmaster=%s\n' \
        "$2" "$3" "$4" "${5:-yes}" "${6:-/etc/NetworkManager/system-connections/$2.nmconnection}" "${7:-}" > "$ST/p/$1"
}
blank() { profile "$1" "$2" "$3" "" yes "/run/NetworkManager/system-connections/$2.nmconnection"; echo "$3 $1" >> "$ST/active"; }
run() { PATH="$work/bin:$PATH" "$script" "$@"; }
check() { # check NAME 'CONDITION'
    if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; sed 's/^/     calls: /' "$ST/calls"; rc=1; fi
}
val() { sed -n "s/^$2=//p" "$ST/p/$1"; }

# 1. 31 Oct: GNOME-made profile with only the name, card renamed by a new card earlier on the bus
reset; card enp10s0 aa:bb:cc:00:00:01; profile u1 "Wired connection 1" enp6s0 ""; blank u2 "Wired connection 2" enp10s0
out="$(run check)"; r=$?
check "31 Oct: check says renamed card, exit 1" '[ $r = 1 ] && grep -q "tied to enp6s0" <<< "$out" && grep -q "got a new name (enp10s0)" <<< "$out"'
run fix >/dev/null
check "31 Oct: profile moved to the card's MAC, name cleared" '[ "$(val u1 ifname)" = "" ] && [ "$(val u1 mac)" = AA:BB:CC:00:00:01 ]'
check "31 Oct: card switched over to the saved profile" 'grep -qx "up u1 enp10s0" "$ST/calls"'
check "31 Oct: blank profile left alone (gone at reboot)" '! grep -q "u2" "$ST/calls" && [ -e "$ST/p/u2" ]'
check "31 Oct: move written to the log" 'grep -q "Wired connection 1. moved from enp6s0 to enp10s0" "$TIND_WP_LOG"'
out="$(run check)"; r=$?
check "31 Oct: check is ok afterwards and shows the move" '[ $r = 0 ] && grep -q "^ok:" <<< "$out" && grep -q "moved earlier" <<< "$out"'
# 2. profile with a MAC and the old name: moved whatever the names look like
reset; card enp3s0 aa:bb:cc:00:00:02; profile u1 home eno1 AA:BB:CC:00:00:02; blank u2 "Wired connection 1" enp3s0
run fix >/dev/null
check "MAC saved: moved although eno1 -> enp3s0 is not a bus change" '[ "$(val u1 ifname)" = "" ] && grep -qx "up u1 enp3s0" "$ST/calls"'
# 3. permanent MAC wins over a cloned one
reset; card enp2s0 02:00:00:00:00:99; echo aa:bb:cc:00:00:03 > "$TIND_SYSNET/enp2s0/permaddr"; profile u1 home enp1s0 AA:BB:CC:00:00:03
run fix >/dev/null
check "cloned MAC: matched by the permanent one" '[ "$(val u1 ifname)" = "" ] && [ "$(val u1 mac)" = AA:BB:CC:00:00:03 ]'
# 4. name only, two wired cards: not moved
reset; card enp10s0 aa:bb:cc:00:00:04; card enp11s0 aa:bb:cc:00:00:05; profile u1 "Wired connection 1" enp6s0 ""
run fix >/dev/null
check "two wired cards: not moved" '! grep -q modify "$ST/calls"'
# 5. name only, an unplugged USB adapter's profile; the built-in card is on a blank profile
reset; card enp3s0 aa:bb:cc:00:00:06; profile u1 dongle enp0s20f0u1 ""; blank u2 "Wired connection 1" enp3s0
run fix >/dev/null; out="$(run check)"; r=$?
check "unplugged USB adapter: not moved onto the built-in card" '! grep -q modify "$ST/calls"'
check "unplugged USB adapter: check exit 0, says why not moved" '[ $r = 0 ] && grep -q "not the same card on another bus" <<< "$out"'
# 6. name only, the card has its own saved settings: not moved, check ok
reset; card enp3s0 aa:bb:cc:00:00:07; profile u1 old enp2s0 ""; profile u2 mine enp3s0 ""
run fix >/dev/null; out="$(run check)"; r=$?
check "card has its own settings: not moved" '! grep -q modify "$ST/calls"'
check "card has its own settings: check exit 0 but lists the stray profile" '[ $r = 0 ] && grep -q "old. is tied to enp2s0" <<< "$out"'
# 7. a profile tied to nothing matches every card: no orphan, no bare card
reset; card enp3s0 aa:bb:cc:00:00:08; profile u1 any "" ""
out="$(run check)"; r=$?; run fix >/dev/null
check "profile tied to nothing: ok, nothing changed" '[ $r = 0 ] && grep -q "^ok:" <<< "$out" && ! grep -q modify "$ST/calls"'
# 8. autoconnect off: moved, not started
reset; card enp10s0 aa:bb:cc:00:00:09; profile u1 manual enp6s0 "" no
run fix >/dev/null
check "autoconnect off: moved but not started" 'grep -q "modify u1" "$ST/calls" && ! grep -q "^up" "$ST/calls"'
# 9. two name-only orphans, one card: not moved
reset; card enp10s0 aa:bb:cc:00:00:0a; profile u1 a enp6s0 ""; profile u2 b enp7s0 ""
run fix >/dev/null
check "two unmatched profiles: not moved" '! grep -q modify "$ST/calls"'
# 10. same bus, other slot (not a bus renumbering): not moved
reset; card enp6s1 aa:bb:cc:00:00:0b; profile u1 a enp6s0 ""
run fix >/dev/null
check "other slot, same bus: not moved" '! grep -q modify "$ST/calls"'
# 11. Wi-Fi and virtual devices do not count as wired cards
reset; card enp10s0 aa:bb:cc:00:00:0c; card wlp2s0 aa:bb:cc:00:00:0d wifi; card docker0 02:42:00:00:00:01 virtual
profile u1 "Wired connection 1" enp6s0 ""
run fix >/dev/null
check "Wi-Fi and docker0 ignored: still one wired card, moved" 'grep -q "modify u1" "$ST/calls"'
# 12. bond port: left alone
reset; card enp10s0 aa:bb:cc:00:00:0e
profile u1 port enp6s0 "" yes /etc/NetworkManager/system-connections/port.nmconnection bond0
run fix >/dev/null
check "bond port: left alone" '! grep -q modify "$ST/calls"'
# 13. MAC saved, card not here: left alone
reset; card enp3s0 aa:bb:cc:00:00:0f; profile u1 laptop-dock enx001122334455 00:11:22:33:44:55
run fix >/dev/null
check "MAC of an absent card: left alone" '! grep -q modify "$ST/calls"'
# 14. nmcli refuses the change: fix exits 1, nothing logged as moved
reset; card enp10s0 aa:bb:cc:00:00:10; profile u1 "Wired connection 1" enp6s0 ""; export TD_MODIFY_FAILS=1
run fix >/dev/null; r=$?
check "change refused: exit 1, no move logged, not started" '[ $r = 1 ] && [ ! -e "$TIND_WP_LOG" ] && ! grep -q "^up" "$ST/calls"'
# 15. nothing saved at all (fresh install): ok, nothing to do
reset; card enp1s0 aa:bb:cc:00:00:11; blank u1 "Wired connection 1" enp1s0
out="$(run check)"; r=$?; run fix >/dev/null; r2=$?
check "fresh install: check ok, fix does nothing" '[ $r = 0 ] && [ $r2 = 0 ] && [ ! -s "$ST/calls" ]'

exit "$rc"
