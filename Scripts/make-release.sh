#!/bin/bash
# Сборка релизного .app-бандла AudioSet.
#
# Использование:
#   Scripts/make-release.sh            — сборка в build/AudioSet.app
#   Scripts/make-release.sh --install  — то же + установка в ~/Applications
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME=AudioSet
BUNDLE_ID=local.audioset.AudioSet
VERSION=1.0.0
INSTALL_DIR="${HOME}/Applications"

echo "==> swift build -c release"
swift build -c release

APP_DIR="build/${APP_NAME}.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
cp ".build/release/${APP_NAME}" "$APP_DIR/Contents/MacOS/${APP_NAME}"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>AudioSet</string>
    <key>CFBundleDisplayName</key>
    <string>AudioSet</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

echo "==> бандл готов: ${APP_DIR}"

if [[ "${1:-}" == "--install" ]]; then
    mkdir -p "$INSTALL_DIR"
    rm -rf "${INSTALL_DIR}/${APP_NAME}.app"
    cp -R "$APP_DIR" "${INSTALL_DIR}/"
    echo "==> установлен: ${INSTALL_DIR}/${APP_NAME}.app"
fi
