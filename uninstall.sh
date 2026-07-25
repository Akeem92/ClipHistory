#!/usr/bin/env bash
# Removes the launch agent and the installed app. Leaves your history JSON alone
# unless you pass --purge.
set -euo pipefail
cd "$(dirname "$0")"

NAME="ClipHistory"
LABEL="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' Info.plist)"
DEST="$HOME/Applications/$NAME.app"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
DATA="$HOME/Library/Application Support/ClipHistory"

echo "==> Stopping"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
pkill -f "$NAME.app/Contents/MacOS/$NAME" 2>/dev/null || true

rm -f "$PLIST"
rm -rf "$DEST"
echo "==> Removed app and launch agent"

if [ "${1:-}" = "--purge" ]; then
	rm -rf "$DATA"
	echo "==> Removed history data"
else
	echo "    History kept at: $DATA"
	echo "    Delete it with: ./uninstall.sh --purge"
fi
