# Extras: the optional app boxes

Seven boxes: Games, Developer tools, Entertainment, Creative, Communication, Productivity and cloud, Printers and scanners. Nothing from them is on the ISO. Everything is downloaded from Debian, Flathub or the vendor's own apt repository, so it needs internet.

## How the user chooses
- Installer: clicking "Install Tind" first shows a small checklist (`/usr/lib/tind/install-launcher`, zenity) with the seven tick boxes, then starts Calamares. Productivity and cloud is ticked by default (LibreOffice is no longer on the ISO, so a friend who skips it has no office suite until they add it in Tind Apps); the other six start unticked. (Calamares' own packagechooser page only does single selection and shows a placeholder icon, so it was not used. A native Calamares page can replace this when the design is done.)
- The choice is written to `/tmp/tind-extras-choice`; the `tindextras` Calamares job copies it to `/var/lib/tind/pending-extras` on the installed system.
- First boot: `tind-extras.service` waits for internet, runs the chosen setup scripts, writes `/var/lib/tind/extras-status` (running, done, offline, failed:...) and logs to `/var/log/tind-extras.log`. An autostart notification tells the user how it went. If offline, the marker stays and it retries at next boot.
- Later: the same seven entries exist in Tind Apps (`tind-optins`) and call the same scripts. Marker words: `gaming dev entertainment creative communication productivity hardware`.
- One launcher at a time: the live session shows only "Install Tind" (`tind-installer` ships `/usr/local/share/applications/tind-optins.desktop` with `NoDisplay=true` to hide Tind Apps, which could only install into RAM there). After installing, `tind-installer` is removed, which removes that override and the installer entry, so only Tind Apps is left.

## What the scripts install
- `/usr/lib/tind/setup-gaming`: enables contrib/non-free, adds i386, then steam-installer, steam-devices, lutris, wine, wine32:i386, winetricks, gamemode, mangohud, vulkan-tools, 32-bit Mesa/Vulkan libs (plus nvidia-driver-libs:i386 when the NVIDIA driver is installed), and sets `vm.max_map_count` to the SteamOS value. All native apt, no Flatpak, so Steam, Lutris and Wine share one filesystem view.
- `/usr/lib/tind/setup-dev`: git, build-essential, python3-pip, python3-venv, pipx, curl, jq, tmux, openssh-client, gh, VS Code from Microsoft's apt repository, and Claude Desktop (beta) from Anthropic's apt repository. Both keys are accepted only if their fingerprints match the pinned ones in the script.

- `/usr/lib/tind/setup-gaming` also installs `xpadneo-dkms` and `xone-dkms` when Debian ships them (skipped with a note otherwise), and Discord, Heroic and ProtonUp-Qt from Flathub.
- `/usr/lib/tind/setup-dev` also installs Wireshark (capture without root), nmap, mtr, Remmina with RDP/VNC/secret plugins, virt-manager, libvirt and QEMU, and adds the regular users to the `wireshark` and `libvirt` groups (effective at next login).
- `/usr/lib/tind/setup-entertainment`: VLC with the GStreamer plugin sets, Strawberry (Debian package, Flathub fallback; plays local files and talks to Subsonic servers such as Navidrome), Spotify (Flathub).
- `/usr/lib/tind/setup-creative`: GIMP, Inkscape, Krita, Kdenlive (with frei0r and the Breeze icon theme), Audacity, OBS Studio, Blender (Debian), plus Upscayl from Flathub (non-fatal if it fails).
- `/usr/lib/tind/setup-communication`: Signal from Signal's apt repository (key and sources file fetched from updates.signal.org; Signal publishes no fingerprint, so `SIGNAL_FPR` is the one CI logged on 2026-10-18 and the script refuses any other key; a rotated key shows up as a mismatch), Telegram (Debian, Flathub fallback).
- `/usr/lib/tind/setup-productivity`: LibreOffice Writer, Calc, Impress with Norwegian packs and spell-check, Nextcloud client (preconfigured for lagrr.servr.no by `tind-optins`), Bitwarden (Flathub). Proton Mail is not offered (it needs a paid plan); Proton VPN is the only Proton app, pre-installed on the image.
- `/usr/lib/tind/setup-hardware`: hplip, sane-utils, sane-airscan.

## Graphics drivers (always on the ISO)
`tind-graphics`: NVIDIA 550 (DKMS), Mesa Vulkan/VA-API/VDPAU, AMD graphics firmware, Intel media driver. Old NVIDIA cards fall back to nouveau (`tind-gpu-check.service`). With Secure Boot on, `tind-gpu secureboot` enrolls a per-machine signing key (login prompt offers it).

## Flatpak
Used for small apps only: Discord, Heroic, ProtonUp-Qt, Spotify, Bitwarden, Upscayl (and Telegram or Strawberry if Debian lacks them), plus the GNOME everyday apps and utilities opt-ins.

## Newer kernel (opt-in)
The newer kernel (no longer a Tind Apps entry; run `sudo /usr/lib/tind/setup-newer-kernel` by hand) is `/usr/lib/tind/setup-newer-kernel`: adds Debian trixie-backports, installs the backports kernel and headers, and the NVIDIA DKMS module from backports when the NVIDIA driver is installed. The current kernel stays installed and in the boot menu as a fallback. Needs internet and a restart.

## Flatpak steps are non-fatal
Each Flatpak app in the boxes (Spotify, Discord, Heroic, ProtonUp-Qt, Bitwarden, Upscayl) is installed through `optional`, so one that fails (Spotify's `apply_extra` download failed in CI) is logged as a warning and the rest of the box still installs.

## App grid
Folders (defaults in `tind-branding`, users can rearrange): **Office** (LibreOffice Writer, Calc, Impress, Start Center; fills up when the Productivity box is installed), **System** (Proton VPN, Extensions, Tind Apps), **Utilities** (Calculator, Text Editor, System Monitor, Disks, Image Viewer, Papers, Archive Manager). Settings, Software, Terminal, Camera, Firefox, Thunderbird and Files stay at the top level. Showtime is not installed; VLC comes with the Entertainment box. The standalone Print Settings app is hidden (printers are in GNOME Settings).
