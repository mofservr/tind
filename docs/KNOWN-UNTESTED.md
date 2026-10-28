# What Tind has and has not been tested on

Plain words, for friends and for the release notes. "Tested" means it ran on a real machine, not only in the
automatic build tests. Last updated 25 October 2026 (Tind 1, Stetind).

Tind is Debian 13 with a thin layer on top. Hardware support itself (graphics, Wi-Fi, Bluetooth, sound, laptops,
printers) comes from Debian and is not retested here. This list covers only what Tind changes: its packages, the
installer setup, boot fixes, the NVIDIA setup and the update channels.

## Tested on real hardware

- **Desktop, AMD Radeon RX 6700, legacy BIOS boot.** Daily use, games (Lutris, Wine, Steam), the always-on tunnel to
  servr.no, and a silent update arriving through the daily timers.
- **ASUS VivoBook X412DA laptop, AMD Ryzen 3 3200U, UEFI with Secure Boot.** A clean install of Tind 0.4 with the default
  options, Wi-Fi, Bluetooth, sound, webcam, suspend and battery, a silent update, and the accent colours.

## Tested only by the automatic build (a virtual machine, no real hardware)

- Installs on UEFI, with and without Secure Boot, and on legacy BIOS; the optional app boxes ("extras").
- The first-boot step that turns on Debian's non-free packages, and the Stetind default wallpaper.
- Hiding NVIDIA's Vulkan file on machines without an NVIDIA card (the logic is tested with faked commands).

## Not tested by anyone yet

- **Any real NVIDIA card**: Debian's driver (550), the nouveau fallback for older cards, and the Secure Boot key step
  NVIDIA needs.
- **A fresh install on a legacy-BIOS machine** from the finished installer.
- **The optional app boxes on a fresh install on real hardware.**
- **The hotkey set and its shell parts** (27 Oct): the top bar's numbered workspaces, Super+Ctrl+1..0 on the dock, the
  small permanent numbers left of the dock icons and the running dots under the icons. They reach into Dash to Dock's
  private code (Debian ships 100-2) and were checked against its source, not on a running shell. If Dash to Dock's own
  "keyboard shortcuts" are switched on in its settings, log out and in again so the two do not fight over the keys.
- **The AI assistant box** (test channel, `ai-box` branch, from 28 Oct): the walls (two system users, the `tind_ai`
  firewall table, the sandboxed services), redaction and one request end to end are checked in the build's virtual
  machine against a fake provider. Not yet run against a real provider (Scaleway, IONOS, Mistral, Claude, OpenAI) or on
  real hardware.
- **32-bit and ARM machines**: not supported.

When a friend with one of these setups reports that it works, the line moves up to "tested".
