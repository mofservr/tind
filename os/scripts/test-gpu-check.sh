#!/bin/bash
# Test the logic of gpu-check (nouveau fallback for NVIDIA cards too old for Debian's packaged driver)
# with faked lspci, nvidia-detect, modprobe and logger. It tests Tind's decision logic, not the real
# nvidia-detect wording for an old card.
set -u
cd "$(dirname "$0")/.." || exit 1
script="$PWD/packages/tind-graphics/usr/lib/tind/gpu-check"
rc=0
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

run_case() { # run_case NAME LSPCI_TEXT NVIDIA_DETECT_TEXT EXPECT(unchanged|disabled)
    local name="$1" lspci_out="$2" detect_out="$3" expect="$4"
    local d="$work/$name"
    mkdir -p "$d/bin" "$d/modprobe.d"
    printf '#!/bin/sh\nprintf "%%s\\n" "%s"\n' "$lspci_out" > "$d/bin/lspci"
    printf '#!/bin/sh\ncat <<"X"\n%s\nX\n' "$detect_out" > "$d/bin/nvidia-detect"
    printf '#!/bin/sh\necho "$@" >> "%s/modprobe.calls"\n' "$d" > "$d/bin/modprobe"
    printf '#!/bin/sh\nexit 0\n' > "$d/bin/logger"
    chmod +x "$d"/bin/*
    echo "blacklist nouveau" > "$d/modprobe.d/nvidia-blacklists-nouveau.conf"
    PATH="$d/bin:$PATH" TIND_MODPROBE_DIR="$d/modprobe.d" bash "$script"
    local got=bad
    if [ "$expect" = unchanged ]; then
        [ -f "$d/modprobe.d/nvidia-blacklists-nouveau.conf" ] && [ ! -e "$d/modprobe.calls" ] && got=ok
    else
        [ ! -f "$d/modprobe.d/nvidia-blacklists-nouveau.conf" ] \
            && [ -f "$d/modprobe.d/nvidia-blacklists-nouveau.conf.tind-disabled" ] \
            && grep -qx 'nouveau' "$d/modprobe.calls" 2>/dev/null && got=ok
    fi
    if [ "$got" = ok ]; then echo "ok    $name"; else echo "FAIL  $name (expected $expect)"; rc=1; fi
}

run_case no-nvidia \
    '0300: 1002:73df
03:00.0 VGA compatible controller [0300]: Advanced Micro Devices, Inc. [AMD/ATI] Navi 22 [Radeon RX 6700] [1002:73df]' \
    '' unchanged
run_case nvidia-supported \
    '01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GM204 [GeForce GTX 970] [10de:13c2] (rev a1)' \
    'Detected NVIDIA GPUs:
01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GM204 [GeForce GTX 970] [10de:13c2] (rev a1)

Checking card:  NVIDIA Corporation GM204 [GeForce GTX 970] (rev a1)
Your card is supported by the default drivers.
It is recommended to install the
    nvidia-driver
package.' unchanged
run_case nvidia-too-old \
    '01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GK104 [GeForce GTX 760] [10de:1187] (rev a1)' \
    'Detected NVIDIA GPUs:
01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GK104 [GeForce GTX 760] [10de:1187] (rev a1)

Checking card:  NVIDIA Corporation GK104 [GeForce GTX 760] (rev a1)
Uh oh. Your card is not supported by any driver version up to 550.' disabled
exit $rc
