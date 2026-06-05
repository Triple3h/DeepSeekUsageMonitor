#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="DeepSeekUsageMonitor"
BUNDLE_ID="com.deepseekusagemonitor"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"

# Clean previous build
rm -rf "${APP_BUNDLE}"

# Build release binary
echo "Building release binary..."
swift build -c release

# Create .app bundle structure
echo "Creating .app bundle..."
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy binary
cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/"

# Copy SPM resource bundle
cp -R "${BUILD_DIR}/${APP_NAME}_${APP_NAME}.bundle" "${APP_BUNDLE}/Contents/Resources/"

# Copy Info.plist
cp "scripts/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"

# Copy AppIcon.icns
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/"
    echo "Added AppIcon.icns"
fi

# Compile Asset Catalog (if available)
if [ -d "Resources/Assets.xcassets" ]; then
    mkdir -p ".build/assetcatalog"
    if xcrun actool "Resources/Assets.xcassets" \
        --compile "${APP_BUNDLE}/Contents/Resources" \
        --platform macosx \
        --minimum-deployment-target 13.0 \
        --target-device mac \
        --app-icon AppIcon \
        --output-partial-info-plist ".build/assetcatalog/asset-info.plist" 2>/dev/null; then
        echo "Compiled Asset Catalog"
    else
        echo "Asset Catalog compilation skipped (using .icns fallback)"
    fi
fi

# Ad-hoc sign the app bundle
echo "Signing app bundle..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "Done: ${APP_BUNDLE}"
echo ""
echo "To install, run:"
echo "  cp -r '${APP_BUNDLE}' /Applications/"
