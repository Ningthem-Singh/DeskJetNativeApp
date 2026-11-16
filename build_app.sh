#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

echo "==> Building HP DeskJet Studio Pro for Apple Silicon (ARM64)..."

MACRO_LIB="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins/libSwiftUIMacros.dylib"
MACRO_FLAG=""
if [ -f "$MACRO_LIB" ]; then
    MACRO_FLAG="-load-plugin-library $MACRO_LIB"
fi

echo "==> Packaging HP DeskJet Studio Pro.app bundle..."
APP_BUNDLE="HP DeskJet Studio Pro.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

swiftc -O -parse-as-library $MACRO_FLAG \
    Sources/*.swift Sources/Views/*.swift \
    -o "$APP_BUNDLE/Contents/MacOS/HP DeskJet Studio Pro"

cp "AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
cp "Info.plist" "$APP_BUNDLE/Contents/Info.plist"
chmod +x "$APP_BUNDLE/Contents/MacOS/HP DeskJet Studio Pro"

echo "==> Ad-hoc code signing for Apple Silicon..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "==> Build complete! App available at:"
echo "    $PROJECT_DIR/$APP_BUNDLE"

if [ "$1" == "--install" ]; then
    rm -rf "/Applications/$APP_BUNDLE"
    cp -R "$APP_BUNDLE" "/Applications/"
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "/Applications/$APP_BUNDLE"
    echo "==> Installed to /Applications/$APP_BUNDLE"
fi
