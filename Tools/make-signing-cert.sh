#!/usr/bin/env bash
#
# OPTIONAL — read before running.
#
# This script MODIFIES YOUR LOGIN KEYCHAIN. It creates a self-signed certificate named
# "ClipHistory Dev" and adds it as a TRUSTED ROOT for code signing. macOS will prompt for
# your login password to authorise that. Nothing leaves your machine, and no network
# request is made, but you are adding a trust anchor — so read the script first.
#
# Why it exists: ad-hoc signing (codesign --sign -) derives the app's identity from a hash
# of its own bytes, so every rebuild looks like a brand-new app and macOS drops the
# Accessibility grant, meaning auto-paste breaks until you re-approve it. A stable
# certificate keeps the grant.
#
# You do NOT need this. build.sh falls back to ad-hoc signing and the app works fine —
# you'll just re-tick the Accessibility checkbox now and then.
#
# To undo: delete "ClipHistory Dev" from Keychain Access, then rebuild.
#
set -euo pipefail

NAME="ClipHistory Dev"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if security find-identity -v -p codesigning | grep -q "$NAME"; then
	echo "==> Identity \"$NAME\" already exists — nothing to do."
	echo "    Rebuild with ./build.sh and it will be used automatically."
	exit 0
fi

echo "==> Generating key and certificate"
cat > "$WORK/openssl.cnf" <<'CNF'
[ req ]
distinguished_name = dn
x509_extensions    = ext
prompt             = no

[ dn ]
CN = ClipHistory Dev

[ ext ]
basicConstraints = critical,CA:false
keyUsage         = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CNF

openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
	-keyout "$WORK/key.pem" -out "$WORK/cert.pem" -config "$WORK/openssl.cnf" 2>/dev/null

openssl pkcs12 -export -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
	-name "$NAME" -passout pass: -out "$WORK/identity.p12"

# -T scopes key access to codesign only, rather than -A which would allow every binary.
echo "==> Importing into login keychain"
security import "$WORK/identity.p12" -k "$KEYCHAIN" -P "" -T /usr/bin/codesign

echo "==> Trusting it for code signing (password prompt expected)"
security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$WORK/cert.pem"

echo
echo "==> Done. Verify with:"
echo "      security find-identity -v -p codesigning"
echo
echo "    Then: ./build.sh && ./install.sh"
echo "    Grant Accessibility once more — it will persist across rebuilds from now on."
