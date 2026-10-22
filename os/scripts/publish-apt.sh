#!/bin/bash
# publish-apt.sh: build the signed Tind apt repository as a static site (for GitHub Pages).
#
# Two channels (apt suites), both containing only tind-* packages:
#   next    every package version built from main, at once (Morten's own machines follow this)
#   stable  what ISO installs follow: a package version is promoted here HOLD_DAYS (14) days after it first
#           appeared on next. Until then stable keeps serving the previous version. A version listed in
#           os/packages/WITHDRAWN is never promoted. TIND_APT_FAST_TRACK=1 promotes everything at once.
#
# The only state is state/first-seen.json in the published site (first day each package version was seen,
# and which version stable currently serves). It is read back from the live site on every run.
#
# Environment (all optional except the signing key):
#   TIND_APT_SIGNING_KEY   armored private key (the GitHub secret). Required.
#   TIND_APT_URL           live site, default https://apt.servr.no
#   TIND_APT_DEBS          directory with the built .deb files, default ../dist
#   TIND_APT_OUT           output directory, default ./site
#   TIND_APT_HOLD_DAYS     default 14
#   TIND_APT_FAST_TRACK    1 = promote to stable now
#   TIND_APT_FIRST_RUN     1 = there is no live site yet, do not try to read it
#   TIND_APT_PREV_DIR      read the previous site from this directory instead of the URL (tests)
#   TIND_APT_NOW           epoch seconds to use as "now" (tests)
#   TIND_APT_WITHDRAWN     file with "package version" lines, default ../packages/WITHDRAWN
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEBS="${TIND_APT_DEBS:-$HERE/../dist}"
OUT="${TIND_APT_OUT:-$PWD/site}"
BASE_URL="${TIND_APT_URL:-https://apt.servr.no}"
HOLD_DAYS="${TIND_APT_HOLD_DAYS:-14}"
FAST="${TIND_APT_FAST_TRACK:-0}"
FIRST_RUN="${TIND_APT_FIRST_RUN:-0}"
PREV_DIR="${TIND_APT_PREV_DIR:-}"
NOW="${TIND_APT_NOW:-$(date +%s)}"
WITHDRAWN="${TIND_APT_WITHDRAWN:-$HERE/../packages/WITHDRAWN}"

die() { echo "publish-apt: $*" >&2; exit 1; }
[ -n "${TIND_APT_SIGNING_KEY:-}" ] || die "TIND_APT_SIGNING_KEY is not set"
for t in apt-ftparchive dpkg-deb gpg jq xz curl; do command -v "$t" >/dev/null || die "$t is not installed"; done

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export GNUPGHOME="$tmp/gnupg"; mkdir -m 700 "$GNUPGHOME"
printf '%s\n' "$TIND_APT_SIGNING_KEY" | gpg --batch --quiet --import 2>/dev/null || die "cannot import the signing key"
FPR="$(gpg --list-secret-keys --with-colons | awk -F: '$1=="fpr"{print $10; exit}')"
[ -n "$FPR" ] || die "no secret key after import"
echo "signing with key $FPR"

# ---- the packages built from main (these are what "next" serves) ----------------------------------
declare -A VER FILE
shopt -s nullglob
for deb in "$DEBS"/tind-*.deb; do
    pkg="$(dpkg-deb -f "$deb" Package)"; ver="$(dpkg-deb -f "$deb" Version)"; arch="$(dpkg-deb -f "$deb" Architecture)"
    [[ "$pkg" == tind-* ]] || die "$deb: package name $pkg does not start with tind-"
    [ "$arch" = all ] || die "$deb: architecture $arch, only 'all' is published"
    [ -z "${VER[$pkg]:-}" ] || die "two .deb files for $pkg"
    VER[$pkg]="$ver"; FILE[$pkg]="$deb"
done
shopt -u nullglob
[ "${#VER[@]}" -gt 0 ] || die "no tind-*.deb files in $DEBS"
[ -n "${FILE[tind-archive-keyring]:-}" ] || die "tind-archive-keyring is missing from $DEBS"

# ---- previous site: state, and old stable files ------------------------------------------------------
# fetch_prev REL DEST: 0 = fetched, 4 = does not exist, 1 = any other failure (never guess on those)
fetch_prev() {
    local rel="$1" dest="$2" code
    if [ -n "$PREV_DIR" ]; then
        if [ -f "$PREV_DIR/$rel" ]; then cp "$PREV_DIR/$rel" "$dest"; return 0; fi
        return 4
    fi
    # the query string keeps GitHub Pages' edge cache (up to ~10 minutes) from handing back a stale copy
    code="$(curl -sS --retry 3 --retry-delay 5 -o "$dest" -w '%{http_code}' "$BASE_URL/$rel?cb=$(date +%s)")" || return 1
    case "$code" in
        200) return 0 ;;
        404) rm -f "$dest"; return 4 ;;
        *) echo "publish-apt: HTTP $code for $BASE_URL/$rel" >&2; rm -f "$dest"; return 1 ;;
    esac
}

