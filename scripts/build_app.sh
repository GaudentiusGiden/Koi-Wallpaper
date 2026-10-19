#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

BUILD_CONFIG="${1:-release}"
APP_NAME="KoiWallpaper"
BUILD_DIR="${PROJECT_DIR}/build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "==> Building ${APP_NAME} (${BUILD_CONFIG}) via Swift Package Manager..."
cd "${PROJECT_DIR}"
swift build -c "${BUILD_CONFIG}"

BIN_PATH="$(swift build -c "${BUILD_CONFIG}" --show-bin-path)/${APP_NAME}"
if [ ! -f "${BIN_PATH}" ]; then
    echo "Error: Binary not found at ${BIN_PATH}" >&2
    exit 1
fi

echo "==> Packaging into ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

# Copy compiled executable
cp "${BIN_PATH}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

# Generate Info.plist
cat > "${CONTENTS_DIR}/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleName</key>
    <string>KoiWallpaper</string>
    <key>CFBundleDisplayName</key>
    <string>Koi Wallpaper</string>
    <key>CFBundleIdentifier</key>
    <string>com.koiwallpaper.KoiWallpaper</string>
    <key>CFBundleVersion</key>
    <string>0.1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleExecutable</key>
    <string>KoiWallpaper</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

# Ad-hoc codesign the bundle
echo "==> Applying ad-hoc code signature..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "==> Successfully created ${APP_BUNDLE}"
echo "    Architecture: $(lipo -archs "${MACOS_DIR}/${APP_NAME}")"
echo "    Bundle ID:    com.koiwallpaper.KoiWallpaper"
echo "    LSUIElement:  true (menu bar agent)"
