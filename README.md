# Tind

A Debian 13 (trixie) based GNOME desktop for daily use and gaming. Cold mountain, warm welcome.

```
os/            live-build config, the tind-* packages, build and check scripts
  packages/    tind-branding, -desktop, -apps, -mozilla-config, -wireguard, -installer, -optins
  config/      live-build package lists, hooks, archives
  auto/        live-build auto scripts
  scripts/     verify-on-debian.sh, check-packages.sh, prepare-thirdparty.sh, test-vm.sh
  build.sh     build the ISO on a Debian 13 machine
docs/          VERIFY-CHECKLIST.md, THIRD-PARTY.md, servr-wireguard-server.md
.github/       CI: lint, build packages, build the ISO
```

Status: scaffolding. The visuals (logo, wallpapers, ice theme, Plymouth/GRUB art) in `tind-branding`
are placeholders and are being redone. CI is how the build gets proven; see `docs/VERIFY-CHECKLIST.md`.
