#!/usr/bin/env bash
# Runs a command (a Godot run) and kills it if its memory passes a cap, so a runaway fails fast instead of taking the
# Mac down (2026-10-30: a Godot run grew to about 267 GB and froze the machine). macOS ignores `ulimit -v`, so this
# polls: the resident size (`ps rss`, cheap) every half second, and the real footprint (`top`'s MEM, which counts
# compressed and swapped pages too, about 0.4 s of CPU a read) every 2 seconds. Over the cap: kill -9, a clear line
# on stderr, exit 137.
# Usage: tools/mem_guard.sh <command> [args...]
# Env: GODOT_MEM_CAP_MB (default 6144).
set -uo pipefail
cap_mb="${GODOT_MEM_CAP_MB:-6144}"
cap_kb=$((cap_mb * 1024))

"$@" &
pid=$!
trap 'kill $pid 2>/dev/null' INT TERM

# top prints MEM as 512K, 1385M, 2.1G (sometimes with a trailing +): kilobytes, or empty if unreadable.
footprint_kb() {
	top -l 1 -pid "$1" -stats mem 2>/dev/null | tail -1 | tr -d ' +-' |
		awk '/^[0-9.]+[BKMGT]$/ { n = substr($0, 1, length($0) - 1); u = substr($0, length($0));
			m = (u == "B") ? 1 / 1024 : (u == "K") ? 1 : (u == "M") ? 1024 : (u == "G") ? 1048576 : 1073741824;
			printf "%d\n", n * m }'
}

(
	tick=0
	while kill -0 $pid 2>/dev/null; do
		kb=$(ps -o rss= -p $pid 2>/dev/null | tr -d ' ')
		if [ $((tick % 4)) -eq 0 ]; then
			fp=$(footprint_kb $pid)
			[ -n "$fp" ] && [ "${fp}" -gt "${kb:-0}" ] && kb=$fp
		fi
		if [ -n "$kb" ] && [ "$kb" -gt "$cap_kb" ]; then
			echo "killed: over memory cap (${cap_mb} MB, pid $pid at $((kb / 1024)) MB): $*" >&2
			kill -9 $pid 2>/dev/null
			break
		fi
		tick=$((tick + 1))
		sleep 0.5
	done
) &
watch=$!

wait $pid
code=$?
kill $watch 2>/dev/null
wait $watch 2>/dev/null
exit $code
