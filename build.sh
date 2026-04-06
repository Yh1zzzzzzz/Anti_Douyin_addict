#!/bin/bash

set -e

APP_NAME="DouyinAntiAddict"
BUILD_DIR="./build"
SCHEME="DouyinAntiAddict"
CONFIGURATION="Release"

echo "Building $APP_NAME with xcodebuild..."

xcodebuild clean build \
    -project "$APP_NAME.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    CODE_SIGNING_ALLOWED=NO \
    -quiet

APP_PATH="$BUILD_DIR/DerivedData/Build/Products/$CONFIGURATION/$APP_NAME.app"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: App not found in build output"
    exit 1
fi

OUTPUT_DIR="$BUILD_DIR"
if [ -d "$OUTPUT_DIR/$APP_NAME.app" ]; then
    mv "$OUTPUT_DIR/$APP_NAME.app" "$OUTPUT_DIR/$APP_NAME.app.previous.$(date +%Y%m%d%H%M%S)"
fi
ditto "$APP_PATH" "$OUTPUT_DIR/$APP_NAME.app"

echo ""
echo "Build complete!"
echo "App location: $OUTPUT_DIR/$APP_NAME.app"
echo ""
echo "To run the app:"
echo "  open $OUTPUT_DIR/$APP_NAME.app"
echo ""
echo "To install to Applications:"
echo "  cp -R $OUTPUT_DIR/$APP_NAME.app /Applications/"
echo ""
echo "Note: The app will request accessibility permissions to monitor browser activity."
echo "      Grant permissions in System Settings > Privacy & Security > Accessibility"
