#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="DeepSeekUsageMonitor"
DMG_NAME="${1:-${APP_NAME}.dmg}"
DMG_VOLUME="DeepSeek Usage Monitor"
DMG_TEMP_DIR=".build/dmg-temp"

# Step 1: Build the .app bundle first
echo "=== Step 1: Building .app bundle ==="
zsh scripts/build-app.sh

# Step 2: Create DMG
echo ""
echo "=== Step 2: Creating DMG ==="

# Clean up
rm -rf "${DMG_TEMP_DIR}" "${DMG_NAME}"
mkdir -p "${DMG_TEMP_DIR}"

# Copy .app into temp dir
cp -R "${APP_NAME}.app" "${DMG_TEMP_DIR}/"

# Create a symlink to /Applications for drag-to-install
ln -s /Applications "${DMG_TEMP_DIR}/Applications"

# Create the DMG
hdiutil create \
    -volname "${DMG_VOLUME}" \
    -srcfolder "${DMG_TEMP_DIR}" \
    -ov \
    -format UDZO \
    "${DMG_NAME}"

# Clean up temp dir
rm -rf "${DMG_TEMP_DIR}"

echo ""
echo "Done: ${DMG_NAME}"
echo ""
echo "To distribute, share the DMG file."
echo "Users can open it and drag the app to Applications."
