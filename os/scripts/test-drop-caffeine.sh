#!/bin/bash
# Test /usr/lib/tind/drop-caffeine (tind-desktop 0.1.22) with faked dpkg-query and apt-get: Caffeine is purged
# once from machines that have it, nothing happens without it, nothing is removed when apt would take another
# package along, and a busy apt is retried at the next boot (no stamp).
set -u
cd "$(dirname "$0")/.." || exit 1
script="$PWD/packages/tind-desktop/usr/lib/tind/drop-caffeine"
rc=0
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin"
# TC_STATUS: dpkg status abbrev ("" = unknown package); TC_SIM: extra package apt would remove;
# TC_FAIL=1: the real purge fails. Every real purge is logged to $TC_LOG.
cat > "$work/bin/dpkg-query" <<'F'
#!/bin/sh
[ -n "${TC_STATUS:-}" ] || exit 1
printf '%s' "$TC_STATUS"
F
cat > "$work/bin/apt-get" <<'F'
#!/bin/sh
case " $* " in
    *" -s "*)
        echo "Purg gnome-shell-extension-caffeine [56-2]"
        [ -n "${TC_SIM:-}" ] && echo "Remv $TC_SIM [1.0]"
        exit 0 ;;
esac
echo "purge $*" >> "$TC_LOG"
[ "${TC_FAIL:-0}" = 1 ] && exit 100
exit 0
F
chmod +x "$work/bin/"*
case_() { # case_ NAME EXPECT_PURGE(0/1) EXPECT_STAMP(0/1) PATTERN
    local st="$work/state.$RANDOM" out purged stamp
    export TC_LOG="$work/log.$RANDOM"; : > "$TC_LOG"
    out="$(PATH="$work/bin:$PATH" TIND_STATE_DIR="$st" sh "$script")"; local r=$?
    purged=0; [ -s "$TC_LOG" ] && purged=1
    stamp=0; [ -e "$st/caffeine-removed" ] && stamp=1
    if [ "$r" = 0 ] && [ "$purged" = "$2" ] && [ "$stamp" = "$3" ] && grep -qE "$4" <<< "${out:-<none>}"; then
        echo "ok   $1"
    else
        echo "FAIL $1 (rc $r, purged $purged, stamp $stamp: ${out:-<none>})"; rc=1
    fi
}

TC_STATUS="ii " case_ "installed: purged, stamp written" 1 1 'removed gnome-shell-extension-caffeine'
TC_STATUS="" case_ "not installed: nothing done, stamp written" 0 1 '<none>'
TC_STATUS="rc " case_ "only leftovers: nothing done, stamp written" 0 1 '<none>'
TC_STATUS="ii " TC_SIM="some-app" case_ "apt would take another package: nothing removed" 0 1 'also remove: some-app'
TC_STATUS="ii " TC_FAIL=1 case_ "apt busy or failing: no stamp, retried next boot" 1 0 'try again at the next boot'
# the real purge must be non-interactive and wait for a busy dpkg lock
export TC_LOG="$work/log.flags"; : > "$TC_LOG"
PATH="$work/bin:$PATH" TIND_STATE_DIR="$work/s.flags" TC_STATUS="ii " sh "$script" >/dev/null
if grep -q -- '-y' "$TC_LOG" && grep -q 'DPkg::Lock::Timeout=' "$TC_LOG"; then echo "ok   purge runs with -y and a lock timeout"
else echo "FAIL purge flags: $(cat "$TC_LOG")"; rc=1; fi

[ "$rc" = 0 ] && echo "drop-caffeine: all ok" || echo "drop-caffeine: FAILED"
exit "$rc"
