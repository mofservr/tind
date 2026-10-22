# Third-party software in Tind

| App | When | Source | Status |
|---|---|---|---|
| LibreOffice | opt-in (Productivity and cloud, ticked by default) | Debian | to verify |
| Firefox ESR, Thunderbird | pre-installed | Debian | ready, restricted by `tind-mozilla-config` |
| uBlock Origin | pre-installed | Debian package `webext-ublock-origin-firefox` (1.67.0 in trixie) | auto-enable behaviour to verify |
| WireGuard | pre-installed | Debian | ready, tooling in `tind-wireguard` |
| Proton VPN | opt-in (Security box, Tind Apps) | Proton's apt repository; `setup-security` fetches Proton's release package and checks its SHA-256 against Proton's install page (pinned in the script) | installs in CI (`proton-vpn-gnome-desktop`) |
| Nextcloud client | opt-in (Productivity and cloud) | Debian `nextcloud-desktop`, global config pre-fills `https://lagrr.servr.no` | ready, `overrideServerUrl` to verify |
| Spotify | opt-in (Entertainment) | Flathub `com.spotify.Client` | to verify |
| Steam, Lutris, Wine, gamemode, mangohud | opt-in (Games box at install, or Tind Apps) | Debian apt, native | proven in CI |
| Upscayl | opt-in (Creative) | Flathub `org.upscayl.Upscayl` | to verify |
| Bitwarden | opt-in (Security) | Flathub `com.bitwarden.desktop` | to verify |
| Discord, ProtonUp-Qt | opt-in (Games) | Flathub | to verify |
| Signal | opt-in (Communication) | Signal's apt repository (`updates.signal.org`); key fingerprint not published, logged and not yet pinned | to verify |
| Telegram | opt-in (Communication) | Debian `telegram-desktop`, Flathub fallback | to verify |
| VLC, Strawberry | opt-in (Entertainment) | Debian (Strawberry: Flathub fallback) | to verify |
| GIMP, Inkscape, Krita, Kdenlive, Audacity, OBS Studio, Blender | opt-in (Creative) | Debian | to verify |
| Wireshark, nmap, mtr, Remmina, virt-manager | part of Developer tools | Debian | to verify |
| HPLIP, SANE | opt-in (Printers and scanners) | Debian | to verify |
| xpadneo, xone (Xbox controllers) | part of Games, if Debian ships them | Debian DKMS | availability to verify |
| Claude Desktop | part of Developer tools | Anthropic's apt repository (`downloads.claude.ai`), key fingerprint `31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE` pinned in `setup-dev` | installs in CI |

## Rules used

- Every third-party repository is checked against the vendor's own install page: a pinned key fingerprint (Microsoft, Anthropic) or a pinned package checksum (Proton). Tind's own packages come from `apt.servr.no`, signed with its own key (see UPDATES.md).
- Flatpak apps install system-wide from Flathub; Debian apps come from Debian.

## Principles check (homelab principles vs. this list)

Steam, Spotify, Proton VPN and Claude Desktop are closed-source or DRM'd. They are all opt-in and nothing else in Tind depends on them.
