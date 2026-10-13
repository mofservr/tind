#!/bin/bash
# Build every package under packages/ into .deb files (no debhelper needed).
# Output: ../dist/*.deb and a copy in ../config/packages.chroot/ for live-build.
set -euo pipefail
cd "$(dirname "$0")"
OUT="$PWD/../dist"; LB="$PWD/../config/packages.chroot"
mkdir -p "$OUT" "$LB"
rm -f "$OUT"/*.deb "$LB"/*.deb
for d in tind-*/; do
    pkg="${d%/}"
    [ -f "$pkg/DEBIAN/control" ] || continue
    ver="$(sed -n 's/^Version: //p' "$pkg/DEBIAN/control")"
    find "$pkg" -type d -exec chmod 755 {} +
    find "$pkg" -type f ! -path "$pkg/DEBIAN/*" -exec chmod u+rw,go+r,go-w {} +
    [ -d "$pkg/DEBIAN" ] && chmod 755 "$pkg/DEBIAN"
    # installed-size for dpkg
    size="$(du -sk --exclude=DEBIAN "$pkg" | cut -f1)"
    grep -q '^Installed-Size:' "$pkg/DEBIAN/control" || sed -i "/^Description:/i Installed-Size: $size" "$pkg/DEBIAN/control"
    dpkg-deb --root-owner-group -Zxz --build "$pkg" "$OUT/${pkg}_${ver}_all.deb" >/dev/null
    echo "built ${pkg}_${ver}_all.deb"
done
cp "$OUT"/*.deb "$LB"/
