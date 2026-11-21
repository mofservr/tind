#!/bin/bash
# The News reader box (Liferea and nyhet'r, 21 Nov 2026), with faked commands:
#  1. the shipped OPML files: the first-start list holds one Google Reader source with the full endpoint and no
#     credentials; the NRK list has five https feeds;
#  2. setup-feeds: installs Liferea, diverts Liferea's default feed list once, puts Tind's in its place, enables the
#     user timer; a second run changes nothing; a missing default list only warns;
#  3. tind-feeds (Super+W): Tind Apps without Liferea; Liferea otherwise, with a notice first when the server does
#     not answer;
#  4. feeds-refresh: asks a running Liferea to refresh, and only then (not running, or server silent: no call);
#  5. Super+W in the dconf defaults and the Hotkey overview, the timer and service files, package versions.
# Liferea itself (first-start list, login box, refresh) was run against a mock Google Reader server in the sandbox;
# that is not repeated here.
set -u
cd "$(dirname "$0")/.." || exit 1
repo="$PWD"
extras="$repo/packages/tind-extras"
rc=0
fail() { echo "FAIL $*"; rc=1; }
ok() { echo "ok   $*"; }
expect() { # expect DESCRIPTION ACTUAL PATTERN
    if grep -qE -- "$3" <<< "$2"; then ok "$1"; else fail "$1: got '$2'"; fi
}
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

echo "-- shipped OPML files"
list="$extras/usr/share/tind/feeds/liferea-feedlist.opml"
nrk="$extras/usr/share/tind/feeds/nrk.opml"
python3 -I - "$list" "$nrk" <<'EOF' || rc=1
import sys, xml.etree.ElementTree as ET
bad = 0
def check(cond, text):
    global bad
    print(("ok   " if cond else "FAIL ") + text)
    bad += (not cond)
first = ET.parse(sys.argv[1]).getroot()
outs = list(first.iter("outline"))
check(len(outs) == 1, "first-start list: one outline")
o = outs[0]
check(o.get("type") == "source" and o.get("sourceType") == "fl_google_reader", "first-start list: a Google Reader source")
check(o.get("xmlUrl") == "https://nyhetr.servr.no/api/greader.php", "first-start list: the full endpoint")
check(not any(a in o.attrib for a in ("username", "password")), "first-start list: no credentials")
nrk = ET.parse(sys.argv[2]).getroot()
urls = [x.get("xmlUrl") for x in nrk.iter("outline") if x.get("xmlUrl")]
check(len(urls) == 5 and all(u.startswith("https://www.nrk.no/") and u.endswith("/toppsaker.rss") for u in urls), "NRK list: five https toppsaker feeds")
check(len(set(urls)) == len(urls), "NRK list: no duplicates")
sys.exit(1 if bad else 0)
EOF

echo "-- setup-feeds with faked apt-get, dpkg-divert, systemctl"
mkdir -p "$work/bin" "$work/usr/share/liferea/opml" "$work/usr/share/tind/feeds"
cp "$list" "$work/usr/share/tind/feeds/liferea-feedlist.opml"
cat > "$work/bin/id" <<'F'
#!/bin/bash
echo 0
F
cat > "$work/bin/apt-get" <<'F'
#!/bin/bash
echo "apt-get $*" >> "$ST/calls"
F
cat > "$work/bin/dpkg-divert" <<'F'
#!/bin/bash
echo "dpkg-divert $*" >> "$ST/calls"
case "$1" in
    --list) [ -e "$ST/diverted" ] && echo "local diversion of $2 to $2.distrib" ;;
    *) for last; do :; done
       if [[ " $* " == *" --add "* ]]; then mv "$last" "$last.distrib"; : > "$ST/diverted"; fi ;;
