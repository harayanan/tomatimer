#!/bin/bash
# Builds build/Tomatimer.app (universal, ad-hoc signed). Requires macOS with swiftc.
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${VERSION:-1.0.0}"
APP="build/Tomatimer.app"
MIN_OS="13.0"

rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/obj

for ARCH in arm64 x86_64; do
  echo "→ compiling $ARCH"
  swiftc -O -swift-version 5 \
    -target "$ARCH-apple-macos$MIN_OS" \
    -module-name Tomatimer -parse-as-library \
    Sources/*.swift \
    -o "build/obj/Tomatimer-$ARCH"
done
lipo -create build/obj/Tomatimer-arm64 build/obj/Tomatimer-x86_64 -output "$APP/Contents/MacOS/Tomatimer"

sed "s/__VERSION__/$VERSION/g" Info.plist > "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "→ drawing icon"
swift scripts/make-icon.swift build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

echo "→ signing (ad-hoc)"
codesign --force --deep --sign - "$APP"

echo "✓ $APP ($VERSION)"
