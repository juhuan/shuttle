#!/bin/bash
set -e

PROJECT_NAME="Shuttle"
CONFIG="Release"
OUTPUT_DIR="build/Build/Products/${CONFIG}"
DMG_NAME="${PROJECT_NAME}.dmg"

# Signing / notarization are optional and driven by environment.
#   APPLE_DEVELOPER_IDENTITY  - "Developer ID Application: ..." (empty = unsigned build)
#   APPLE_TEAM_ID             - Apple Developer Program Team ID
#   APPLE_NOTARY_USER         - Apple ID for notarytool
#   APPLE_NOTARY_PASSWORD     - App-specific password for notarytool
IDENTITY="${APPLE_DEVELOPER_IDENTITY:-}"
TEAM_ID="${APPLE_TEAM_ID:-}"
NOTARY_USER="${APPLE_NOTARY_USER:-}"
NOTARY_PASSWORD="${APPLE_NOTARY_PASSWORD:-}"

echo "=== Building ${PROJECT_NAME} ==="

# Clean previous build
rm -rf build/
rm -f "${DMG_NAME}"

# Build project
if [ -n "$IDENTITY" ]; then
    xcodebuild -project "${PROJECT_NAME}.xcodeproj" \
        -scheme "${PROJECT_NAME}" \
        -configuration ${CONFIG} \
        -derivedDataPath build \
        CODE_SIGN_IDENTITY="$IDENTITY" \
        DEVELOPMENT_TEAM="$TEAM_ID" \
        build
else
    echo "No APPLE_DEVELOPER_IDENTITY set — building unsigned."
    xcodebuild -project "${PROJECT_NAME}.xcodeproj" \
        -scheme "${PROJECT_NAME}" \
        -configuration ${CONFIG} \
        -derivedDataPath build \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        build
fi

APP_PATH="${OUTPUT_DIR}/${PROJECT_NAME}.app"

# Notarize the signed app (only when signing + credentials are present)
if [ -n "$IDENTITY" ] && [ -n "$TEAM_ID" ] && [ -n "$NOTARY_USER" ] && [ -n "$NOTARY_PASSWORD" ]; then
    ZIP_PATH="/tmp/${PROJECT_NAME}-notary.zip"
    rm -f "$ZIP_PATH"
    echo "=== Notarizing ${APP_PATH} ==="
    ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
    xcrun notarytool submit "$ZIP_PATH" \
        --apple-id "$NOTARY_USER" \
        --password "$NOTARY_PASSWORD" \
        --team-id "$TEAM_ID" \
        --wait
    echo "=== Stapling ==="
    xcrun stapler staple "$APP_PATH"
fi

# Prepare DMG content
DMG_TEMP="/tmp/${PROJECT_NAME}-dmg"
rm -rf "${DMG_TEMP}"
mkdir -p "${DMG_TEMP}"
cp -R "$APP_PATH" "${DMG_TEMP}/"
ln -s /Applications "${DMG_TEMP}/Applications"

# Create DMG
hdiutil create -volname "${PROJECT_NAME}" -srcfolder "${DMG_TEMP}" -ov -format UDZO "${DMG_NAME}"

# Cleanup
rm -rf "${DMG_TEMP}"

echo "=== Done: ${DMG_NAME} ==="
ls -lh "${DMG_NAME}"