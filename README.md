# Tind

A Debian 13 (trixie) based GNOME desktop for daily use and gaming.

```
os/            live-build config, the tind-* packages, build and check scripts
  packages/    tind-branding, -desktop, -graphics, -extensions, -extras, -apps, -mozilla-config, -wireguard, -installer, -optins, -archive-keyring
  config/      live-build package lists, hooks, archives
  auto/        live-build auto scripts
  scripts/     verify-on-debian.sh, check-packages.sh, test-vm.sh, publish-apt.sh, test-publish-apt.sh
  build.sh     build the ISO on a Debian 13 machine
docs/          VERIFY-CHECKLIST.md, THIRD-PARTY.md, servr-wireguard-server.md
.github/       CI: lint, build packages, build the ISO
```

Status: Tind 1 (Stetind). The ISO and the tind-* packages are built and tested in CI (build, UEFI and legacy
BIOS installs, Secure Boot), and the result runs on the author's own desktop and laptop. What has and has not been
tried on real hardware is in `docs/KNOWN-UNTESTED.md`; the design pins are in `docs/DESIGN-PINNED.md`.
