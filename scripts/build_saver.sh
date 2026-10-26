#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

BUILD_CONFIG="release"
DO_INSTALL=false

for arg in "$@"; do
    case "${arg}" in
        debug)
            BUILD_CONFIG="debug"
            ;;
        release)
            BUILD_CONFIG="release"
            ;;
        --install)
            DO_INSTALL=true
            ;;
        *)
            ;;
    esac
done

SAVER_NAME="KoiWallpaper"
BUILD_DIR="${PROJECT_DIR}/build"
SAVER_BUNDLE="${BUILD_DIR}/${SAVER_NAME}.saver"
CONTENTS_DIR="${SAVER_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "==> Building KoiWallpaperSaver (${BUILD_CONFIG}) via Swift Package Manager..."
cd "${PROJECT_DIR}"
swift build -c "${BUILD_CONFIG}" --product KoiWallpaperSaver

BIN_PATH="$(swift build -c "${BUILD_CONFIG}" --show-bin-path)/libKoiWallpaperSaver.dylib"
if [ ! -f "${BIN_PATH}" ]; then
    echo "Error: Dynamic library not found at ${BIN_PATH}" >&2
    exit 1
fi

echo "==> Packaging into ${SAVER_BUNDLE}..."
rm -rf "${SAVER_BUNDLE}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

# Copy compiled dynamic library as bundle executable
cp "${BIN_PATH}" "${MACOS_DIR}/${SAVER_NAME}Saver"
chmod +x "${MACOS_DIR}/${SAVER_NAME}Saver"

# Generate Info.plist for macOS Screen Saver
cat > "${CONTENTS_DIR}/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundlePackageType</key>
    <string>BNDL</string>
    <key>CFBundleName</key>
    <string>KoiWallpaper</string>
    <key>CFBundleDisplayName</key>
    <string>Koi Wallpaper</string>
    <key>CFBundleIdentifier</key>
    <string>com.koiwallpaper.KoiWallpaperSaver</string>
    <key>CFBundleVersion</key>
    <string>0.1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleExecutable</key>
    <string>KoiWallpaperSaver</string>
    <key>NSPrincipalClass</key>
    <string>KoiWallpaperSaverView</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
</dict>
</plist>
EOF

# Ad-hoc codesign the bundle
echo "==> Applying ad-hoc code signature..."
codesign --force --deep --sign - "${SAVER_BUNDLE}"
codesign --verify --deep --strict --verbose=2 "${SAVER_BUNDLE}"

echo "==> Successfully created ${SAVER_BUNDLE}"
echo "    Architecture: $(lipo -archs "${MACOS_DIR}/${SAVER_NAME}Saver")"
echo "    Bundle ID:    com.koiwallpaper.KoiWallpaperSaver"
echo "    Principal:    KoiWallpaperSaverView"

if [ "${DO_INSTALL}" = true ]; then
    TARGET_DIR="${HOME}/Library/Screen Savers"
    mkdir -p "${TARGET_DIR}"
    DEST_BUNDLE="${TARGET_DIR}/${SAVER_NAME}.saver"
    echo "==> Installing to ${DEST_BUNDLE}..."
    rm -rf "${DEST_BUNDLE}"
    cp -R "${SAVER_BUNDLE}" "${DEST_BUNDLE}"
    echo "==> Installed successfully to ${DEST_BUNDLE}"
fi
