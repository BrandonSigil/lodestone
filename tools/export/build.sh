#!/usr/bin/env bash
# Playtest builds for friends and family: a Mac .app (zipped) and a Windows .exe, in build/.
# Usage: tools/export/build.sh [mac|windows|all]   (GODOT=/path/to/godot to pick the binary)
#
# Needs Godot's export templates for this exact version (Editor > Manage Export Templates > Download, or the .tpz
# from godotengine.org installed into ~/Library/Application Support/Godot/export_templates/<version>/). They are not
# installed on this Mac yet (2026-11-13): this script says so and stops.
#
# The presets live here (tools/export/export_presets.cfg) because game/export_presets.cfg is gitignored (it can hold
# signing secrets). This one holds none: the Mac build is ad-hoc signed, so on first open a tester right-clicks the app
# and picks Open; Windows SmartScreen asks "Run anyway". Release builds hide Dev Tools and the F7/F8/F10 keys
# (Game.dev_available); F12 saves a feedback note for every player.
set -euo pipefail
GODOT="${GODOT:-$(command -v godot || echo /Applications/Godot.app/Contents/MacOS/Godot)}"
root="$(cd "$(dirname "$0")/../.." && pwd)"
which="${1:-all}"

version="$("$GODOT" --version | sed -E 's/^([0-9]+\.[0-9]+(\.[0-9]+)?)\.([a-z]+[0-9]*)\..*/\1.\3/')"
templates="$HOME/Library/Application Support/Godot/export_templates/$version"
if [ ! -d "$templates" ]; then
	echo "No export templates for Godot $version at:"
	echo "  $templates"
	echo "Install them first (Godot editor: Editor > Manage Export Templates > Download and Install)."
	exit 1
fi

cp "$root/tools/export/export_presets.cfg" "$root/game/export_presets.cfg"
mkdir -p "$root/build/mac" "$root/build/windows"
cd "$root/game"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
if [ "$which" = "mac" ] || [ "$which" = "all" ]; then
	"$GODOT" --headless --path . --export-release "macOS" "$root/build/mac/Lodestone.zip"
	echo "built build/mac/Lodestone.zip"
fi
if [ "$which" = "windows" ] || [ "$which" = "all" ]; then
	"$GODOT" --headless --path . --export-release "Windows" "$root/build/windows/Lodestone.exe"
	echo "built build/windows/Lodestone.exe"
fi
