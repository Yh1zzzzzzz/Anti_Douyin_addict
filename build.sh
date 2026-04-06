#!/bin/bash

set -e

APP_NAME="DouyinAntiAddict"
BUILD_DIR="./build"
SCHEME="DouyinAntiAddict"

echo "Building $APP_NAME with xcodebuild..."

xcodebuild clean build \
    -project "$APP_NAME.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    -quiet

APP_PATH=$(find "$BUILD_DIR/DerivedData" -name "$APP_NAME.app" -type d | head -1)

if [ -z "$APP_PATH" ]; then
    echo "Error: App not found in build output"
    exit 1
fi

OUTPUT_DIR="$BUILD_DIR"
rm -rf "$OUTPUT_DIR/$APP_NAME.app"
cp -R "$APP_PATH" "$OUTPUT_DIR/$APP_NAME.app"

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
