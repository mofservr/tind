# Verify checklist

Status after CI runs on GitHub Actions (Debian 13 container build, then a UEFI boot of the ISO in QEMU with a self-test that reports over the serial port). Logs are pushed to the `ci-logs` branch.

## Proven by CI (run 38466699782)

- shellcheck (warning level), `bash -n`, JSON and XML checks pass.
- All 7 `.deb` packages build; every Depends and Recommends name exists in trixie (contrib, non-free, non-free-firmware enabled).
- live-build produces a 2.4 GB hybrid ISO; it boots under UEFI and auto-logs in to GNOME (nb_NO locale).
- `os-release` shows Tind 0.1; all 7 tind packages installed; no failed systemd units.
- NetworkManager, systemd-resolved, ufw (active) and gdm are running; `/etc/resolv.conf` links to the resolved stub.
- Flathub remote is present.
- dconf defaults apply: prefer-dark, pink accent, dark wallpaper, extensions enabled, dock on the left.
- Tind Ice extension is ACTIVE and Dash to Dock is enabled (UUID confirmed).
- Firefox policy files are present at both paths and are valid JSON. uBlock Origin loads and is active in Firefox ESR (`app-system-share`).
- Thunderbird policy file is valid JSON.
- `tind-enroll` help, `init`, `status` and `remove` work; `apply` refuses cleanly on an empty enrolment block.
- Calamares `branding: tind` is set and the branding files are installed.
- Live installer launcher is renamed "Install Tind"; the original is hidden.
- Plymouth default theme is `tind`; GRUB drop-in `90-tind.cfg` is installed.
- gnome-tour is removed (no first-login tour).
- Nextcloud `overrideServerUrl` file is in place (the client itself has not been run).

## Installer findings (CI drives Calamares by keyboard and mouse in QEMU)

- Calamares opens as "Install Tind" with the Tind branding and walks through location, keyboard, partitioning (erase disk), users, summary and install.
- Fixed: default timezone was America/New_York; now Europe/Oslo (`/etc/calamares/modules/locale.conf`).
- Fixed: install failed at the bootloader step (`grub-efi` has no candidate because the image carries no apt indices, and `hwclock` was missing in the target). GRUB EFI packages and `util-linux-extra` are now in the image.
- Fixed: post-install package removal failed on packages we do not ship; now a `try_remove` list.
- Result (CI run with ISO 38502970300): the full install completes ("All done"), the installed disk boots under UEFI to the Tind desktop with autologin, no failed units, installer packages are removed from the installed system.
- Known: UEFI only for now (no `grub-pc`), no `ckbcomp` (no keyboard preview), welcome page text from the branding is English only.

## Still unproven

| # | Item | How to check | If wrong |
|---|---|---|---|
| 4 | Firefox reads the policies and each key is accepted | `about:policies`: Active, no Errors | rename or remove the key (`AIControls`, `SearchEngines` are the newest) |
| 6 | Thunderbird reads its policies | `about:policies` | path may differ |
| 7 | Tind Ice looks right | look at the running desktop | selectors for the dock and Quick Settings; blur is not possible in CSS |
| 10 | Plymouth splash renders | boot with a screen capture early | script syntax; fall back to `bgrt` |
| 11 | GRUB theme on the installed system | reboot after install | PNG depth, font name |
| 12 | Calamares installer runs through and the installed system boots | install in a VM | partitioning, branding keys |
| 14 | `tind-enroll apply` with NetworkManager and a real peer | needs an enrolment block from `tind-add-peer` | `nmcli connection import` property names |
| 15 | Split DNS: `*.servr.no` via the tunnel only | `resolvectl query` on both | `/etc/resolv.conf`, NM `dns=systemd-resolved` |
| 17 | Nextcloud client honours the preset URL | run the wizard | file location |
| 18 | Flathub refs exist (`com.spotify.Client` etc.) | `tind-optins install spotify` | `.optin` files |
| 20 | BIOS (syslinux) boot | QEMU without OVMF | `--bootloaders` in `auto/config` |

