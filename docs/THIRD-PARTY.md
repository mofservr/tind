# Third-party software in Tind

| App | When | Source | Status |
|---|---|---|---|
| LibreOffice | pre-installed | Debian | ready |
| Firefox ESR, Thunderbird | pre-installed | Debian | ready, restricted by `tind-mozilla-config` |
| uBlock Origin | pre-installed | Debian package `webext-ublock-origin-firefox` (1.67.0 in trixie) | auto-enable behaviour to verify |
| WireGuard | pre-installed | Debian | ready, tooling in `tind-wireguard` |
| Proton VPN | pre-installed | Proton's apt repository; the build fetches Proton's release package, checks its SHA-256 against Proton's install page (`os/third-party.env`), and the image keeps the repo via that package | verified against Proton's page; installs in CI (`proton-vpn-gnome-desktop` 0.11.0) |
| Nextcloud client | opt-in | Debian `nextcloud-desktop`, global config pre-fills `https://lagrr.servr.no` | ready, `overrideServerUrl` to verify |
| Spotify | opt-in | Flathub `com.spotify.Client` | ready |
| Steam, Lutris, Wine, gamemode, mangohud | opt-in (Games box at install, or Tind Apps) | Debian apt, native | proven in CI |
| Bitwarden | opt-in | Flathub `com.bitwarden.desktop` | ready |
| Claude Desktop | part of Developer tools | Anthropic's apt repository (`downloads.claude.ai`), key fingerprint `31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE` pinned in `setup-dev` | installs in CI |

## Rules used

- Every third-party repository is checked against the vendor's own install page: a pinned key fingerprint (Microsoft, Anthropic) or a pinned package checksum (Proton).
- Flatpak apps install system-wide from Flathub; Debian apps come from Debian.

## Principles check (homelab principles vs. this list)

Steam, Spotify, Proton VPN and Claude Desktop are closed-source or DRM'd. They are opt-in (Proton is pre-installed at your request) and nothing else in Tind depends on them.
