# What Tind has and has not been tested on

Plain words, for friends and for the release notes. "Tested" means it ran on a real machine, not only in the
automatic build tests. Last updated 22 October 2026 (Tind 0.2).

## Tested on real hardware

- **Desktop, AMD Radeon RX 6700, BIOS (legacy) boot.** Install, Wi-Fi-less daily use, Lutris/Wine games, Steam.
  The legacy-boot install needed one manual fix (`sudo apt install grub-pc`); the installer now does it, but
  that fix is only proven in the automatic test, not on a fresh install on this machine.
- **ASUS VivoBook X412DA laptop, AMD Ryzen 3 3200U (Vega 3), UEFI.** Install next to Windows and another Debian
  (all three show in the boot menu), Secure Boot on, Wi-Fi, sound, suspend and battery.

## Tested only by the automatic build (a virtual machine, no real hardware)

- Install on UEFI, with and without Secure Boot, and on legacy BIOS.

## Not tested by anyone yet

- **Any real NVIDIA card**: Debian's driver (550) or nouveau on older cards, and the Secure Boot key step NVIDIA needs.
- **Laptops with two graphics chips** (Intel or AMD plus NVIDIA).
- **Intel graphics** of any age, and Intel CPUs in general.
- **A fresh install on a legacy-BIOS machine** from the finished installer.
- **Wi-Fi or Bluetooth chips** other than the Intel one in the ASUS laptop (Broadcom and Realtek in particular).
- **Printers and scanners** (the box installs; no real device has been tried).
- **Fingerprint readers, touchscreens, drawing tablets, 2-in-1 sensors.**
- **Very new hardware** (less than a year old): Debian 13 may not have its drivers.
- **32-bit and ARM machines**: not supported.
- **The always-on tunnel to servr.no** after the latest change (`tind-enroll` 0.3.1).

When a friend with one of these machines reports that it works, the line moves up to "tested".
