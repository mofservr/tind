#!/bin/bash
# Test publish-apt.sh with a throwaway key: the 14-day promotion, withdrawal, fast-track, and a real
# "apt-get update" and install against the result. Needs the .deb files in os/dist (run packages/build-debs.sh).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PUB="$HERE/publish-apt.sh"
DEBS="$HERE/../dist"
t="$(mktemp -d)"; trap 'rm -rf "$t"' EXIT
fail() { echo "TEST FAILED: $*" >&2; exit 1; }

# throwaway signing key
export GNUPGHOME="$t/gnupg"; mkdir -m 700 "$GNUPGHOME"
gpg --batch --quiet --passphrase '' --quick-generate-key "Tind Test <test@example.invalid>" ed25519 sign never 2>/dev/null
FPR="$(gpg --list-keys --with-colons | awk -F: '$1=="fpr"{print $10; exit}')"
TIND_APT_SIGNING_KEY="$(gpg --armor --export-secret-keys "$FPR")"; export TIND_APT_SIGNING_KEY
gpg --export "$FPR" > "$t/test-keyring.gpg"
unset GNUPGHOME

# a copy of the debs, plus a newer tind-branding built from the real one
mkdir -p "$t/debs1" "$t/debs2"
cp "$DEBS"/tind-*.deb "$t/debs1/"
cp "$DEBS"/tind-*.deb "$t/debs2/"
br="$(ls "$t"/debs2/tind-branding_*_all.deb)"; oldver="$(dpkg-deb -f "$br" Version)"
mkdir "$t/x"; dpkg-deb -R "$br" "$t/x"
newver="${oldver}.1"; sed -i "s/^Version: .*/Version: $newver/" "$t/x/DEBIAN/control"
rm "$br"; dpkg-deb --root-owner-group -Zxz --build "$t/x" "$t/debs2/tind-branding_${newver}_all.deb" >/dev/null

DAY=86400; T0=1792000000
run() {   # name now-offset-days debs prevdir [extra env...]
    local name="$1" off="$2" debs="$3" prev="$4"; shift 4
    local env=(TIND_APT_OUT="$t/$name" TIND_APT_DEBS="$debs" TIND_APT_NOW=$((T0 + off * DAY)) TIND_APT_WITHDRAWN="$t/WITHDRAWN")
    if [ -n "$prev" ]; then env+=(TIND_APT_PREV_DIR="$t/$prev"); else env+=(TIND_APT_FIRST_RUN=1); fi
    env "${env[@]}" "$@" bash "$PUB" > "$t/$name.log" 2>&1 || { cat "$t/$name.log"; fail "$name: publish failed"; }
}
suite_ver() {   # site suite package -> version in that suite's Packages file
    awk -v p="$3" '$1=="Package:"{c=($2==p)} c&&$1=="Version:"{print $2}' "$t/$1/dists/$2/main/binary-all/Packages"
}
expect() { [ "$1" = "$2" ] || fail "$3: expected '$2', got '$1'"; echo "ok: $3"; }
: > "$t/WITHDRAWN"

run s1 0  "$t/debs1" ""
expect "$(suite_ver s1 next tind-branding)"   "$oldver" "day 0: next has the new package"
expect "$(suite_ver s1 stable tind-branding)" ""        "day 0: stable has nothing yet"

run s2 13 "$t/debs1" s1
expect "$(suite_ver s2 stable tind-branding)" ""        "day 13: still held back"

run s3 14 "$t/debs1" s2
expect "$(suite_ver s3 stable tind-branding)" "$oldver" "day 14: promoted to stable"

run s4 20 "$t/debs2" s3
expect "$(suite_ver s4 next tind-branding)"   "$newver" "day 20: next has the newer version"
expect "$(suite_ver s4 stable tind-branding)" "$oldver" "day 20: stable keeps the proven version"
[ -f "$t/s4/pool/main/tind-branding/tind-branding_${oldver}_all.deb" ] || fail "old stable file was not carried over"

run s5 33 "$t/debs2" s4
expect "$(suite_ver s5 stable tind-branding)" "$oldver" "day 33: newer version still too young"

run s6 34 "$t/debs2" s5
expect "$(suite_ver s6 stable tind-branding)" "$newver" "day 34: newer version promoted"

echo "tind-branding $newver" > "$t/WITHDRAWN"
run s7 20 "$t/debs2" s3
expect "$(suite_ver s7 stable tind-branding)" "$oldver" "withdrawn version is never promoted"
: > "$t/WITHDRAWN"

run s8 20 "$t/debs2" s3 TIND_APT_FAST_TRACK=1
expect "$(suite_ver s8 stable tind-branding)" "$newver" "fast-track promotes at once"