## Known gaps

- The live ISO boot menu is stock live-build (Debian title, hard-hat splash); branding it needs artwork, which is waiting on the design work.
- All visuals in `tind-branding` (wallpapers, icons, Plymouth, GRUB art, Ice colours) are placeholders pending the redesign.
- ext4 for now (decided): no btrfs, no snapshots.
- Thunderbird policy is minimal.

## Lean desktop (2026-10-14)
- Proven in CI: tind-desktop names GNOME pieces explicitly (no gnome-core); app grid is Calculator, Camera, Disks, Extensions, Files, Firefox, Image Viewer, LibreOffice, Papers, Print Settings, Settings, Software, System Monitor, Terminal, Text Editor, Thunderbird, Tind Apps, Install Tind.
- Proven: Calamares install of the lean ISO boots to desktop, autologin, no failed units.
- Removed apps are opt-ins in tind-optins: gnome-extras, gnome-utilities, tweaks.
- fwupd added for firmware updates through GNOME Software (unproven on real hardware).
- Unproven: Flathub refs of the new opt-ins; hook 0170 purge result on the next full ISO (launchers verified hidden in build run 38531716185).

## Extras and graphics (2026-10-14)
- Proven in CI (packages job, real trixie): setup-dev and setup-gaming complete; VS Code from the Microsoft repo, Steam installer licence unattended, Lutris, Wine, wine32:i386, winetricks, gamemode, mangohud install; Microsoft key fingerprint matches the pin.
- Proven: ISO carries NVIDIA 550 DKMS module (built for the image kernel), no DKMS signing key shipped, nvidia-persistenced masked, no gaming or dev software on the ISO.
- Proven (installer run 38569659053): the choice reaches /var/lib/tind/pending-extras, first boot waits for internet, installs the developer stack, status becomes done, marker removed. Calamares' own chooser page was single-select with a placeholder icon, replaced by a zenity checklist in the install launcher.
- Proven (installer run 38598804949): zenity checklist with both boxes ticked by mouse; first boot installed games (steam-installer, lutris, wine, wine32:i386, winetricks, gamemode, mangohud, i386 enabled, vm.max_map_count=2147483642) and developer tools (git, gh, build-essential, pipx, code); status done; no failed units.
- Unproven: the login notification, Enter key in the dialog (OK must be clicked), Steam/Lutris actually launching games, Tind Apps entries for Games and Developer tools on an installed system.
- Unproven on real hardware: NVIDIA load, nouveau fallback for old cards, Secure Boot key flow, fwupd, Steam/Lutris actually running games.

## Boot modes, dual boot, newer kernel (2026-10-14)
- Proven (installer run 38614079926, BIOS/SeaBIOS): install completes, installed system boots via BIOS, GRUB in /boot/grub/i386-pc, ext4 root, no failed units. The image carries both grub-efi-amd64-bin and grub-pc-bin; Tind's own bootloader step (`/usr/lib/tind/bootloader-config`, module `tindbootloader`) replaces Debian's helper because that one runs apt (needs network, and grub-pc conflicts with grub-efi-amd64).
- Image has os-prober and ntfs-3g; `GRUB_DISABLE_OS_PROBER=false` in `/etc/default/grub.d/90-tind.cfg`. Unproven: an actual second OS being detected and offered by Calamares ("install alongside") and by the GRUB menu.
- BIOS note: the BIOS install has grub-pc-bin but not the grub-pc package, so grub upgrades do not re-run grub-install on the disk. Acceptable for now.
- Newer kernel opt-in ("Newer kernel" in Tind Apps, `/usr/lib/tind/setup-newer-kernel`): adds trixie-backports, installs linux-image-amd64 and headers (7.2.6 at test time) and, if present, nvidia-kernel-dkms from backports. Dry run resolves in CI. Unproven: a real install, NVIDIA module building on 7.x, boot into the new kernel.
- Installer test is now selectable: `os/ci/installer-test/FIRMWARE` (uefi|bios) and `EXTRAS` (yes|no).

