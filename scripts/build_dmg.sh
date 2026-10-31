#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

INSTALL_TO_APPLICATIONS=false
for arg in "$@"; do
    case "$arg" in
        --install)
            INSTALL_TO_APPLICATIONS=true
            ;;
    esac
done

APP_NAME="KoiWallpaper"
APP_VERSION="1.0.0"
VOLUME_NAME="Koi Wallpaper"
BUILD_DIR="${PROJECT_DIR}/build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
ICNS_PATH="${BUILD_DIR}/AppIcon.icns"
STAGING_DIR="${BUILD_DIR}/dmg-staging"
DMG_VERSIONED="${BUILD_DIR}/${APP_NAME}-${APP_VERSION}.dmg"
DMG_LATEST="${BUILD_DIR}/${APP_NAME}.dmg"

# 1. Build the release .app bundle and AppIcon.icns
"${SCRIPT_DIR}/build_app.sh" release

# 2. Prepare staging directory for DMG
echo "==> Preparing DMG staging directory..."
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"

ditto "${APP_BUNDLE}" "${STAGING_DIR}/${APP_NAME}.app"
ln -s /Applications "${STAGING_DIR}/Applications"

if [ -f "${ICNS_PATH}" ]; then
    cp "${ICNS_PATH}" "${STAGING_DIR}/.VolumeIcon.icns"
    if [ -x "/usr/bin/SetFile" ]; then
        /usr/bin/SetFile -a V "${STAGING_DIR}/.VolumeIcon.icns" || true
        /usr/bin/SetFile -a C "${STAGING_DIR}" || true
    fi
fi

# 3. Create compressed UDZO DMG image
echo "==> Creating compressed disk image ${DMG_VERSIONED}..."
rm -f "${DMG_VERSIONED}" "${DMG_LATEST}"
hdiutil create \
    -volname "${VOLUME_NAME}" \
    -srcfolder "${STAGING_DIR}" \
    -ov \
    -format UDZO \
    "${DMG_VERSIONED}"

rm -rf "${STAGING_DIR}"

# 4. Ad-hoc sign the DMG and create convenience copy KoiWallpaper.dmg
codesign --force --sign - "${DMG_VERSIONED}"
cp "${DMG_VERSIONED}" "${DMG_LATEST}"

echo "==> Successfully created DMG installer:"
echo "    Versioned DMG: ${DMG_VERSIONED}"
echo "    Latest DMG:    ${DMG_LATEST}"

if [ "${INSTALL_TO_APPLICATIONS}" = true ]; then
    echo "==> Installing ${APP_NAME}.app to /Applications/${APP_NAME}.app..."
    rm -rf "/Applications/${APP_NAME}.app"
    ditto "${APP_BUNDLE}" "/Applications/${APP_NAME}.app"
    echo "==> Installed to /Applications/${APP_NAME}.app"
fi
