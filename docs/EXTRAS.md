# Extras: the optional app boxes

Seven boxes: Games, Developer tools, Entertainment, Creative, Communication, Productivity and cloud, Printers and scanners. Nothing from them is on the ISO. Everything is downloaded from Debian, Flathub or the vendor's own apt repository, so it needs internet.

## How the user chooses
- Installer: clicking "Install Tind" first shows a small checklist (`/usr/lib/tind/install-launcher`, zenity) with the seven tick boxes, then starts Calamares. Productivity and cloud is ticked by default (LibreOffice is no longer on the ISO, so a friend who skips it has no office suite until they add it in Tind Apps); the other six start unticked. (Calamares' own packagechooser page only does single selection and shows a placeholder icon, so it was not used. A native Calamares page can replace this when the design is done.)
- The choice is written to `/tmp/tind-extras-choice`; the `tindextras` Calamares job copies it to `/var/lib/tind/pending-extras` on the installed system.
- First boot: `tind-extras.service` waits for internet, runs the chosen setup scripts, writes `/var/lib/tind/extras-status` (running, done, offline, failed:...) and logs to `/var/log/tind-extras.log`. An autostart notification tells the user how it went. If offline, the marker stays and it retries at next boot.
- Later: the same seven entries exist in Tind Apps (`tind-optins`) and call the same scripts. Marker words: `gaming dev entertainment creative communication productivity hardware`.

## What the scripts install
- `/usr/lib/tind/setup-gaming`: enables contrib/non-free, adds i386, then steam-installer, steam-devices, lutris, wine, wine32:i386, winetricks, gamemode, mangohud, vulkan-tools, 32-bit Mesa/Vulkan libs (plus nvidia-driver-libs:i386 when the NVIDIA driver is installed), and sets `vm.max_map_count` to the SteamOS value. All native apt, no Flatpak, so Steam, Lutris and Wine share one filesystem view.
- `/usr/lib/tind/setup-dev`: git, build-essential, python3-pip, python3-venv, pipx, curl, jq, tmux, openssh-client, gh, VS Code from Microsoft's apt repository, and Claude Desktop (beta) from Anthropic's apt repository. Both keys are accepted only if their fingerprints match the pinned ones in the script.

- `/usr/lib/tind/setup-gaming` also installs `xpadneo-dkms` and `xone-dkms` when Debian ships them (skipped with a note otherwise), and Discord, Heroic and ProtonUp-Qt from Flathub.
- `/usr/lib/tind/setup-dev` also installs Wireshark (capture without root), nmap, mtr, Remmina with RDP/VNC/secret plugins, virt-manager, libvirt and QEMU, and adds the regular users to the `wireshark` and `libvirt` groups (effective at next login).
- `/usr/lib/tind/setup-entertainment`: VLC with the GStreamer plugin sets, Strawberry (Debian package, Flathub fallback; plays local files and talks to Subsonic servers such as Navidrome), Spotify (Flathub).
- `/usr/lib/tind/setup-creative`: GIMP, Inkscape, Krita, Kdenlive (with frei0r and the Breeze icon theme), Audacity, OBS Studio, Blender. All Debian.
- `/usr/lib/tind/setup-communication`: Signal from Signal's apt repository (key and sources file fetched from updates.signal.org; no fingerprint is published, so the script logs it and `SIGNAL_FPR` is empty until checked), Telegram (Debian, Flathub fallback).
- `/usr/lib/tind/setup-productivity`: LibreOffice Writer, Calc, Impress with Norwegian packs and spell-check, Nextcloud client (preconfigured for lagrr.servr.no by `tind-optins`), Bitwarden (Flathub), Proton Mail. Proton documents only a downloadable .deb for Mail, no apt repository: the script installs it with apt from that file after checking its SHA-512 against Proton's version file, and skips it (logged) if the check cannot be made. It does not update through apt unless the .deb adds a repository.
- `/usr/lib/tind/setup-hardware`: hplip, sane-utils, sane-airscan.

## Graphics drivers (always on the ISO)
`tind-graphics`: NVIDIA 550 (DKMS), Mesa Vulkan/VA-API/VDPAU, AMD graphics firmware, Intel media driver. Old NVIDIA cards fall back to nouveau (`tind-gpu-check.service`). With Secure Boot on, `tind-gpu secureboot` enrolls a per-machine signing key (login prompt offers it).

## Flatpak
Used for small apps only: Discord, Heroic, ProtonUp-Qt, Spotify, Bitwarden (and Telegram or Strawberry if Debian lacks them), plus the GNOME everyday apps and utilities opt-ins.

## Newer kernel (opt-in)
Tind Apps entry "Newer kernel" runs `/usr/lib/tind/setup-newer-kernel`: adds Debian trixie-backports, installs the backports kernel and headers, and the NVIDIA DKMS module from backports when the NVIDIA driver is installed. The current kernel stays installed and in the boot menu as a fallback. Needs internet and a restart.
