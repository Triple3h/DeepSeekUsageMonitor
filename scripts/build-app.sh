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

# Copy SPM resource bundle to Contents/Resources (standard location)
cp -R "${BUILD_DIR}/${APP_NAME}_${APP_NAME}.bundle" "${APP_BUNDLE}/Contents/Resources/"

# Also copy to .app root (SPM Bundle.module searches here too)
cp -R "${BUILD_DIR}/${APP_NAME}_${APP_NAME}.bundle" "${APP_BUNDLE}/"

# Ensure SPM resource bundle contains Info.plist (required for Bundle.module)
RESOURCE_BUNDLE="${APP_BUNDLE}/Contents/Resources/${APP_NAME}_${APP_NAME}.bundle"
RESOURCE_BUNDLE_ROOT="${APP_BUNDLE}/${APP_NAME}_${APP_NAME}.bundle"

create_resource_info_plist() {
    local bundle_dir=$1
    if [ ! -f "${bundle_dir}/Contents/Info.plist" ]; then
        echo "Creating Info.plist for resource bundle at ${bundle_dir}..."
        mkdir -p "${bundle_dir}/Contents/Resources"
        cat > "${bundle_dir}/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>\$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>com.deepseekusagemonitor.${APP_NAME}-resources</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME} Resources</string>
    <key>CFBundlePackageType</key>
    <string>BNDL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
</dict>
</plist>
EOF
        # Move resources into Contents/Resources if they are at bundle root
        if [ -f "${bundle_dir}/deepseek-logo.png" ]; then
            mv "${bundle_dir}/deepseek-logo.png" "${bundle_dir}/Contents/Resources/"
            mv "${bundle_dir}/mimo-logo.png" "${bundle_dir}/Contents/Resources/"
            echo "Moved resources into Contents/Resources"
        fi
    fi
}

create_resource_info_plist "${RESOURCE_BUNDLE}"
create_resource_info_plist "${RESOURCE_BUNDLE_ROOT}"

# Copy Info.plist and inject version from VERSION file
cp "scripts/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"
if [ -f "VERSION" ]; then
    VERSION=$(cat VERSION | tr -d '[:space:]')
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "${APP_BUNDLE}/Contents/Info.plist"
    echo "Injected version: ${VERSION}"
fi

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