esac
exit 0
F
cat > "$work/bin/systemctl" <<'F'
#!/bin/bash
echo "systemctl $*" >> "$ST/calls"
F
chmod +x "$work/bin/"*
# the script as it would run, with the system paths pointed into the work folder
sed -e "s#/usr/lib/tind/extras-lib.sh#$extras/usr/lib/tind/extras-lib.sh#" \
    -e "s#/usr/share/liferea/opml#$work/usr/share/liferea/opml#" \
    -e "s#/usr/share/tind/feeds#$work/usr/share/tind/feeds#" \
    "$extras/usr/lib/tind/setup-feeds" > "$work/setup-feeds"
default="$work/usr/share/liferea/opml/feedlist_en.opml"
echo "<opml><!-- Liferea's own example feeds --></opml>" > "$default"
export ST="$work"
run() { PATH="$work/bin:$PATH" bash "$work/setup-feeds" "$@" > "$work/out" 2>&1; }
: > "$work/calls"
run || fail "setup-feeds failed: $(tail -5 "$work/out")"
expect "Liferea and the keyring typelib installed" "$(cat "$work/calls")" 'apt-get .*install -y --no-install-recommends liferea gir1.2-secret-1'
expect "the default list diverted" "$(grep -c -- '--add' "$work/calls")" '^1$'
expect "Tind's list in place of the default" "$(grep -c 'fl_google_reader' "$default")" '^1$'
expect "Liferea's own list kept as .distrib" "$(cat "$default.distrib")" 'example feeds'
expect "the 15-minute timer enabled for all users" "$(cat "$work/calls")" 'systemctl --global enable tind-feeds-refresh.timer'
: > "$work/calls"
run || fail "second setup-feeds failed"
expect "second run: no second diversion" "$(grep -c -- '--add' "$work/calls")" '^0$'
expect "second run: Tind's list still in place" "$(grep -c 'fl_google_reader' "$default")" '^1$'
: > "$work/calls"; rm -f "$default" "$work/diverted"
run || fail "setup-feeds without a default list failed"
expect "no default list: a warning, no diversion" "$(cat "$work/out")" 'WARNING: Liferea.s default feed list'
expect "no default list: still no --add" "$(grep -c -- '--add' "$work/calls")" '^0$'
: > "$work/calls"
run nosuchapp 2>/dev/null && fail "an unknown app id was accepted"
expect "unknown app id installs nothing" "$(cat "$work/calls")" '^$'

echo "-- tind-feeds (Super+W)"
fk="$work/fk"; mkdir -p "$fk"
cat > "$fk/notify-send" <<'F'
#!/bin/bash
echo "notify-send $*" >> "$ST/launch"
F
cat > "$fk/curl" <<'F'
#!/bin/bash
[ -e "$ST/silent" ] && exit 92
exit 0
F
cat > "$fk/liferea" <<'F'
#!/bin/bash
echo "liferea $*" >> "$ST/launch"
F
cat > "$fk/tind-optins" <<'F'
#!/bin/bash
echo "tind-optins" >> "$ST/launch"
F
chmod +x "$fk/"*
launch() { : > "$work/launch"; PATH="$1" "$BASH" "$extras/usr/bin/tind-feeds" "${@:2}"; cat "$work/launch"; }
rm -f "$work/silent"
mkdir -p "$work/none"
expect "Liferea not installed: Tind Apps opens" "$(launch "$work/none:/nonexistent" 2>&1 | tail -1)" '(tind-optins|not found)'
cp "$fk/tind-optins" "$work/none/"
expect "Liferea not installed: Tind Apps, nothing else" "$(launch "$work/none")" '^tind-optins$'
expect "server answers: Liferea opens, no notice" "$(launch "$fk")" '^liferea $'
expect "server answers: arguments pass through" "$(launch "$fk" -w shown)" '^liferea -w shown$'
: > "$work/silent"
out="$(launch "$fk")"
expect "server silent: a notice names the network" "$out" 'notify-send .*not reachable from this network'
expect "server silent: the notice says the password is not wrong" "$out" 'password is not wrong'
expect "server silent: Liferea still opens" "$out" 'liferea $'
rm -f "$work/silent"

