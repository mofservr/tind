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
- NVIDIA graphics with Secure Boot on: after install, run `tind-gpu secureboot` once to enrol the driver signing key (a reboot and a short blue MOK screen follow). Until then the NVIDIA module cannot load under Secure Boot and the open-source driver should take over (not yet tried on real hardware).
- Something wrong? Run `tind-report` in a terminal and attach the file it writes.

## 5. Install it to the computer's drive

1. In the live session, **Install Tind** is the first icon in the dock (it is also in the app grid).
2. A short checklist asks which app boxes to add. Press OK to continue, with or without a tick. Everything ticked needs internet and is set up the first time you start the installed Tind.
3. In the installer pick language, location and keyboard. On **Partitions**, **Erase disk** wipes and formats the whole drive. **Manual partitioning** lets you format and mount partitions yourself. A disk that already has another system may offer more choices, such as installing alongside it.
4. Enter your name, user name, computer name and password, check the summary, then install.
5. When it says it is done, remove the USB stick and restart.

Erase disk deletes everything on that drive. Check the drive name in the installer first.

