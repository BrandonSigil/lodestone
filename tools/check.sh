#!/usr/bin/env bash
# Headless check every session runs after a change: import, unit tests, scene smoke runs.
# Usage: GODOT=/path/to/godot tools/check.sh
set -uo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/../game"
fail=0

"$GODOT" --headless --path . --import >/dev/null 2>&1

if ! "$GODOT" --headless --path . -s res://tests/run_tests.gd; then
	fail=1
fi

for scene in village trail combat world_map; do
	out=$("$GODOT" --headless --path . --quit-after 60 "res://scenes/$scene.tscn" 2>&1)
	if grep -qE "SCRIPT ERROR|^ERROR" <<< "$out"; then
		echo "FAIL scene $scene"
		grep -A1 -E "SCRIPT ERROR|^ERROR" <<< "$out"
		fail=1
	else
		echo "ok   scene $scene"
	fi
done

exit $fail
