#!/usr/bin/env bash
# Headless check every session runs after a change: import, unit tests, scene smoke runs.
# Usage: GODOT=/path/to/godot tools/check.sh
set -uo pipefail
GODOT="${GODOT:-$(command -v godot || echo /Applications/Godot.app/Contents/MacOS/Godot)}"
if [ ! -x "$GODOT" ] && ! command -v "$GODOT" >/dev/null; then
	echo "FAIL no Godot at '$GODOT' (set GODOT=/path/to/godot)"
	exit 1
fi
cd "$(dirname "$0")/../game"
fail=0

"$GODOT" --headless --path . --import >/dev/null 2>&1

if ! "$GODOT" --headless --path . -s res://tests/run_tests.gd; then
	fail=1
fi

for scene in launch village trail combat world_map battle_view explore map_maker overworld; do
	out=$("$GODOT" --headless --path . --quit-after 60 "res://scenes/$scene.tscn" 2>&1)
	if grep -qE "SCRIPT ERROR|^ERROR" <<< "$out"; then
		echo "FAIL scene $scene"
		grep -A1 -E "SCRIPT ERROR|^ERROR" <<< "$out"
		fail=1
	else
		echo "ok   scene $scene"
	fi
done

# The E2E robot plays the whole loop (about 2 minutes). Opt in: E2E=1 tools/check.sh
if [ "${E2E:-0}" = "1" ]; then
	out=$("$GODOT" --headless --path . -s res://tools/e2e_play.gd 2>&1)
	code=$?
	grep -E "^FAIL|^E2E|fights lost" <<< "$out"
	if grep -q "SCRIPT ERROR" <<< "$out"; then
		echo "FAIL e2e script errors:"
		grep -A3 "SCRIPT ERROR" <<< "$out" | head -20
		code=1
	fi
	if [ $code -ne 0 ]; then
		echo "FAIL e2e"
		fail=1
	fi
fi

exit $fail
