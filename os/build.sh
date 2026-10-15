#!/bin/bash
# Build the Tind ISO. Run on a Debian 13 (trixie) machine, as a normal user with sudo.
#   ./build.sh              full build (builds the tind-* packages first)
#   TIND_PROTON=0 ./build.sh   skip Proton VPN (no third-party repository)
#   ./build.sh clean        remove build/ (keeps the apt cache of downloaded packages? no: everything)
set -euo pipefail
cd "$(dirname "$0")"

if [ "${1:-}" = "clean" ]; then
    sudo rm -rf build
    echo "build/ removed."
    exit 0
fi

command -v lb >/dev/null 2>&1 || {
    echo "live-build is not installed. On Debian: sudo apt install live-build debootstrap squashfs-tools xorriso \\" >&2
    echo "    grub-pc-bin grub-efi-amd64-bin mtools dosfstools qemu-system-x86 ovmf" >&2
    exit 1
}

./packages/build-debs.sh

if [ "${TIND_PROTON:-1}" = 1 ]; then
    ./scripts/prepare-thirdparty.sh
else
    rm -f config/archives/protonvpn.* config/package-lists/protonvpn.list.chroot config/hooks/live/0190-tind-proton-repo.hook.chroot
fi

mkdir -p build
rm -rf build/config build/auto
cp -a config auto build/
if [ "${TIND_CI:-0}" = 1 ]; then
    # CI only: self-test service that reports over the serial port
    mkdir -p build/config/includes.chroot_after_packages
    cp -a ci/includes.chroot_after_packages/. build/config/includes.chroot_after_packages/
    printf 'jq\nlibinput-tools\nevtest\n' > build/config/package-lists/ci.list.chroot
fi
cd build
sudo lb clean --purge >/dev/null 2>&1 || true
sudo lb config
sudo lb build
ls -lh ./*.iso
echo "Test it with: ../scripts/test-vm.sh build/live-image-amd64.hybrid.iso"
