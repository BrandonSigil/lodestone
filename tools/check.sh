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
# Every Godot run here is watched: over GODOT_MEM_CAP_MB (default 6144) it's killed with "killed: over memory cap".
RUN=(../tools/mem_guard.sh "$GODOT")

# On the Mac, Godot's "use external editor" setting pointed back at Godot itself, so any run that wanted to show a
# script opened a stray Project Manager on Brandon's main display. Keep it off (editor settings are saved per version).
for es in "$HOME/Library/Application Support/Godot"/editor_settings-4*.tres; do
	[ -f "$es" ] && grep -q '^text_editor/external/use_external_editor = true' "$es" &&
		sed -i '' 's|^text_editor/external/use_external_editor = true|text_editor/external/use_external_editor = false|' "$es"
done

"${RUN[@]}" --headless --path . --import >/dev/null 2>&1

if ! "${RUN[@]}" --headless --path . -s res://tests/run_tests.gd; then
	fail=1
fi

for scene in launch village trail combat world_map battle_view explore map_maker plot_maker overworld fishing; do
	out=$("${RUN[@]}" --headless --path . --quit-after 60 "res://scenes/$scene.tscn" 2>&1)
	if grep -qE "SCRIPT ERROR|^ERROR|^killed: over memory cap" <<< "$out"; then
		echo "FAIL scene $scene"
		grep -A1 -E "SCRIPT ERROR|^ERROR|^killed: over memory cap" <<< "$out"
		fail=1
	else
		echo "ok   scene $scene"
	fi
done

# The shape gate ([USER] 2026-10-30: never show him a box): the crypt redesign prototype must not read as one.
if command -v python3 >/dev/null 2>&1 && [ -f data/explore/crypt.json ]; then
	if ! shape=$(python3 ../tools/map_shape.py data/explore/crypt.json); then
		echo "FAIL map shape: $shape"
		fail=1
	fi
fi

# The scale gate: props must make spatial sense against the hero (doors taller than he is).
if command -v python3 >/dev/null 2>&1; then
	if ! scale=$(python3 ../tools/art/prop_scale_check.py data/explore/village_v2.json); then
		echo "FAIL prop scale: $scale"
		fail=1
	fi
fi

# The E2E robot plays the whole loop (about 2 minutes). Opt in: E2E=1 tools/check.sh
if [ "${E2E:-0}" = "1" ]; then
	out=$("${RUN[@]}" --headless --path . -s res://tools/e2e_play.gd 2>&1)
	code=$?
	grep -E "^FAIL|^E2E|fights lost|^killed: over memory cap" <<< "$out"
	if grep -q "SCRIPT ERROR" <<< "$out"; then
		echo "FAIL e2e script errors:"
		grep -A3 "SCRIPT ERROR" <<< "$out" | head -20
		code=1
	fi
	# Engine errors fail the run too (a deferred call on a freed node, 2026-10-30), all but Godot's own leak
	# report at exit.
	errs=$(grep -E "^ERROR:" <<< "$out" | grep -vE "still in use at exit|leaked at exit")
	if [ -n "$errs" ]; then
		echo "FAIL e2e engine errors:"
		sort <<< "$errs" | uniq -c | head -10
		code=1
	fi
	if [ $code -ne 0 ]; then
		echo "FAIL e2e"
		fail=1
	fi
fi

exit $fail
