#!/bin/bash
set -e

PROJECT_NAME="Shuttle"
CONFIG="Release"
OUTPUT_DIR="build/${CONFIG}"

echo "=== Building ${PROJECT_NAME} ==="

# Clean previous build
rm -rf build/
rm -f "${PROJECT_NAME}.dmg"

# Build project
xcodebuild -project "${PROJECT_NAME}.xcodeproj" -configuration ${CONFIG} build

# Prepare DMG content
DMG_TEMP="/tmp/${PROJECT_NAME}-dmg"
rm -rf "${DMG_TEMP}"
mkdir -p "${DMG_TEMP}"
cp -R "${OUTPUT_DIR}/${PROJECT_NAME}.app" "${DMG_TEMP}/"
ln -s /Applications "${DMG_TEMP}/Applications"

# Create DMG
hdiutil create -volname "${PROJECT_NAME}" -srcfolder "${DMG_TEMP}" -ov -format UDZO "${PROJECT_NAME}.dmg"

# Cleanup
rm -rf "${DMG_TEMP}"

echo "=== Done: ${PROJECT_NAME}.dmg ==="
ls -lh "${PROJECT_NAME}.dmg"