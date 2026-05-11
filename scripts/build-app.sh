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

# Copy Info.plist
cp "scripts/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"

# Ad-hoc sign the app bundle
echo "Signing app bundle..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "Done: ${APP_BUNDLE}"
echo ""
echo "To install, run:"
echo "  cp -r '${APP_BUNDLE}' /Applications/"
