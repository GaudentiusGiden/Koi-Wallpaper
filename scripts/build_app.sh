#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

BUILD_CONFIG="release"
INSTALL_TO_APPLICATIONS=false

for arg in "$@"; do
    case "$arg" in
        --install)
            INSTALL_TO_APPLICATIONS=true
            ;;
        debug|release)
            BUILD_CONFIG="$arg"
            ;;
    esac
done

APP_NAME="KoiWallpaper"
APP_VERSION="1.0.0"
BUILD_DIR="${PROJECT_DIR}/build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
ICNS_PATH="${BUILD_DIR}/AppIcon.icns"

mkdir -p "${BUILD_DIR}"

echo "==> Generating Zen Arc Koi AppIcon.icns..."
swift "${SCRIPT_DIR}/generate_app_icon.swift"

echo "==> Building ${APP_NAME} v${APP_VERSION} (${BUILD_CONFIG}, arm64) via Swift Package Manager..."
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

# Copy compiled executable and app icon
cp "${BIN_PATH}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"
cp "${ICNS_PATH}" "${RESOURCES_DIR}/AppIcon.icns"

# Generate Info.plist
cat > "${CONTENTS_DIR}/Info.plist" << EOF
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
    <string>${APP_VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleExecutable</key>
    <string>KoiWallpaper</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.lifestyle</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Koi Wallpaper. All rights reserved.</string>
</dict>
</plist>
EOF

# Ad-hoc codesign the bundle
echo "==> Applying ad-hoc code signature..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "==> Successfully created ${APP_BUNDLE}"
echo "    Version:      ${APP_VERSION}"
echo "    Architecture: $(lipo -archs "${MACOS_DIR}/${APP_NAME}")"
echo "    Bundle ID:    com.koiwallpaper.KoiWallpaper"
echo "    App Icon:     ${RESOURCES_DIR}/AppIcon.icns"
echo "    LSUIElement:  true (menu bar agent)"

if [ "${INSTALL_TO_APPLICATIONS}" = true ]; then
    echo "==> Installing ${APP_NAME}.app to /Applications/${APP_NAME}.app..."
    rm -rf "/Applications/${APP_NAME}.app"
    ditto "${APP_BUNDLE}" "/Applications/${APP_NAME}.app"
    echo "==> Installed to /Applications/${APP_NAME}.app"
fi
