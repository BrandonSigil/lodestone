#!/usr/bin/env bash
# Runs Godot for Claude's windowed runs (screenshot scripts) without pulling Brandon's screen around.
# On a Mac with two displays the window opens on the second one (the laptop), and focus goes straight
# back to whatever app was in front: Godot always makes itself the front app at launch, and a window
# on the main display flips a full-screen Space over to the desktop. Headless runs pass straight through.
# Usage: tools/godot.sh <godot args...>
# Env: GODOT_BIN (the real binary), GODOT_SCREEN (display index, default 1).
set -uo pipefail
BIN="${GODOT_BIN:-}"
if [ -z "$BIN" ]; then
	BIN="$(command -v godot || true)"
	[ -n "$BIN" ] || BIN=/Applications/Godot.app/Contents/MacOS/Godot
fi

if [ "$(uname)" != Darwin ] || [[ " $* " == *" --headless "* ]]; then
	exec "$BIN" "$@"
fi

args=("$@")
if [[ " $* " != *" --screen "* ]]; then
	args=(--screen "${GODOT_SCREEN:-1}" "${args[@]}")
fi

front_field() { lsappinfo info -only "$1" "$(lsappinfo front)" 2>/dev/null | sed -n 's/.*="*\([^"]*\)"*$/\1/p'; }
prev="$(front_field bundleid)"

"$BIN" "${args[@]}" &
pid=$!
trap 'kill $pid 2>/dev/null' INT TERM

# Hand focus back once, as soon as Godot grabs it (give up after about 10 seconds).
if [ -n "$prev" ] && [ "$prev" != org.godotengine.godot ]; then
	for _ in $(seq 1 200); do
		kill -0 $pid 2>/dev/null || break
		if [ "$(front_field pid)" = "$pid" ]; then
			open -b "$prev"
			break
		fi
		sleep 0.05
	done
fi

wait $pid