## Secure Boot, updates, hardware basics (2026-10-15)
- Proven (secureboot-test run 38688887984): the live ISO has shim signed by Microsoft (UEFI CA 2011 and 2023) and GRUB signed by Debian; it boots to the desktop under OVMF with Secure Boot on ("SecureBoot enabled" in the self-test).
- Proven (installer run 38689713608, UEFI, Secure Boot on): install completes (7.6 GB used), the installed system boots with Secure Boot enabled, no failed units. The NVIDIA module and the MOK key step cannot be tested in a VM without a GPU.
- Proven (build run 38690632554): ISO with Proton VPN (`proton-vpn-gnome-desktop` 0.11.0 installed), first-boot apt refresh (`tind-apt-refresh`, lists present, marker written), PackageKit and GNOME Software 48.3 answer (`pkcon get-updates` works), unattended-upgrades timers enabled, `power-profiles-daemon` active, microcode and Broadcom/MediaTek firmware installed, `tind-report` writes a 12-section report.
- Findings fixed after that run: LLMNR (tcp/udp 5355) was listening, now disabled via `/etc/systemd/resolved.conf.d/90-tind.conf`; the build-time Proton repo is stripped from the image by live-build, so a generated hook (0190, written by `prepare-thirdparty.sh`, checksum-verified) installs Proton's release package to keep Proton updating and its key rotating (Proton's current key expires 2027-03-03); AppArmor is skipped in the live session by Debian's design (`ConditionPathExists=!/run/live/overlay/work`).
- Claude Desktop is part of `setup-dev` (Anthropic apt repo, fingerprint pinned); the separate Claude opt-in is gone. Proven: installs in the packages job.
- ISO download: `tind-iso` artifact now has `SHA256SUMS`, kept 30 days (see `WRITE-TO-USB.md`). GitHub release assets cap at 2 GB, the ISO is larger.
- Still unproven: Plymouth and GRUB menu frames (early frames added to the boot job), a real second OS, Wi-Fi chips (Broadcom STA driver deliberately not shipped), suspend and battery behaviour, `fwupd` on real hardware.
- Proven (build run 38698762129 and installer run 38702037752, UEFI, Secure Boot on): `protonvpn-stable-release` 1.0.8 is installed in the image with its repo entry; on the installed system AppArmor is active (141 profiles, 19 enforcing), ufw active, LLMNR gone (only loopback DNS/CUPS and mDNS 5353 listen), no failed units. Early boot frames in CI: firmware, GRUB menu (stock live-build look), Tind Plymouth splash with progress bar, desktop.

## App boxes (2026-10-16, not yet tested)
- Seven installer boxes replace the two: Games, Developer tools, Entertainment, Creative, Communication, Productivity and cloud (ticked by default), Printers and scanners. LibreOffice moved from `tind-apps` to the Productivity box, so the live ISO and a no-extras install have no office suite.
- CI `installer-test`: the dialog is taller and has seven rows, so the click coordinates in `os/ci/installer-test/*.json` (rows and OK button) need to be captured again. The no-extras run now also installs Productivity on first boot unless it is unticked.
- To check in the VM: Strawberry connects to Navidrome (Subsonic); Signal installs and updates through apt (key pinned to the CI-logged fingerprint); `xpadneo-dkms` / `xone-dkms` exist in trixie; Heroic, Discord and ProtonUp-Qt launch; Telegram and Strawberry come from Debian rather than Flathub; LibreOffice Draw and Math stay hidden after the first-boot install; the app grid after the box installs.
- Netflix-style streaming (Widevine) and codecs in the base image are still unchecked.

## One-launcher, folders and trimmed grid (to check on hardware)
- Live session: only "Install Tind" in the app grid; Tind Apps hidden. After installing: only Tind Apps, no installer entry.
- App grid shows folders Office, System, Utilities; Showtime is gone; dock starts with Firefox, Thunderbird, Files.
- An empty Office folder (no LibreOffice yet) is not shown. Not verified.
- Installing the Entertainment box gives VLC; Spotify failing must not fail the box.

