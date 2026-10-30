#!/usr/bin/env bash
# Runs Godot for Claude's windowed runs (screenshot scripts) without touching Brandon's screen.
# On a Mac the run uses a private focus-free copy of Godot (tools/nofocus/setup.sh builds it in
# ~/.lodestone/nofocus): it is marked background-only and a small library stops it activating itself,
# so it never becomes the front app, never moves his windows and never takes his keyboard or mouse.
# Brandon (2026-10-30): "there has to be another way to grab a screenshot then making my windows fly
# around constantly and unfocus my mouse". If the focus-free copy can't be built, the run is refused.
# Every run goes through tools/mem_guard.sh: over GODOT_MEM_CAP_MB (default 6144) it is killed, not left to fill the Mac.
# Usage: tools/godot.sh <godot args...>
# Env: GODOT_BIN (the real binary, non-Mac and headless runs), GODOT_SCREEN (display index, default 1), GODOT_MEM_CAP_MB.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
GUARD="$HERE/mem_guard.sh"
BIN="${GODOT_BIN:-}"
if [ -z "$BIN" ]; then
	BIN="$(command -v godot || true)"
	[ -n "$BIN" ] || BIN=/Applications/Godot.app/Contents/MacOS/Godot
fi

if [ "$(uname)" != Darwin ] || [[ " $* " == *" --headless "* ]]; then
	exec "$GUARD" "$BIN" "$@"
fi

NF="$HOME/.lodestone/nofocus"
if ! "$HERE/nofocus/setup.sh" >/dev/null 2>&1; then
	echo "tools/godot.sh: couldn't build the focus-free Godot (tools/nofocus/setup.sh); windowed run refused so Brandon's screen isn't disturbed." >&2
	exit 3
fi

args=("$@")
if [[ " $* " != *" --screen "* ]]; then
	args=(--screen "${GODOT_SCREEN:-1}" "${args[@]}")
fi
exec "$GUARD" "$NF/launch" "$NF/Godot.app/Contents/MacOS/Godot" "$NF/nofocus.dylib" "${args[@]}"