prev='{"first_seen":{},"stable":{},"content":{}}'
if [ "$FIRST_RUN" != 1 ]; then
    rc=0; fetch_prev state/first-seen.json "$tmp/state.json" || rc=$?
    case "$rc" in
        0) jq -e '.first_seen and .stable' "$tmp/state.json" >/dev/null || die "the live state file is not valid"
           prev="$(jq '.content //= {}' "$tmp/state.json")" ;;
        4) echo "no state on the live site: treating this as the first publish" ;;
        *) die "could not read the live state; not publishing (re-run, or set TIND_APT_FIRST_RUN=1 for a first publish)" ;;
    esac
fi

# content_sha DEB: fingerprint of what the package installs (file names, modes, link targets, file hashes,
# control files), so it does not depend on tool versions or timestamps the way the .deb bytes do.
content_sha() {
    local d; d="$(mktemp -d -p "$tmp")"
    dpkg-deb -x "$1" "$d/files"; dpkg-deb -e "$1" "$d/ctl"
    {
        ( cd "$d/files" && find . -printf '%p %m %y %l\n' | LC_ALL=C sort
          find . -type f -exec sha256sum {} + | LC_ALL=C sort -k2 )
        ( cd "$d/ctl" && find . -type f -exec sha256sum {} + | LC_ALL=C sort -k2 )
    } | sha256sum | cut -d' ' -f1
    rm -rf "$d"
}

today="$(date -u -d "@$NOW" +%F)"
state="$prev"
keep='[]'
for pkg in "${!VER[@]}"; do
    key="${pkg}_${VER[$pkg]}"
    csha="$(content_sha "${FILE[$pkg]}")"
    old="$(jq -r --arg k "$key" '.content[$k] // empty' <<<"$prev")"
    if [ -n "$old" ] && [ "$old" != "$csha" ]; then
        die "$pkg ${VER[$pkg]} was published before with different contents. Raise the Version in os/packages/$pkg/DEBIAN/control, otherwise installed computers will not update."
    fi
    state="$(jq --arg k "$key" --arg d "$today" --arg c "$csha" '.first_seen[$k] //= $d | .content[$k] = $c' <<<"$state")"
    keep="$(jq --arg k "$key" '. + [$k]' <<<"$keep")"
done
state="$(jq --argjson keep "$keep" '.first_seen |= with_entries(select(.key as $k | $keep | index($k))) | .content |= with_entries(select(.key as $k | $keep | index($k)))' <<<"$state")"

is_withdrawn() {   # package version
    [ -r "$WITHDRAWN" ] || return 1
    awk -v p="$1" -v v="$2" '!/^[[:space:]]*#/ && $1==p && $2==v {f=1} END{exit !f}' "$WITHDRAWN"
}

# ---- which version does stable serve? ------------------------------------------------------------------
declare -A SVER SFILE
state="$(jq '.stable = {}' <<<"$state")"
for pkg in $(printf '%s\n' "${!VER[@]}" | sort); do
    ver="${VER[$pkg]}"
    eligible=0
    if is_withdrawn "$pkg" "$ver"; then
        echo "$pkg $ver is withdrawn: not promoted"
    elif [ "$FAST" = 1 ]; then
        eligible=1
    else
        seen="$(jq -r --arg k "${pkg}_${ver}" '.first_seen[$k]' <<<"$state")"
        age=$(( (NOW - $(date -u -d "$seen" +%s)) / 86400 ))
        if [ "$age" -ge "$HOLD_DAYS" ]; then eligible=1; else echo "$pkg $ver is $age days old on next (needs $HOLD_DAYS)"; fi
    fi
    pver="$(jq -r --arg p "$pkg" '.stable[$p].version // empty' <<<"$prev")"
    psha="$(jq -r --arg p "$pkg" '.stable[$p].sha256 // empty' <<<"$prev")"
    if [ "$eligible" = 1 ] && { [ -z "$pver" ] || dpkg --compare-versions "$ver" ge "$pver"; }; then
        SVER[$pkg]="$ver"; SFILE[$pkg]="${FILE[$pkg]}"
    elif [ -n "$pver" ]; then
        if [ "$pver" = "$ver" ]; then
            SVER[$pkg]="$ver"; SFILE[$pkg]="${FILE[$pkg]}"
        else
            rel="pool/main/$pkg/${pkg}_${pver}_all.deb"; old="$tmp/old-${pkg}_${pver}_all.deb"
            rc=0; fetch_prev "$rel" "$old" || rc=$?
            [ "$rc" = 0 ] || die "cannot fetch the version of $pkg that stable serves now ($pver)"
            [ "$(sha256sum "$old" | cut -d' ' -f1)" = "$psha" ] || die "$rel does not match the checksum in the live state"
            SVER[$pkg]="$pver"; SFILE[$pkg]="$old"
        fi
    fi
    if [ -n "${SVER[$pkg]:-}" ]; then
        sha="$(sha256sum "${SFILE[$pkg]}" | cut -d' ' -f1)"
        state="$(jq --arg p "$pkg" --arg v "${SVER[$pkg]}" --arg s "$sha" '.stable[$p] = {version: $v, sha256: $s}' <<<"$state")"
    fi
