#!/bin/bash
# Test the logic of gpu-check with faked lspci, nvidia-detect, modprobe, logger and dpkg-divert:
#  - the nouveau fallback for NVIDIA cards too old for Debian's packaged driver;
#  - hiding NVIDIA's Vulkan ICD file when there is no usable NVIDIA GPU, and putting it back when there is.
# It tests Tind's decision logic, not the real nvidia-detect wording for an old card and not real dpkg.
set -u
cd "$(dirname "$0")/.." || exit 1
script="$PWD/packages/tind-graphics/usr/lib/tind/gpu-check"
rc=0
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

make_bin() { # make_bin DIR LSPCI_TEXT NVIDIA_DETECT_TEXT
    local d="$1" lspci_out="$2" detect_out="$3"
    mkdir -p "$d/bin" "$d/modprobe.d" "$d/icd"
    printf '#!/bin/sh\nprintf "%%s\\n" "%s"\n' "$lspci_out" > "$d/bin/lspci"
    printf '#!/bin/sh\ncat <<"X"\n%s\nX\n' "$detect_out" > "$d/bin/nvidia-detect"
    printf '#!/bin/sh\necho "$@" >> "%s/modprobe.calls"\n' "$d" > "$d/bin/modprobe"
    printf '#!/bin/sh\nexit 0\n' > "$d/bin/logger"
    # fake dpkg-divert: a text file as the diversion database, and a real rename like --rename does
    cat > "$d/bin/dpkg-divert" <<'FAKE'
#!/bin/sh
db="$TD_DIR/diversions"
case " $* " in *" --list "*) cat "$db" 2>/dev/null; exit 0 ;; esac
op=""; div=""; f=""
while [ $# -gt 0 ]; do
    case "$1" in
        --divert) div="$2"; shift ;;
        --add) op=add; f="$2"; shift ;;
        --remove) op=remove; f="$2"; shift ;;
    esac
    shift
done
case "$op" in
    add)
        grep -qF "diversion of $f to" "$db" 2>/dev/null && exit 2
        [ -e "$f" ] || exit 2
        echo "local diversion of $f to $div" >> "$db"; mv "$f" "$div"; echo "add $f" >> "$TD_DIR/divert.calls" ;;
    remove)
        line="$(grep -F "diversion of $f to" "$db" 2>/dev/null)" || exit 2
        to="${line##* to }"; mv "$to" "$f"
        grep -vF "diversion of $f to" "$db" > "$db.n"; mv "$db.n" "$db"; echo "remove $f" >> "$TD_DIR/divert.calls" ;;
