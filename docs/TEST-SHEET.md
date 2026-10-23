# Tind hardware test sheet

One run per machine. For every test: do it, tick it, and write down what you saw in one line. When you are
done, run `tind-report` and send the file together with this sheet. The report already contains the driver,
boot, firmware and login-screen details, so no screenshots are needed except where a test says so. You do not
need to write down which computer it is: the first lines of the report list the model, CPU, graphics, Wi-Fi,
sound and UEFI or BIOS.

## Before you start

1. Write the ISO to a USB stick as described in `WRITE-TO-USB.md` and boot from it (UEFI or BIOS, whichever your
   machine uses). Choose "Install Tind" in the dock at the left of the live desktop.
2. Tick the tests below as you go. You do not need to understand them: if something looks wrong, write down what
   you saw and carry on.
3. At the end, open a terminal and run `tind-report`. It writes one text file in your home folder and prints
   its name. It hides your serial numbers and network addresses; read it first if you want to be sure.

## Which tests are mine?

| My machine | Do these |
|---|---|
| Any | "Every machine" |
| NVIDIA graphics | "NVIDIA" test that matches the card, plus "Secure Boot on" if it is on |
| Laptop with Intel or AMD graphics **and** NVIDIA | the NVIDIA tests and "Hybrid graphics" |
| Windows (or another OS) on the same disk | "Second OS installed" |
| Older PC without UEFI (BIOS only) | "BIOS-only PC" |

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
- [ ] **BIOS-only PC**: after the install, `dpkg -l grub-pc grub-efi-amd64 | tail -2` shows `ii` for grub-pc
  and `rc` or nothing for grub-efi-amd64; the machine boots without the USB stick.
- [ ] **Hybrid graphics** (Intel or AMD plus NVIDIA): the desktop runs on the integrated GPU
  (`tind-gpu status` lists both); a game started from Steam or Lutris uses the NVIDIA card.
- [ ] **Second OS installed** (Windows or another Linux): the GRUB menu lists it and it boots.
- [ ] **fwupd**: `fwupdmgr get-updates` runs without an error (it may say there is nothing to update).
- [ ] **Lutris and Steam** start from the Games box.

## Send back

1. This sheet with one line per test.
2. The file from `tind-report`.
3. The login-screen screenshot.
