#!/bin/bash
# Tind Apps (tind-optins, tind-extras), per-app choice of 10 Nov 2026:
#  1. every box's APPS ids match the ids its setup script takes (pick_apps), and every package or Flatpak an APPS
#     check names is installed by that script, so the window's "installed" cannot drift from what the scripts do;
#  2. `tind-optins --status` with faked dpkg-query, flatpak and apt-cache: alternatives, all-of checks, apt? hiding,
#     box states installed, partial and missing;
#  3. pick_apps and want in extras-lib.sh; the window's Python compiles.
set -u
cd "$(dirname "$0")/.." || exit 1
optins="$PWD/packages/tind-optins/usr/share/tind/optins.d"
cli="$PWD/packages/tind-optins/usr/bin/tind-optins"
lib="$PWD/packages/tind-extras/usr/lib/tind/extras-lib.sh"
rc=0
fail() { echo "FAIL $*"; rc=1; }
ok() { echo "ok   $*"; }

echo "-- APPS lines against the box scripts"
for f in "$optins"/*.optin; do
    box="$(basename "$f" .optin)"
    # shellcheck disable=SC1090
    eval "$(unset NAME DESC STATUS SCRIPT APT_PACKAGES APPS; . "$f"
            printf 'script=%q apt=%q apps=%q\n' "${SCRIPT:-}" "${APT_PACKAGES:-}" "${APPS:-}")"
    # shellcheck disable=SC2154  # set by the eval above
    ids="$(printf '%s\n' "$apps" | awk -F'|' 'NF>=4 {print $1}' | sort | tr '\n' ' ')"
    [ -n "$ids" ] || { fail "$box: no APPS lines"; continue; }
    # shellcheck disable=SC2154
    if [ -n "$script" ]; then
        src="$PWD/packages/tind-extras${script}"
        [ -r "$src" ] || { fail "$box: $script not in tind-extras"; continue; }
        want_ids="$(sed -n 's/^pick_apps "\([^"]*\)".*/\1/p' "$src" | tr ' ' '\n' | sort | tr '\n' ' ')"
        if [ "$ids" = "$want_ids" ]; then ok "$box: ids match $script"; else fail "$box: APPS ids '$ids' vs pick_apps '$want_ids'"; fi
        text="$(cat "$src")"
    else
        # shellcheck disable=SC2154
        text="$apt"
    fi
    while IFS='|' read -r id _name _about check; do
        [ -n "$id" ] || continue
        for alt in $check; do
            for p in $(tr '+' ' ' <<< "${alt#*:}"); do
                if grep -qwF -- "$p" <<< "$text"; then :; else fail "$box:$id: $p is not installed by ${script:-APT_PACKAGES}"; fi
            done
        done
    done <<< "$apps"
done

echo "-- tind-optins --status with faked package tools"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin"
cat > "$work/bin/dpkg-query" <<'F'
#!/bin/bash
for p in "${@:3}"; do if grep -qx "$p" "$ST/apt" 2>/dev/null; then echo "$p ii "; else echo "no packages found matching $p" >&2; fi; done
exit 1
F
cat > "$work/bin/flatpak" <<'F'
#!/bin/bash
cat "$ST/flatpak" 2>/dev/null; true
F
cat > "$work/bin/apt-cache" <<'F'
#!/bin/bash
grep -qx "$2" "$ST/known" 2>/dev/null
F
chmod +x "$work/bin/"*
export ST="$work" TIND_OPTINS_DIR="$optins"
st() { PATH="$work/bin:$PATH" bash "$cli" --status; }
line() { st | awk -F'\t' -v k="$1" -v a="$2" -v b="$3" '$1==k && $2==a && $3==b'; }
expect() { # expect DESCRIPTION ACTUAL PATTERN
    if grep -qE -- "$3" <<< "$2"; then ok "$1"; else fail "$1: got '$2'"; fi
}
: > "$work/apt"; : > "$work/flatpak"; : > "$work/known"
expect "nothing installed: Games missing" "$(st | awk -F'\t' '$1=="box" && $2=="gaming"')" $'\tmissing\t0/7\t'
expect "Xbox drivers hidden when Debian lacks them" "$(line app gaming xbox)" '^$'
echo xone-dkms > "$work/known"
expect "Xbox drivers offered when Debian has one" "$(line app gaming xbox)" $'\tmissing\t'
printf '%s\n' nextcloud-desktop git build-essential pipx > "$work/apt"
expect "Nextcloud alone: productivity partial" "$(st | awk -F'\t' '$1=="box" && $2=="productivity"')" $'\tpartial\t1/2\t'
expect "Nextcloud installed" "$(line app productivity nextcloud)" $'\tinstalled\t'
expect "all-of check: basics missing without gh" "$(line app developer basics)" $'\tmissing\t'
echo gh >> "$work/apt"
expect "all-of check: basics installed with gh" "$(line app developer basics)" $'\tinstalled\t'
echo org.telegram.desktop > "$work/flatpak"
expect "alternative: Telegram from Flathub counts" "$(line app communication telegram)" $'\tinstalled\t'
printf '%s\n' libreoffice-writer libreoffice-calc libreoffice-impress >> "$work/apt"
expect "whole box installed" "$(st | awk -F'\t' '$1=="box" && $2=="productivity"')" $'\tinstalled\t2/2\t'
expect "--list runs" "$(PATH="$work/bin:$PATH" bash "$cli" --list)" 'productivity:nextcloud +\[installed\]'
expect "install refuses a bad spec" "$(bash "$cli" install 'gaming:steam;rm' 2>&1)" 'invalid'
expect "install refuses an unknown box" "$(bash "$cli" install nosuchbox 2>&1)" 'unknown box'

echo "-- pick_apps and want"
pw() { ( need_root() { :; }; # shellcheck source=/dev/null
         . "$lib"; pick_apps "a b c" "$@" >/dev/null; for x in a b c; do if want "$x"; then printf '%s' "$x"; fi; done ) 2>/dev/null; }
expect "no names: whole box" "$(pw)" '^abc$'
expect "one name" "$(pw b)" '^b$'
expect "commas" "$(pw a,c)" '^ac$'
# shellcheck source=/dev/null
( . "$lib"; pick_apps "a b c" d >/dev/null 2>&1 ); r=$?
if [ "$r" = 2 ]; then ok "unknown name stops with 2"; else fail "unknown name: exit $r"; fi

echo "-- the window compiles"
if python3 -c 'import ast,sys; ast.parse(open(sys.argv[1]).read())' "$PWD/packages/tind-optins/usr/lib/tind/tind-apps-window"; then
    ok "tind-apps-window parses"
else
    fail "tind-apps-window does not parse"
fi
exit "$rc"
