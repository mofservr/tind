#!/bin/bash
# Boot a Tind ISO in QEMU (UEFI if OVMF is installed, KVM if available).
#   ./scripts/test-vm.sh path/to/tind.iso
set -euo pipefail
iso="${1:?usage: test-vm.sh path/to/image.iso}"
# shellcheck disable=SC2054
args=(-m 6G -smp 4 -cdrom "$iso" -boot d -vga virtio -display gtk -device virtio-net-pci,netdev=n -netdev user,id=n)
[ -e /dev/kvm ] && args+=(-enable-kvm -cpu host)
for fw in /usr/share/OVMF/OVMF_CODE_4M.fd /usr/share/OVMF/OVMF_CODE.fd /usr/share/ovmf/OVMF.fd; do
    if [ -f "$fw" ]; then args+=(-bios "$fw"); echo "UEFI firmware: $fw"; break; fi
done
exec qemu-system-x86_64 "${args[@]}"
