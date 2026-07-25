#!/usr/bin/env bash
# Compiles the package, then assembles the .app bundle by hand.
# SPM has no macOS-app product type, so the bundle is just mkdir + cp.
set -euo pipefail
cd "$(dirname "$0")"

NAME="ClipHistory"
BUNDLE="$NAME.app"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' Info.plist)"

echo "==> Compiling (release)"
swift build -c release

BINARY="$(swift build -c release --show-bin-path)/$NAME"
[ -f "$BINARY" ] || { echo "!! Expected binary at $BINARY"; exit 1; }

# Only re-render when the generator changed — it's slow-ish and rarely edited.
if [ ! -f "$NAME.icns" ] || [ Tools/make-icon.swift -nt "$NAME.icns" ]; then
	echo "==> Generating icon"
	swift Tools/make-icon.swift
	iconutil --convert icns --output "$NAME.icns" "$NAME.iconset"
	rm -rf "$NAME.iconset"
else
	echo "==> Icon up to date"
fi

echo "==> Assembling $BUNDLE"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$BINARY" "$BUNDLE/Contents/MacOS/$NAME"
cp Info.plist "$BUNDLE/Contents/Info.plist"
cp "$NAME.icns" "$BUNDLE/Contents/Resources/$NAME.icns"

# A stable identity keeps the Accessibility grant across rebuilds; ad-hoc doesn't.
SIGN_IDENTITY="ClipHistory Dev"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "$SIGN_IDENTITY"; then
	echo "==> Signing with \"$SIGN_IDENTITY\""
	codesign --force --sign "$SIGN_IDENTITY" --identifier "$BUNDLE_ID" "$BUNDLE"
else
	echo "==> Signing ad-hoc"
	echo "    Tip: run Tools/make-signing-cert.sh to stop re-approving Accessibility."
	codesign --force --sign - --identifier "$BUNDLE_ID" "$BUNDLE"
fi

echo
echo "==> Built $PWD/$BUNDLE"
echo "    Try it:      open $BUNDLE"
echo "    Install it:  ./install.sh"
