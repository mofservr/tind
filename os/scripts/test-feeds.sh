#!/bin/bash
# The News reader box (NewsFlash and nyhet'r, 22 Nov 2026), with faked commands:
#  1. the NRK list (imported once on the server's web page): five https feeds, no duplicates;
#  2. setup-feeds: installs NewsFlash from Flathub; an unknown app id installs nothing;
#  3. tind-feeds (Super+W): Tind Apps without NewsFlash; NewsFlash otherwise, with the server address shown the first
#     time only;
#  4. Super+W in the dconf defaults and the Hotkey overview, no refresh timer left, package versions.
set -u
cd "$(dirname "$0")/.." || exit 1
repo="$PWD"
extras="$repo/packages/tind-extras"
app="io.gitlab.news_flash.NewsFlash"
rc=0
fail() { echo "FAIL $*"; rc=1; }
ok() { echo "ok   $*"; }
expect() { # expect DESCRIPTION ACTUAL PATTERN
    if grep -qE -- "$3" <<< "$2"; then ok "$1"; else fail "$1: got '$2'"; fi
}
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
export ST="$work"

echo "-- NRK list"
python3 -I - "$extras/usr/share/tind/feeds/nrk.opml" <<'EOF' || rc=1
import sys, xml.etree.ElementTree as ET
urls = [x.get("xmlUrl") for x in ET.parse(sys.argv[1]).getroot().iter("outline") if x.get("xmlUrl")]
good = len(urls) == 5 and all(u.startswith("https://www.nrk.no/") and u.endswith("/toppsaker.rss") for u in urls)
print(("ok   " if good else "FAIL ") + "NRK list: five https toppsaker feeds")
print(("ok   " if len(set(urls)) == len(urls) else "FAIL ") + "NRK list: no duplicates")
sys.exit(0 if good and len(set(urls)) == len(urls) else 1)
EOF

echo "-- setup-feeds with faked flatpak"
mkdir -p "$work/bin"
cat > "$work/bin/id" <<'F'
#!/bin/bash
echo 0
F
cat > "$work/bin/flatpak" <<'F'
#!/bin/bash
echo "flatpak $*" >> "$ST/calls"
F
chmod +x "$work/bin/"*
sed -e "s#/usr/lib/tind/extras-lib.sh#$extras/usr/lib/tind/extras-lib.sh#" "$extras/usr/lib/tind/setup-feeds" > "$work/setup-feeds"
run() { PATH="$work/bin:$PATH" "$BASH" "$work/setup-feeds" "$@" > "$work/out" 2>&1; }
: > "$work/calls"
run || fail "setup-feeds failed: $(tail -5 "$work/out")"
expect "NewsFlash installed from Flathub" "$(cat "$work/calls")" "flatpak install --system -y --noninteractive flathub $app"
: > "$work/calls"
run newsflash || fail "setup-feeds newsflash failed"
expect "the single app id works" "$(cat "$work/calls")" "install .*$app"
: > "$work/calls"
run nosuchapp && fail "an unknown app id was accepted"
expect "unknown app id installs nothing" "$(cat "$work/calls")" '^$'

echo "-- tind-feeds (Super+W)"
fk="$work/fk"; mkdir -p "$fk"
cat > "$fk/flatpak" <<'F'
#!/bin/bash
case "$1" in
    info) [ -e "$ST/installed" ] ;;
    run) shift; echo "run $*" >> "$ST/launch" ;;
esac
F
cat > "$fk/notify-send" <<'F'
#!/bin/bash
echo "notify-send $*" >> "$ST/launch"
F
cat > "$fk/tind-optins" <<'F'
#!/bin/bash
echo "tind-optins" >> "$ST/launch"
F
chmod +x "$fk/"*
home="$work/home"; mkdir -p "$home"
launch() { : > "$work/launch"; HOME="$home" PATH="$fk" "$BASH" "$extras/usr/bin/tind-feeds" "$@"; cat "$work/launch"; }
rm -f "$work/installed"
expect "NewsFlash not installed: Tind Apps, nothing else" "$(launch)" '^tind-optins$'
: > "$work/installed"
out="$(launch)"
expect "first run: a notice with the server address" "$out" "notify-send .*https://nyhetr.servr.no/api/greader.php"
expect "first run: NewsFlash opens" "$out" "^run $app\$"
mkdir -p "$home/.var/app/$app"
expect "later runs: NewsFlash only, no notice" "$(launch)" "^run $app\$"
expect "arguments pass through" "$(launch --foo)" "^run $app --foo\$"

echo "-- Super+W, leftovers, versions"
dconf="$repo/packages/tind-branding/etc/dconf/db/local.d/00-tind"
expect "tind-feeds in the custom keybinding list" "$(grep '^custom-keybindings=' "$dconf")" 'custom-keybindings/tind-feeds/'
sect="$(awk '/^\[org\/gnome\/settings-daemon\/plugins\/media-keys\/custom-keybindings\/tind-feeds\]/{on=1;next} /^\[/{on=0} on' "$dconf")"
expect "Super+W runs tind-feeds" "$sect" "command='tind-feeds'"
expect "Super+W binding" "$sect" "binding='<Super>w'"
expect "Super+W is bound once" "$(grep -ci "binding='<Super>w'" "$dconf")" '^1$'
expect "Hotkey overview lists the news reader" "$(grep -c "'tind-feeds', 'News reader'" "$repo/packages/tind-desktop/usr/bin/tind-hotkeys")" '^1$'
if [ -e "$extras/usr/lib/systemd/user/tind-feeds-refresh.timer" ]; then fail "the refresh timer is still shipped"; else ok "no refresh timer shipped"; fi
expect "postinst drops the old timer link" "$(cat "$extras/DEBIAN/postinst")" 'rm -f /etc/systemd/user/timers.target.wants/tind-feeds-refresh.timer'
expect "the box names NewsFlash from Flathub" "$(grep '^newsflash|' "$repo/packages/tind-optins/usr/share/tind/optins.d/feeds.optin")" "flatpak:$app\$"
for f in usr/bin/tind-feeds usr/lib/tind/setup-feeds; do
    if [ -x "$extras/$f" ]; then ok "$f is executable"; else fail "$f is not executable"; fi
done
ev="$(sed -n 's/^Version: //p' "$extras/DEBIAN/control")"
need="$(sed -n 's/^Depends:.*tind-extras (>= \([0-9.]*\)).*/\1/p' "$repo/packages/tind-optins/DEBIAN/control")"
expect "tind-optins needs this tind-extras ($ev, needs >= $need)" "$need" "^$ev$"
exit "$rc"
