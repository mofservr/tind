# Third-party software in Tind

| App | When | Source | Status |
|---|---|---|---|
| LibreOffice | pre-installed | Debian | ready |
| Firefox ESR, Thunderbird | pre-installed | Debian | ready, restricted by `tind-mozilla-config` |
| uBlock Origin | pre-installed | Debian package `webext-ublock-origin-firefox` (1.67.0 in trixie) | auto-enable behaviour to verify |
| WireGuard | pre-installed | Debian | ready, tooling in `tind-wireguard` |
| Proton VPN | pre-installed | Proton's own apt repository, added at build time | **repository URL and key from memory, verify** (`os/third-party.env`) |
| Nextcloud client | opt-in | Debian `nextcloud-desktop`, global config pre-fills `https://lagrr.servr.no` | ready, `overrideServerUrl` to verify |
| Spotify | opt-in | Flathub `com.spotify.Client` | ready |
| Steam | opt-in | Flathub `com.valvesoftware.Steam` plus Debian `gamemode`, `mangohud` | ready |
| Bitwarden | opt-in | Flathub `com.bitwarden.desktop` | ready |
| Claude Desktop | opt-in | Anthropic's own signed apt repository (official beta for Debian 12+, package `claude-desktop`) | **repository line and key URL left blank on purpose**, fill in `/etc/tind/thirdparty.conf` from Anthropic's install page |
| Gaming extras | opt-in (proposed) | Flathub: ProtonUp-Qt, Heroic, Lutris | proposed, not decided |

## Rules used

- Nothing is installed from a repository whose URL and key fingerprint have not been checked by a human against the vendor's own page.
- No URL is guessed. Where I did not know it, the value is empty and the tool says so.
- Flatpak apps install system-wide from Flathub; Debian apps come from Debian.

## Principles check (homelab principles vs. this list)

Steam, Spotify and Proton VPN are closed-source or DRM'd services. They are opt-in (Proton is pre-installed at your request) and nothing else in Tind depends on them.
