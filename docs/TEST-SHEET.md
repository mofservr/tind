# Tind hardware test sheet

One run per machine. For every test: do it, tick it, and write down what you saw in one line. When you are
done, run `tind-report` and send the file together with this sheet. The report already contains the driver,
boot, firmware and login-screen details, so no screenshots are needed except where a test says so.

Machine: ______________________  CPU/GPU: ______________________  BIOS or UEFI: ________

## Every machine

- [ ] **Install**: the installer finishes and the machine reboots into Tind. Note the install type (erase / alongside / replace).
- [ ] **Login screen** shows the Tind logo (screenshot) and no "debian 13".
- [ ] **Wi-Fi, sound, suspend and resume, brightness keys** work.
- [ ] **Firefox** opens www.servr.no; Bitwarden is in the toolbar. Selection colour, links in the address-bar suggestions and the Quick Settings toggles are the same teal.
- [ ] **Install-boxes notification** appears after the first login with internet, and Tind Apps lists the boxes.
- [ ] **Updates**: `sudo apt update` shows `https://apt.servr.no` and finishes without errors.

## Only where it applies

- [ ] **NVIDIA, older than RTX 20** (GTX 9xx / 10xx): `tind-gpu status` shows the Debian driver (550) or nouveau, and the screen works.
- [ ] **NVIDIA, RTX 20 or newer**: after the first boot with internet and one restart, `tind-gpu status` shows the NVIDIA repository driver (615 or newer), and a game or `vulkaninfo --summary` runs on it.
- [ ] **Secure Boot on**: `tind-gpu secureboot`, restart, enrol the key in the blue screen, then `tind-gpu status` shows the NVIDIA module loaded.
- [ ] **Second OS installed** (Windows or another Linux): the GRUB menu lists it and it boots.
- [ ] **fwupd**: `fwupdmgr get-updates` runs without an error (it may say there is nothing to update).
- [ ] **Lutris and Steam** start from the Games box.

## Send back

1. This sheet with one line per test.
2. The file from `tind-report`.
3. The login-screen screenshot.
