#!/bin/bash
set -e

APP_NAME="Tasks"
EXECUTABLE_NAME="TasksApp"
BUNDLE_NAME="$APP_NAME.app"
ICON_SOURCE="Resources/AppIcon.png"
OUTPUT_DIR="."

VERSION=${1:-"1.2.0"}
BUILD=${2:-"1"}

echo "🚀 Building $APP_NAME v$VERSION ($BUILD)..."
swift build -c release

echo "📦 Creating Bundle Structure..."
mkdir -p "$OUTPUT_DIR/$BUNDLE_NAME/Contents/MacOS"
mkdir -p "$OUTPUT_DIR/$BUNDLE_NAME/Contents/Resources"

echo "📝 Creating Info.plist..."
cat > "$OUTPUT_DIR/$BUNDLE_NAME/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$EXECUTABLE_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.$APP_NAME</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

if [ -f "$ICON_SOURCE" ]; then
    echo "🎨 Generating AppIcon.icns..."
    ICONSET_DIR="Tasks.iconset"
    mkdir -p "$ICONSET_DIR"

    # Generate standard sizes
    sips -z 16 16     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png" > /dev/null
    sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png" > /dev/null
    sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png" > /dev/null
    sips -z 64 64     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png" > /dev/null
    sips -z 128 128   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png" > /dev/null
    sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" > /dev/null
    sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png" > /dev/null
    sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" > /dev/null
    sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png" > /dev/null
    sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" > /dev/null

    iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_DIR/$BUNDLE_NAME/Contents/Resources/AppIcon.icns"
    rm -rf "$ICONSET_DIR"
else
    echo "⚠️  Warning: No icon found at $ICON_SOURCE"
fi

echo "🚚 Copying Executable..."
cp ".build/release/$EXECUTABLE_NAME" "$OUTPUT_DIR/$BUNDLE_NAME/Contents/MacOS/$EXECUTABLE_NAME"

echo "🔏 Signing Bundle (Ad-hoc)..."
codesign --force --deep -s - "$OUTPUT_DIR/$BUNDLE_NAME"

echo "✅ Done! App saved to $OUTPUT_DIR/$BUNDLE_NAME"
