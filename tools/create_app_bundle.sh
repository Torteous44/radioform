#!/bin/bash
# Create proper .app bundle structure for Radioform

set -e  # Exit on error

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DIST_DIR="$PROJECT_ROOT/dist"
APP_NAME="Radioform.app"
APP_PATH="$DIST_DIR/$APP_NAME"

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    SWIFT_ARCH="arm64-apple-macosx"
elif [ "$ARCH" = "x86_64" ]; then
    SWIFT_ARCH="x86_64-apple-macosx"
else
    echo "❌ Unsupported architecture: $ARCH"
    exit 1
fi

echo "🔨 Creating Radioform.app bundle structure..."
echo "   Architecture: $ARCH ($SWIFT_ARCH)"

# Clean and create dist directory
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

# Create .app bundle structure
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"
mkdir -p "$APP_PATH/Contents/Resources/Presets"

echo "✓ Created bundle structure"

# Copy Info.plist
echo "📋 Copying Info.plist..."
cp "$PROJECT_ROOT/apps/mac/RadioformApp/Info.plist" "$APP_PATH/Contents/Info.plist"
echo "✓ Info.plist copied"

# Copy main executable (RadioformApp)
echo "📦 Copying RadioformApp executable..."
APP_EXECUTABLE="$PROJECT_ROOT/apps/mac/RadioformApp/.build/$SWIFT_ARCH/release/RadioformApp"

if [ ! -f "$APP_EXECUTABLE" ]; then
    # Try without arch subdirectory
    APP_EXECUTABLE="$PROJECT_ROOT/apps/mac/RadioformApp/.build/release/RadioformApp"
fi

if [ ! -f "$APP_EXECUTABLE" ]; then
    echo "❌ RadioformApp executable not found. Build it first:"
    echo "   cd apps/mac/RadioformApp && swift build -c release"
    exit 1
fi

cp "$APP_EXECUTABLE" "$APP_PATH/Contents/MacOS/RadioformApp"
chmod +x "$APP_PATH/Contents/MacOS/RadioformApp"

# Add rpath for Frameworks directory (needed for Sparkle)
install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_PATH/Contents/MacOS/RadioformApp" 2>/dev/null || true

echo "✓ RadioformApp executable copied"

# Copy RadioformHost
echo "Copying RadioformHost..."
HOST_EXECUTABLE="$PROJECT_ROOT/packages/host/.build/$SWIFT_ARCH/release/RadioformHost"

if [ ! -f "$HOST_EXECUTABLE" ]; then
    # Try without arch subdirectory
    HOST_EXECUTABLE="$PROJECT_ROOT/packages/host/.build/release/RadioformHost"
fi

if [ ! -f "$HOST_EXECUTABLE" ]; then
    echo "❌ RadioformHost executable not found. Build it first:"
    echo "   cd packages/host && swift build -c release"
    exit 1
fi

cp "$HOST_EXECUTABLE" "$APP_PATH/Contents/MacOS/RadioformHost"
chmod +x "$APP_PATH/Contents/MacOS/RadioformHost"
echo "✓ RadioformHost copied"

# Copy RadioformDriver.driver
echo " Copying RadioformDriver.driver..."
DRIVER_BUNDLE="$PROJECT_ROOT/packages/driver/build/RadioformDriver.driver"

if [ ! -d "$DRIVER_BUNDLE" ]; then
    echo " RadioformDriver.driver not found - will need to be installed separately"
    echo "   Note: Driver installation will be handled during onboarding"
    echo "   For development, build with: cd packages/driver && ./install.sh"
else
    cp -R "$DRIVER_BUNDLE" "$APP_PATH/Contents/Resources/RadioformDriver.driver"
    echo "✓ RadioformDriver.driver copied"
fi

# Copy presets
echo "   Copying presets..."
PRESETS_DIR="$PROJECT_ROOT/apps/mac/RadioformApp/Sources/Resources/Presets"

if [ -d "$PRESETS_DIR" ]; then
    cp -R "$PRESETS_DIR"/* "$APP_PATH/Contents/Resources/Presets/"
    echo "✓ Presets copied ($(ls -1 "$PRESETS_DIR" | wc -l | tr -d ' ') files)"
else
    echo "  No presets directory found at $PRESETS_DIR"
fi

# Copy other app resources (images, fonts, etc.)
echo "   Copying app resources..."
RESOURCES_DIR="$PROJECT_ROOT/apps/mac/RadioformApp/Sources/Resources"
if [ -d "$RESOURCES_DIR" ]; then
    # Copy everything except Presets (already handled above)
    rsync -av --exclude "Presets" "$RESOURCES_DIR"/ "$APP_PATH/Contents/Resources/" >/dev/null
    echo "✓ Resources copied"
else
    echo "  No resources directory found at $RESOURCES_DIR"
fi

# Copy Sparkle framework
echo " Copying Sparkle.framework..."
mkdir -p "$APP_PATH/Contents/Frameworks"

SPARKLE_FRAMEWORK="$PROJECT_ROOT/apps/mac/RadioformApp/.build/$SWIFT_ARCH/release/Sparkle.framework"
if [ ! -d "$SPARKLE_FRAMEWORK" ]; then
    # Try without arch subdirectory
    SPARKLE_FRAMEWORK="$PROJECT_ROOT/apps/mac/RadioformApp/.build/release/Sparkle.framework"
fi

if [ -d "$SPARKLE_FRAMEWORK" ]; then
    cp -R "$SPARKLE_FRAMEWORK" "$APP_PATH/Contents/Frameworks/"
    echo "✓ Sparkle.framework copied"
else
    echo " Sparkle.framework not found"
    echo "   Expected at: $SPARKLE_FRAMEWORK"
fi

# Create PkgInfo file
echo "APPL????" > "$APP_PATH/Contents/PkgInfo"

echo ""
echo " Radioform.app bundle created successfully!"
echo "   Location: $APP_PATH"
echo ""
echo "Bundle contents:"
echo "  - RadioformApp (main executable)"
echo "  - RadioformHost (audio engine)"
echo "  - RadioformDriver.driver (HAL driver)"
echo "  - Presets (EQ configurations)"
echo ""
echo "To test the bundle:"
echo "  open $APP_PATH"
echo ""