esac
exit 0
FAKE
    chmod +x "$d"/bin/*
    echo "blacklist nouveau" > "$d/modprobe.d/nvidia-blacklists-nouveau.conf"
}

run_gpu() { # run_gpu DIR
    PATH="$1/bin:$PATH" TD_DIR="$1" TIND_ICD_DIRS="$1/icd" TIND_MODPROBE_DIR="$1/modprobe.d" bash "$script"
}

# run_case NAME LSPCI_TEXT NVIDIA_DETECT_TEXT EXPECT(unchanged|disabled) ICD_START(plain|diverted) ICD_EXPECT(hidden|present)
run_case() {
    local name="$1" lspci_out="$2" detect_out="$3" expect="$4" icd_start="${5:-plain}" icd_expect="${6:-present}"
    local d="$work/$name"
    make_bin "$d" "$lspci_out" "$detect_out"
    echo '{"file_format_version":"1.0.0","ICD":{"library_path":"libGLX_nvidia.so.0","api_version":"1.3"}}' > "$d/icd/nvidia_icd.json"
    echo '{"ICD":{"library_path":"libvulkan_radeon.so"}}' > "$d/icd/radeon_icd.x86_64.json"
    if [ "$icd_start" = diverted ]; then
        mv "$d/icd/nvidia_icd.json" "$d/icd/nvidia_icd.json.tind-no-nvidia"
        echo "local diversion of $d/icd/nvidia_icd.json to $d/icd/nvidia_icd.json.tind-no-nvidia" > "$d/diversions"
    fi
    run_gpu "$d"
    run_gpu "$d"   # a second boot changes nothing more
    local got=bad icd=bad
    if [ "$expect" = unchanged ]; then
        [ -f "$d/modprobe.d/nvidia-blacklists-nouveau.conf" ] && [ ! -e "$d/modprobe.calls" ] && got=ok
    else
        [ ! -f "$d/modprobe.d/nvidia-blacklists-nouveau.conf" ] \
            && [ -f "$d/modprobe.d/nvidia-blacklists-nouveau.conf.tind-disabled" ] \
            && grep -qx 'nouveau' "$d/modprobe.calls" 2>/dev/null && got=ok
    fi
    local calls=0; [ -f "$d/divert.calls" ] && calls="$(wc -l < "$d/divert.calls")"
    if [ "$icd_expect" = hidden ]; then
        [ ! -e "$d/icd/nvidia_icd.json" ] && [ -f "$d/icd/nvidia_icd.json.tind-no-nvidia" ] \
            && grep -qF "diversion of $d/icd/nvidia_icd.json to" "$d/diversions" && icd=ok
    else
        [ -f "$d/icd/nvidia_icd.json" ] && [ ! -e "$d/icd/nvidia_icd.json.tind-no-nvidia" ] \
            && ! grep -q 'tind-no-nvidia' "$d/diversions" 2>/dev/null && icd=ok
    fi
    # the AMD ICD file is never touched; at most one diversion change in two boots
    [ -f "$d/icd/radeon_icd.x86_64.json" ] || icd=bad
    [ "$calls" -le 1 ] || icd=bad
    if [ "$got" = ok ] && [ "$icd" = ok ]; then echo "ok    $name (nouveau $expect, ICD $icd_expect)"
    else echo "FAIL  $name (expected nouveau $expect [$got], ICD $icd_expect [$icd], divert calls $calls)"; rc=1; fi
}

AMD='0300: 1002:73df
03:00.0 VGA compatible controller [0300]: Advanced Micro Devices, Inc. [AMD/ATI] Navi 22 [Radeon RX 6700] [1002:73df]'
GTX970='01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GM204 [GeForce GTX 970] [10de:13c2] (rev a1)'
GTX970_DETECT='Detected NVIDIA GPUs:
01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GM204 [GeForce GTX 970] [10de:13c2] (rev a1)

Checking card:  NVIDIA Corporation GM204 [GeForce GTX 970] (rev a1)
Your card is supported by the default drivers.
It is recommended to install the
    nvidia-driver
package.'
GTX760='01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GK104 [GeForce GTX 760] [10de:1187] (rev a1)'
GTX760_DETECT='Detected NVIDIA GPUs:
01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GK104 [GeForce GTX 760] [10de:1187] (rev a1)

Checking card:  NVIDIA Corporation GK104 [GeForce GTX 760] (rev a1)
Uh oh. Your card is not supported by any driver version up to 550.'

# nouveau fallback (the three original cases), now also checking the ICD file
run_case no-nvidia                "$AMD"    ''                 unchanged plain    hidden
run_case nvidia-supported         "$GTX970" "$GTX970_DETECT"   unchanged plain    present
run_case nvidia-too-old           "$GTX760" "$GTX760_DETECT"   disabled  plain    hidden
# the ICD file comes back when a supported NVIDIA card shows up (a card added to a hidden machine, or a hybrid laptop)
run_case nvidia-supported-restore "$GTX970" "$GTX970_DETECT"   unchanged diverted present
# a machine that already has the diversion stays hidden without NVIDIA
run_case no-nvidia-already-hidden "$AMD"    ''                 unchanged diverted hidden
exit $rc
