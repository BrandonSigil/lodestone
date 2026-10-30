#!/usr/bin/env bash
# Runs Godot for Claude's windowed runs (screenshot scripts) without pulling Brandon's screen around.
# On a Mac with two displays the window opens on the second one (the laptop), and focus goes straight
# back to whatever app was in front: Godot always makes itself the front app at launch, and a window
# on the main display flips a full-screen Space over to the desktop. Headless runs pass straight through.
# Every run goes through tools/mem_guard.sh: over GODOT_MEM_CAP_MB (default 6144) it is killed, not left to fill the Mac.
# Usage: tools/godot.sh <godot args...>
# Env: GODOT_BIN (the real binary), GODOT_SCREEN (display index, default 1), GODOT_MEM_CAP_MB.
set -uo pipefail
GUARD="$(cd "$(dirname "$0")" && pwd)/mem_guard.sh"
BIN="${GODOT_BIN:-}"
if [ -z "$BIN" ]; then
	BIN="$(command -v godot || true)"
	[ -n "$BIN" ] || BIN=/Applications/Godot.app/Contents/MacOS/Godot
fi

if [ "$(uname)" != Darwin ] || [[ " $* " == *" --headless "* ]]; then
	exec "$GUARD" "$BIN" "$@"
fi

args=("$@")
if [[ " $* " != *" --screen "* ]]; then
	args=(--screen "${GODOT_SCREEN:-1}" "${args[@]}")
fi

front_field() { lsappinfo info -only "$1" "$(lsappinfo front)" 2>/dev/null | sed -n 's/.*="*\([^"]*\)"*$/\1/p'; }
prev="$(front_field bundleid)"

"$GUARD" "$BIN" "${args[@]}" &
pid=$!  # the guard; Godot is its child
trap 'kill $pid 2>/dev/null' INT TERM

# Hand focus back once, as soon as Godot grabs it (give up after about 10 seconds).
if [ -n "$prev" ] && [ "$prev" != org.godotengine.godot ]; then
	for _ in $(seq 1 200); do
		kill -0 $pid 2>/dev/null || break
		gpid="$(pgrep -P $pid | head -1)"
		if [ -n "$gpid" ] && [ "$(front_field pid)" = "$gpid" ]; then
			open -b "$prev"
			break
		fi
		sleep 0.05
	done
fi

wait $pid