echo "-- feeds-refresh (every 15 minutes)"
rf="$work/rf"; mkdir -p "$rf"
cp "$fk/curl" "$rf/curl"
cat > "$rf/gdbus" <<'F'
#!/bin/bash
echo "gdbus $*" >> "$ST/gdbus"
if [[ "$*" == *NameHasOwner* ]]; then
    if [ -e "$ST/running" ]; then echo "(true,)"; else echo "(false,)"; fi
fi
F
chmod +x "$rf/gdbus"
refresh() { : > "$work/gdbus"; PATH="$rf" "$BASH" "$extras/usr/lib/tind/feeds-refresh"; echo "exit=$?"; grep -c 'Reader.Refresh' "$work/gdbus"; }
rm -f "$work/running" "$work/silent"
expect "Liferea not running: no Refresh call, exit 0" "$(refresh | tr '\n' ' ')" 'exit=0 0'
: > "$work/running"
expect "Liferea running, server answers: one Refresh call" "$(refresh | tr '\n' ' ')" 'exit=0 1'
: > "$work/silent"
expect "Liferea running, server silent: no Refresh call" "$(refresh | tr '\n' ' ')" 'exit=0 0'
rm -f "$work/silent"
mkdir -p "$work/nogdbus"; cp "$fk/curl" "$work/nogdbus/"
PATH="$work/nogdbus" "$BASH" "$extras/usr/lib/tind/feeds-refresh"; expect "no gdbus: exit 0" "$?" '^0$'
expect "the name is checked before the call (never starts Liferea)" "$(grep -n 'NameHasOwner\|Reader.Refresh' "$extras/usr/lib/tind/feeds-refresh" | head -2 | tr '\n' ' ')" 'NameHasOwner.*Reader.Refresh'

echo "-- Super+W, units, versions"
dconf="$repo/packages/tind-branding/etc/dconf/db/local.d/00-tind"
expect "tind-feeds in the custom keybinding list" "$(grep '^custom-keybindings=' "$dconf")" 'custom-keybindings/tind-feeds/'
sect="$(awk '/^\[org\/gnome\/settings-daemon\/plugins\/media-keys\/custom-keybindings\/tind-feeds\]/{on=1;next} /^\[/{on=0} on' "$dconf")"
expect "Super+W runs tind-feeds" "$sect" "command='tind-feeds'"
expect "Super+W binding" "$sect" "binding='<Super>w'"
expect "Super+W is bound once" "$(grep -ci "binding='<Super>w'" "$dconf")" '^1$'
expect "Hotkey overview lists the news reader" "$(grep -c "'tind-feeds', 'News reader'" "$repo/packages/tind-desktop/usr/bin/tind-hotkeys")" '^1$'
timer="$extras/usr/lib/systemd/user/tind-feeds-refresh.timer"
service="$extras/usr/lib/systemd/user/tind-feeds-refresh.service"
expect "timer: every 15 minutes" "$(cat "$timer")" 'OnUnitActiveSec=15min'
expect "timer: wanted by timers.target" "$(cat "$timer")" 'WantedBy=timers.target'
expect "service: runs the refresh helper" "$(cat "$service")" 'ExecStart=/usr/lib/tind/feeds-refresh$'
for f in usr/bin/tind-feeds usr/lib/tind/feeds-refresh usr/lib/tind/setup-feeds; do
    if [ -x "$extras/$f" ]; then ok "$f is executable"; else fail "$f is not executable"; fi
done
ev="$(sed -n 's/^Version: //p' "$extras/DEBIAN/control")"
need="$(sed -n 's/^Depends:.*tind-extras (>= \([0-9.]*\)).*/\1/p' "$repo/packages/tind-optins/DEBIAN/control")"
expect "tind-optins needs a tind-extras that has setup-feeds ($ev, needs >= $need)" "$(printf '%s\n%s\n' "$need" "$ev" | sort -V | tail -1)" "^$ev$"
exit "$rc"
