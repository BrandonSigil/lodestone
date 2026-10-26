#!/usr/bin/env bash
# Saves a PNG of each screen so Claude can look at visual work instead of guessing.
# Needs a display; on a headless Linux box it uses xvfb-run.
# Usage: GODOT=/path/to/godot tools/screenshot.sh [out_dir]
set -euo pipefail
GODOT="${GODOT:-godot}"
OUT="$(cd "$(dirname "$0")/.." && pwd)/${1:-screenshots}"
mkdir -p "$OUT"
cd "$(dirname "$0")/../game"
run=("$GODOT" --path . --rendering-driver opengl3)
if [ -z "${DISPLAY:-}" ] && command -v xvfb-run >/dev/null; then
	run=(xvfb-run -a -s "-screen 0 1280x720x24" "${run[@]}")
fi
for scene in village trail combat world_map; do
	"${run[@]}" -s res://tools/screenshot.gd -- "res://scenes/$scene.tscn" "$OUT/$scene.png"
done
echo "saved to $OUT"
