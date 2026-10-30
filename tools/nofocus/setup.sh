#!/usr/bin/env bash
# Builds the focus-free Godot for Claude's screenshot runs in ~/.lodestone/nofocus (never committed):
# a copy of Godot.app marked background-only, a library that stops it activating itself, and a launcher.
# tools/godot.sh runs it on its own when a copy is missing or Godot was updated.
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
APP="${GODOT_APP:-/Applications/Godot.app}"
OUT="$HOME/.lodestone/nofocus"
mkdir -p "$OUT"
ver="$("$APP/Contents/MacOS/Godot" --version 2>/dev/null | head -1)"
if [ -f "$OUT/version" ] && [ "$(cat "$OUT/version")" = "$ver" ] && [ -x "$OUT/launch" ] && [ -f "$OUT/nofocus.dylib" ] && [ -d "$OUT/Godot.app" ]; then exit 0; fi
rm -rf "$OUT/Godot.app"
cp -R "$APP" "$OUT/Godot.app"
plist="$OUT/Godot.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :LSBackgroundOnly bool true" "$plist" 2>/dev/null || /usr/libexec/PlistBuddy -c "Set :LSBackgroundOnly true" "$plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier org.lodestone.godot-nofocus" "$plist"
codesign --force --deep -s - "$OUT/Godot.app" >/dev/null 2>&1   # ad hoc, no hardened runtime, so the library may load
clang -dynamiclib -framework AppKit -o "$OUT/nofocus.dylib" "$SRC/nofocus.m"
clang -o "$OUT/launch" "$SRC/launch.c"
codesign -s - -f "$OUT/nofocus.dylib" "$OUT/launch" >/dev/null 2>&1
echo "$ver" > "$OUT/version"
echo "focus-free Godot ready in $OUT ($ver)"
