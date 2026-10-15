# Get the Tind ISO and put it on a USB stick

## 1. Download

1. Open the repository's **Actions** tab on GitHub, pick the latest green **build** run on `main`.
2. Under **Artifacts** download **tind-iso** (a zip that contains `tind-*.iso` and `SHA256SUMS`). Artifacts are kept for 30 days; the next push builds a new one.

## 2. Check the download

Unzip, then in the same folder:

- Linux or macOS: `sha256sum -c SHA256SUMS` (macOS: `shasum -a 256 -c SHA256SUMS`)
- Windows PowerShell: `Get-FileHash .\tind-*.iso -Algorithm SHA256` and compare with the line in `SHA256SUMS`

The ISO file is over 2 GB. If the checksum differs, download again.

## 3. Write it to a USB stick (8 GB or larger, it will be erased)

- Windows or macOS: Fedora Media Writer or balenaEtcher, choose the ISO, choose the stick, write.
- Linux: `sudo dd if=tind-*.iso of=/dev/sdX bs=4M status=progress conv=fsync` (check the device name with `lsblk` first; the wrong one erases that disk).

## 4. Boot it

- Open the boot menu at power-on (often F12, F10, Esc or F8) and pick the USB stick.
- UEFI and old BIOS machines both work. Secure Boot can stay on: the live ISO and the installed system were tested with it on.
- NVIDIA graphics with Secure Boot on: after install, run `tind-gpu secureboot` once to enrol the driver signing key (a reboot and a short blue MOK screen follow). Until then the open-source driver is used.
- Something wrong? Run `tind-report` in a terminal and attach the file it writes.
