#!/bin/bash
# The GPU rule of nvidia-upgrade, tested without a GPU. A stub lspci prints the cards, the real script decides
# (TIND_NVIDIA_CHECK_ONLY stops it before it touches the network). Two parts:
#   1. a table of cards and combinations, which must always pass;
#   2. a sweep of every NVIDIA graphics chip in the PCI ID database (pci.ids): Turing, Ampere, Hopper, Ada and
#      Blackwell must carry on, everything older must stay on Debian's driver.
# The sweep fails the test only with --strict (CI's nvidia-test workflow); the build only prints what differs.
# Needs root, as the script does.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../packages/tind-graphics/usr/lib/tind/nvidia-upgrade"
STRICT=0; [ "${1:-}" = "--strict" ] && STRICT=1
[ "$(id -u)" -eq 0 ] || { echo "SKIP: needs root (the script under test refuses to run otherwise)"; exit 0; }
t="$(mktemp -d)"; trap 'rm -rf "$t"' EXIT
fail() { echo "TEST FAILED: $*" >&2; exit 1; }
mkdir -p "$t/bin"
printf '#!/bin/sh\nprintf "%%s" "$FAKE_LSPCI"\n' > "$t/bin/lspci"; chmod +x "$t/bin/lspci"

card() {   # id [class]: one lspci line
    local cls="${2:-VGA compatible controller [0300]}"
    printf '01:00.0 %s: NVIDIA Corporation Test [GeForce] [10de:%s] (rev a1)\n' "$cls" "$1"
}
verdict() {   # lspci text -> older | carry | none
    local out
    rm -f "$t"/state.*
    out="$(FAKE_LSPCI="$1" PATH="$t/bin:$PATH" TIND_NVIDIA_STATE="$t/state" TIND_NVIDIA_CHECK_ONLY=1 bash "$SCRIPT" 2>&1 || true)"
    if [ -e "$t/state.done" ]; then
        case "$(cat "$t/state.done")" in older*) echo older ;; "no NVIDIA GPU") echo none ;; *) echo "state:$(cat "$t/state.done")" ;; esac
    elif echo "$out" | grep -q "would carry on"; then echo carry
    else echo "unexpected:$out"; fi
}
expect() {   # label want got
    [ "$2" = "$3" ] || fail "$1: expected '$2', got '$3'"
    echo "ok: $1 -> $2"
}

# 1. table
expect "no NVIDIA card"                            none  "$(verdict "")"
expect "1dff, just below Turing"                   older "$(verdict "$(card 1dff)")"
expect "1e00, first Turing id"                     carry "$(verdict "$(card 1e00)")"
expect "GTX 750 Ti (Maxwell, 1380)"                older "$(verdict "$(card 1380)")"
expect "GTX 1080 (Pascal, 1b80)"                   older "$(verdict "$(card 1b80)")"
expect "GT 1030 (Pascal, 1d01)"                    older "$(verdict "$(card 1d01)")"
expect "TITAN V (Volta, 1d81)"                     older "$(verdict "$(card 1d81)")"
expect "RTX 2070 (Turing, 1f02)"                   carry "$(verdict "$(card 1f02)")"
expect "GTX 1650 (Turing, 1f82)"                   carry "$(verdict "$(card 1f82)")"
expect "GTX 1660 Ti (Turing, 2182)"                carry "$(verdict "$(card 2182)")"
expect "RTX 3090 (Ampere, 2204)"                   carry "$(verdict "$(card 2204)")"
expect "RTX 4090 (Ada, 2684)"                      carry "$(verdict "$(card 2684)")"
expect "RTX 4060 (Ada, 2882)"                      carry "$(verdict "$(card 2882)")"
expect "RTX 3090 and GTX 1080 together"            older "$(verdict "$(card 2204; card 1b80)")"
expect "RTX 3090 and RTX 4090 together"            carry "$(verdict "$(card 2204; card 2684)")"
expect "laptop dGPU as a 3D controller (2684)"     carry "$(verdict "$(card 2684 '3D controller [0302]')")"
expect "old card as a 3D controller (1b80)"        older "$(verdict "$(card 1b80 '3D controller [0302]')")"
expect "audio function of a Pascal card is ignored" carry "$(verdict "$(card 2204; card 0fb9 'Audio device [0403]')")"

# 2. every NVIDIA graphics chip in pci.ids
IDS=""; for f in /usr/share/misc/pci.ids /usr/share/hwdata/pci.ids; do [ -r "$f" ] && { IDS="$f"; break; }; done
if [ -z "$IDS" ]; then
    echo "SKIP sweep: no pci.ids (install the pci.ids package)"; [ "$STRICT" = 0 ] || fail "sweep needs pci.ids"
    echo "NVIDIA RULE TESTS PASSED (table only)"; exit 0
fi
awk '
/^10de  / { v = 1; next }
v && /^[^\t#]/ { v = 0 }
v && /^\t[0-9a-f][0-9a-f][0-9a-f][0-9a-f]  / {
    id = substr($0, 2, 4); name = substr($0, 8)
    if (name ~ /NVSwitch/) next
    if (match(name, /^[A-Za-z0-9]+ \[/)) {
        code = substr(name, 1, RLENGTH - 2)
        if (code ~ /^(TU|GA|GH|AD|GB)[0-9]/) print id, "new", name
        else if (code ~ /^(NV|G|GT|GF|GK|GM|GP|GV|C|MCP|IGP)[0-9]/) print id, "old", name
    }
}' "$IDS" > "$t/chips.txt"
new=0; old=0; bad=0
while read -r id cls name; do
    want=older; [ "$cls" = new ] && want=carry
    got="$(verdict "$(card "$id")")"
    if [ "$cls" = new ]; then new=$((new + 1)); else old=$((old + 1)); fi
    if [ "$got" != "$want" ]; then bad=$((bad + 1)); echo "DIFFERS: 10de:$id $name ($cls, rule says $got)"; fi
done < "$t/chips.txt"
echo "sweep of $IDS: $new Turing-or-newer chips, $old older chips, $bad differ from the rule"
[ "$new" -gt 100 ] && [ "$old" -gt 500 ] || fail "the sweep found too few chips ($new new, $old old); pci.ids could not be read"
if [ "$bad" -gt 0 ] && [ "$STRICT" = 1 ]; then fail "$bad chips disagree with the 0x1e00 rule"; fi
echo "NVIDIA RULE TESTS PASSED"