# same version, different contents: refused (otherwise computers would never update)
mkdir "$t/same"; cp "$t"/debs1/tind-*.deb "$t/same/"
br1="$(ls "$t"/same/tind-branding_*_all.deb)"; mkdir "$t/z"; dpkg-deb -R "$br1" "$t/z"
mkdir -p "$t/z/usr/share/tind"; echo "changed" >> "$t/z/usr/share/tind/test-marker"; rm "$br1"
dpkg-deb --root-owner-group -Zxz --build "$t/z" "$t/same/tind-branding_${oldver}_all.deb" >/dev/null
if TIND_APT_OUT="$t/same-out" TIND_APT_DEBS="$t/same" TIND_APT_NOW=$((T0 + 5 * DAY)) TIND_APT_PREV_DIR="$t/s1" TIND_APT_WITHDRAWN="$t/WITHDRAWN" bash "$PUB" > "$t/same.log" 2>&1; then fail "changed contents with the same version were accepted"; fi
grep -q "Raise the Version" "$t/same.log" || fail "the version-bump message is missing"
echo "ok: same version with changed contents refused"
# the same package rebuilt (new .deb bytes, same contents) is fine
mkdir "$t/rebuilt"; cp "$t"/debs1/tind-*.deb "$t/rebuilt/"
br2="$(ls "$t"/rebuilt/tind-branding_*_all.deb)"; mkdir "$t/w"; dpkg-deb -R "$br2" "$t/w"; touch -d '2001-01-01' "$t/w/DEBIAN/control"
rm "$br2"; dpkg-deb --root-owner-group -Zgzip --build "$t/w" "$t/rebuilt/tind-branding_${oldver}_all.deb" >/dev/null
TIND_APT_OUT="$t/rebuilt-out" TIND_APT_DEBS="$t/rebuilt" TIND_APT_NOW=$((T0 + 5 * DAY)) TIND_APT_PREV_DIR="$t/s1" TIND_APT_WITHDRAWN="$t/WITHDRAWN" bash "$PUB" > "$t/rebuilt.log" 2>&1 || { cat "$t/rebuilt.log"; fail "an identical rebuild was refused"; }
echo "ok: identical rebuild accepted"

# a package that is not tind-* must be refused
mkdir "$t/bad"; cp "$t"/debs1/tind-branding_*.deb "$t/bad/"; mkdir "$t/y"; dpkg-deb -R "$t/bad/"tind-branding_*.deb "$t/y"
sed -i 's/^Package: .*/Package: evil-branding/' "$t/y/DEBIAN/control"; dpkg-deb --root-owner-group --build "$t/y" "$t/bad/tind-evil.deb" >/dev/null
rm "$t"/bad/tind-branding_*.deb
if TIND_APT_OUT="$t/bad-out" TIND_APT_DEBS="$t/bad" TIND_APT_FIRST_RUN=1 bash "$PUB" >/dev/null 2>&1; then fail "a non tind-* package was accepted"; fi
echo "ok: non tind-* package refused"

# real apt against the day-34 site: signature check, then install
mkdir -p "$t/apt/state/lists/partial" "$t/apt/cache/archives/partial" "$t/apt/etc"
cat > "$t/apt/etc/tind.sources" <<EOF
Types: deb
URIs: file://$t/s6
Suites: stable
Components: main
Signed-By: $t/test-keyring.gpg
EOF
APT=(-o "Dir::Etc::sourcelist=/dev/null" -o "Dir::Etc::sourceparts=$t/apt/etc" -o "Dir::State=$t/apt/state"
     -o "Dir::State::status=/var/lib/dpkg/status" -o "Dir::Cache=$t/apt/cache" -o "Debug::NoLocking=1" -o "APT::Sandbox::User=")
apt-get "${APT[@]}" update 2>&1 | tail -3
got="$(apt-cache "${APT[@]}" policy tind-branding | sed -n 's/^  Candidate: //p')"
expect "$got" "$newver" "real apt-get update verifies the signature and sees the package"

# a tampered InRelease (the signed file apt reads) must be rejected
cp -r "$t/s6" "$t/s6-bad"; sed -i 's/^Label: Tind/Label: Evil/' "$t/s6-bad/dists/stable/InRelease"
grep -q '^Label: Evil' "$t/s6-bad/dists/stable/InRelease" || fail "tamper step did not change anything"
sed -i "s#file://$t/s6#file://$t/s6-bad#" "$t/apt/etc/tind.sources"; rm -rf "$t/apt/state/lists"; mkdir -p "$t/apt/state/lists/partial"
apt-get "${APT[@]}" update > "$t/tamper.log" 2>&1 || true; cat "$t/tamper.log"
if grep -qE "BADSIG|is not signed" "$t/tamper.log"; then echo "ok: tampered InRelease rejected"; else fail "tampered InRelease was not rejected"; fi
echo "ALL PUBLISH TESTS PASSED"
