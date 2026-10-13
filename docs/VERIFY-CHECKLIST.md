# Verify checklist: what is built but not yet proven

I could not boot anything: the cloud workspace has no route to the Debian mirror and no GNOME session. Everything below was written carefully but never run end to end.

## Proven here

- All shell scripts pass `shellcheck` and `bash -n`. `tind-enroll` was run against stubs (help, key creation, the default-route guard).
- All 7 `.deb` packages build with `dpkg-deb`; contents inspected.
- JSON files parse. SVG and PNG assets rendered and checked by eye. Palette tokens generate from one source.

## Run first on a Debian 13 machine

`./os/scripts/verify-on-debian.sh` prints most of the facts below. Then `./os/scripts/check-packages.sh` checks every package name against apt.

| # | Item | How to check | If wrong |
|---|---|---|---|
| 1 | live-build options in `auto/config` exist | `verify-on-debian.sh` lists `UNKNOWN` options | edit `auto/config`; run `lb config --help` |
| 2 | Package names exist in trixie | `check-packages.sh` (Depends missing = build fails) | rename in `packages/*/DEBIAN/control` |
| 3 | uBlock Origin is enabled automatically in Firefox ESR | install, open Firefox, check `about:addons` | Debian may disable system extensions by default (`extensions.autoDisableScopes`); pin it with the `ExtensionSettings` policy using the local file path from `dpkg -L webext-ublock-origin-firefox` |
| 4 | Firefox reads `/etc/firefox/policies/` | open `about:policies`, status should be Active | the package also ships a copy under `/usr/lib/firefox-esr/distribution/`; keep whichever works |
| 5 | Each policy key is accepted | `about:policies` > Errors tab | remove or rename the key (`AIControls`, `SearchEngines.Add` are the newest) |
| 6 | Thunderbird policies load | Thunderbird: `about:policies` | path may be different on Debian |
| 7 | Tind Ice CSS is picked up and looks right | enable the extension, log out and in; compare with the concept render | selectors for the dock (Dash to Dock) and Quick Settings may need adjusting for GNOME 48; blur is not possible in CSS |
| 8 | Dash to Dock package and UUID `dash-to-dock@micxgx.gmail.com` | `apt-cache policy gnome-shell-extension-dashtodock`, `gnome-extensions list` | fix UUID in `00-tind` |
| 9 | dconf defaults apply (dark, pink accent, wallpapers, dock left) | fresh user, Settings > Appearance | check `/etc/dconf/profile/user`, run `dconf update` |
| 10 | Plymouth theme runs | boot; or `sudo plymouthd --debug --tty=...` test | script syntax is untested; fall back to the stock theme `bgrt` |
| 11 | GRUB theme loads | reboot to the menu | background must be 8-bit PNG (it is); check font name `Unifont Regular 16` |
| 12 | Calamares picks up branding `tind` | start the installer in the live session | `/etc/calamares/settings.conf` `branding:` line; key names in `branding.desc` (3.3 style used) |
| 13 | `os-release` divert works | `cat /etc/os-release`, then `sudo apt install --reinstall base-files` | check `dpkg-divert --list` |
| 14 | `tind-enroll apply` with NetworkManager | on a real device with a test peer | `nmcli connection import` property names; DNS split via `resolvectl status` |
| 15 | Split DNS: `*.servr.no` goes through the tunnel, other names do not | `resolvectl query` on both | check `/etc/resolv.conf` link, NM `dns=systemd-resolved` |
| 16 | Proton VPN repository URL and key | `prepare-thirdparty.sh` prints the fingerprint; compare with Proton's page | edit `os/third-party.env` |
| 17 | Nextcloud client honours `overrideServerUrl` | install via Tind Apps, open the wizard | file location `/etc/Nextcloud/nextcloud.cfg` |
| 18 | Flathub refs exist (`com.spotify.Client` etc.) | `tind-optins install spotify` | fix the `.optin` file |
| 19 | Live session installer launcher is renamed "Install Tind" | live desktop | name of Debian's launcher file in hook `0150` |
| 20 | Resulting ISO boots in BIOS and UEFI | `scripts/test-vm.sh` | `--bootloaders` in `auto/config` |

## Known gaps (not built yet)

- btrfs and snapshots (proposed): Calamares partitioning is left at Debian's defaults (ext4).
- Live-session boot menu (syslinux/GRUB on the ISO itself) is not themed; only the installed system's GRUB is.
- GRUB's selected-item highlight is colour only (no box graphic).
- Thunderbird policy file is minimal.
- No GTK/libadwaita custom accent colour beyond GNOME's built-in "pink".
- The first-run welcome app is only the Tind Apps checklist.
