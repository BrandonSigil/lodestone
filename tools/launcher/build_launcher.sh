#!/usr/bin/env bash
# Builds "Lodestone Launcher.app" in ~/Applications: a tiny Mac app that starts the game.
# It answers lodestone://launch links, so the studio page's Launch button opens the game at once.
# Opening the app itself (Dock, Spotlight) starts the game too.
# Usage: tools/launcher/build_launcher.sh   (Env: LODESTONE_GAME, default <repo>/game)
set -euo pipefail
[ "$(uname)" = Darwin ] || { echo "Mac only"; exit 1; }
GAME="${LODESTONE_GAME:-$(cd "$(dirname "$0")/../../game" && pwd)}"
APP="$HOME/Applications/Lodestone Launcher.app"
SRC="$(mktemp -d)/launcher.applescript"

cat > "$SRC" <<EOF
on launchGame()
	do shell script "open -n -a Godot --args --path " & quoted form of "$GAME"
end launchGame
on open location theURL
	launchGame()
end open location
on run
	launchGame()
end run
EOF

mkdir -p "$HOME/Applications"
rm -rf "$APP"
osacompile -o "$APP" "$SRC"

PLIST="$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.lodestone.launcher" "$PLIST" 2>/dev/null ||
	/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.lodestone.launcher" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes array" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0 dict" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLName string Lodestone" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string lodestone" "$PLIST"

codesign --force --deep --sign - "$APP" 2>/dev/null   # the plist edits break osacompile's signature
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"
echo "Built $APP (game: $GAME)"