done

# ---- write the site ----------------------------------------------------------------------------------------
rm -rf "$OUT"; mkdir -p "$OUT/state"
for pkg in "${!VER[@]}"; do
    install -D -m 0644 "${FILE[$pkg]}" "$OUT/pool/main/$pkg/${pkg}_${VER[$pkg]}_all.deb"
done
for pkg in "${!SVER[@]}"; do
    install -D -m 0644 "${SFILE[$pkg]}" "$OUT/pool/main/$pkg/${pkg}_${SVER[$pkg]}_all.deb"
done

build_suite() {   # suite, then "pkg file" pairs on stdin
    local suite="$1" t="$tmp/tree-$1" pkg file d="$OUT/dists/$1/main/binary-all"
    mkdir -p "$t/pool/main" "$d"
    while read -r pkg file; do
        [ -n "$pkg" ] || continue
        install -D -m 0644 "$file" "$t/pool/main/$pkg/${pkg}_$(dpkg-deb -f "$file" Version)_all.deb"
    done
    ( cd "$t" && apt-ftparchive packages pool ) > "$d/Packages"
    xz -9 -k -f "$d/Packages"
    # Every package here is architecture "all". apt still asks for the indexes of this computer's architectures
    # (amd64, and i386 where Steam and Wine are set up), and prints "doesn't support architecture" on every
    # update if the repository does not list them. So list them, with empty indexes.
    for a in amd64 i386; do
        mkdir -p "$OUT/dists/$suite/main/binary-$a"
        : > "$OUT/dists/$suite/main/binary-$a/Packages"
        xz -9 -k -f "$OUT/dists/$suite/main/binary-$a/Packages"
    done
    apt-ftparchive \
        -o "APT::FTPArchive::Release::Origin=Tind" -o "APT::FTPArchive::Release::Label=Tind" \
        -o "APT::FTPArchive::Release::Suite=$suite" -o "APT::FTPArchive::Release::Codename=$suite" \
        -o "APT::FTPArchive::Release::Architectures=all amd64 i386" -o "APT::FTPArchive::Release::Components=main" \
        -o "APT::FTPArchive::Release::Description=Tind Linux packages ($suite)" \
        release "$OUT/dists/$suite" > "$tmp/Release.$suite"
    mv "$tmp/Release.$suite" "$OUT/dists/$suite/Release"
    gpg --batch --yes --pinentry-mode loopback --passphrase '' --default-key "$FPR" \
        --clearsign -o "$OUT/dists/$suite/InRelease" "$OUT/dists/$suite/Release"
    gpg --batch --yes --pinentry-mode loopback --passphrase '' --default-key "$FPR" \
        --armor --detach-sign -o "$OUT/dists/$suite/Release.gpg" "$OUT/dists/$suite/Release"
    gpg --batch --verify "$OUT/dists/$suite/InRelease" 2>&1 | head -2
}

for pkg in $(printf '%s\n' "${!VER[@]}" | sort); do echo "$pkg ${FILE[$pkg]}"; done | build_suite next
for pkg in $(printf '%s\n' "${!SVER[@]}" | sort); do echo "$pkg ${SFILE[$pkg]}"; done | build_suite stable

# bootstrap files for computers installed before the repo existed
install -m 0644 "${FILE[tind-archive-keyring]}" "$OUT/tind-archive-keyring.deb"
gpg --armor --export "$FPR" > "$OUT/tind-archive-public.asc"
jq -S . <<<"$state" > "$OUT/state/first-seen.json"
touch "$OUT/.nojekyll"
cat > "$OUT/index.html" <<'EOF'
<!doctype html><meta charset="utf-8"><title>Tind apt repository</title>
<h1>Tind apt repository</h1>
<p>Packages for <a href="https://servr.no/pages/tind/">Tind Linux</a>. Installed systems already use this
address; there is nothing to download here by hand.</p>
EOF

echo "== published to $OUT"
echo "next:   $(for p in $(printf '%s\n' "${!VER[@]}" | sort); do printf '%s=%s ' "${p#tind-}" "${VER[$p]}"; done)"
echo "stable: $(for p in $(printf '%s\n' "${!SVER[@]}" | sort); do printf '%s=%s ' "${p#tind-}" "${SVER[$p]}"; done)"
