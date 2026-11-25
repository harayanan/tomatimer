#!/bin/bash
# Installs or updates Tomatimer in /Applications from the latest GitHub release.
set -euo pipefail

URL="https://github.com/harayanan/tomatimer/releases/latest/download/Tomatimer.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading Tomatimer…"
curl -fsSL "$URL" -o "$TMP/Tomatimer.zip"
ditto -x -k "$TMP/Tomatimer.zip" "$TMP"

# Quit a running copy before replacing it.
osascript -e 'tell application id "app.tomatimer.Tomatimer" to quit' >/dev/null 2>&1 || true
pkill -x Tomatimer >/dev/null 2>&1 || true
sleep 1

rm -rf /Applications/Tomatimer.app
mv "$TMP/Tomatimer.app" /Applications/Tomatimer.app
xattr -cr /Applications/Tomatimer.app

open /Applications/Tomatimer.app
echo "Installed. Look for the ring in your menu bar."
