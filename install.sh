#!/usr/bin/env bash
# Installs the built app to ~/Applications and registers a launch agent so it
# starts at login. Re-run after each ./build.sh to update the installed copy.
set -euo pipefail
cd "$(dirname "$0")"

NAME="ClipHistory"
BUNDLE="$NAME.app"
LABEL="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' Info.plist)"
DEST="$HOME/Applications"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

[ -d "$BUNDLE" ] || { echo "!! No $BUNDLE — run ./build.sh first"; exit 1; }

echo "==> Stopping any running copy"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
pkill -f "$BUNDLE/Contents/MacOS/$NAME" 2>/dev/null || true

echo "==> Installing to $DEST/$BUNDLE"
mkdir -p "$DEST"
rm -rf "$DEST/$BUNDLE"
cp -R "$BUNDLE" "$DEST/"

echo "==> Writing launch agent"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$LABEL</string>
	<key>ProgramArguments</key>
	<array>
		<string>$DEST/$BUNDLE/Contents/MacOS/$NAME</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<!-- false so "Quit" from the menu actually quits instead of being restarted -->
	<key>KeepAlive</key>
	<false/>
</dict>
</plist>
PLIST_EOF

launchctl bootstrap "gui/$(id -u)" "$PLIST"

echo
echo "==> Installed and running. It will start automatically at login."
echo "    Press Cmd+Option+V to open the history (changeable in Preferences…)."
echo
echo "    Uninstall: ./uninstall.sh"
