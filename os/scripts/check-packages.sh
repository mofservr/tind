#!/bin/bash
# Check that every package the Tind metapackages and package lists name exists in this Debian's apt.
#   ./scripts/check-packages.sh            check against apt (run on the build machine, trixie)
#   ./scripts/check-packages.sh --list     only print what would be checked
# Depends that cannot be found are errors (the build would fail). Recommends/list entries that
# cannot be found are warnings (apt ignores them).
set -euo pipefail
cd "$(dirname "$0")/.."

names() { # names FIELD  -> unique package names from DEBIAN/control files, alternatives split
    local field="$1" f
    for f in packages/*/DEBIAN/control; do
        awk -v fld="$field" '
            $0 ~ "^"fld":" { on=1; sub("^"fld": *",""); }
            on && /^[A-Za-z-]+:/ && $0 !~ "^"fld":" { on=0 }
            on { print }' "$f"
    done | tr ',|' '\n\n' | sed -e 's/([^)]*)//g' -e 's/[[:space:]]//g' -e '/^$/d' | grep -v '^tind-' | sort -u
}
listnames() { grep -hv -e '^#' -e '^$' config/package-lists/*.chroot 2>/dev/null | grep -v '^tind-' | sort -u || true; }

if [ "${1:-}" = "--list" ]; then
    echo "== Depends";    names Depends
    echo "== Recommends"; names Recommends
    echo "== package-lists"; listnames
    exit 0
fi

have() { apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/ && $2 != "(none)" {ok=1} END{exit !ok}'; }
rc=0
echo "== Depends (must exist)"
for p in $(names Depends); do
    if have "$p"; then echo "ok       $p"; else echo "MISSING  $p"; rc=1; fi
done
echo "== Recommends / package lists (nice to have)"
for p in $( (names Recommends; listnames) | sort -u); do
    if have "$p"; then echo "ok       $p"; else echo "missing  $p"; fi
done
exit $rc
