# Extras: games and developer tools

Nothing from these stacks is on the ISO. Everything is downloaded from Debian (or Microsoft for VS Code, Anthropic for Claude Desktop), so it needs internet.

## How the user chooses
- Installer: clicking "Install Tind" first shows a small checklist (`/usr/lib/tind/install-launcher`, zenity) with two tick boxes, Games and Developer tools, then starts Calamares. (Calamares' own packagechooser page only does single selection and shows a placeholder icon, so it was not used. A native Calamares page can replace this when the design is done.)
- The choice is written to `/tmp/tind-extras-choice`; the `tindextras` Calamares job copies it to `/var/lib/tind/pending-extras` on the installed system.
- First boot: `tind-extras.service` waits for internet, runs the chosen setup scripts, writes `/var/lib/tind/extras-status` (running, done, offline, failed:...) and logs to `/var/log/tind-extras.log`. An autostart notification tells the user how it went. If offline, the marker stays and it retries at next boot.
- Later: the same two entries exist in Tind Apps (`tind-optins`) and call the same scripts.

## What the scripts install
- `/usr/lib/tind/setup-gaming`: enables contrib/non-free, adds i386, then steam-installer, steam-devices, lutris, wine, wine32:i386, winetricks, gamemode, mangohud, vulkan-tools, 32-bit Mesa/Vulkan libs (plus nvidia-driver-libs:i386 when the NVIDIA driver is installed), and sets `vm.max_map_count` to the SteamOS value. All native apt, no Flatpak, so Steam, Lutris and Wine share one filesystem view.
- `/usr/lib/tind/setup-dev`: git, build-essential, python3-pip, python3-venv, pipx, curl, jq, tmux, openssh-client, gh, VS Code from Microsoft's apt repository, and Claude Desktop (beta) from Anthropic's apt repository. Both keys are accepted only if their fingerprints match the pinned ones in the script.

## Graphics drivers (always on the ISO)
`tind-graphics`: NVIDIA 550 (DKMS), Mesa Vulkan/VA-API/VDPAU, AMD graphics firmware, Intel media driver. Old NVIDIA cards fall back to nouveau (`tind-gpu-check.service`). With Secure Boot on, `tind-gpu secureboot` enrolls a per-machine signing key (login prompt offers it).

## Flatpak
Used for small apps only (opt-ins: Spotify, Bitwarden, GNOME everyday apps and utilities).

## Newer kernel (opt-in)
Tind Apps entry "Newer kernel" runs `/usr/lib/tind/setup-newer-kernel`: adds Debian trixie-backports, installs the backports kernel and headers, and the NVIDIA DKMS module from backports when the NVIDIA driver is installed. The current kernel stays installed and in the boot menu as a fallback. Needs internet and a restart.
