#!/bin/bash
# Create DMG with drag-to-Applications layout for Radioform

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
APP_BUNDLE="$PROJECT_ROOT/dist/Radioform.app"
VERSION="${1:-1.0.0}"
DMG_NAME="Radioform-${VERSION}.dmg"
DMG_PATH="$PROJECT_ROOT/dist/${DMG_NAME}"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Creating Radioform DMG${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Check if app bundle exists
if [ ! -d "$APP_BUNDLE" ]; then
    echo "❌ Error: Radioform.app not found at $APP_BUNDLE"
    echo "Run 'make bundle' first"
    exit 1
fi

# Clean up any existing temp directory
rm -rf "$PROJECT_ROOT/dist/dmg_temp"

# Create temporary directory for DMG contents
echo "📁 Creating temporary DMG staging directory..."
mkdir -p "$PROJECT_ROOT/dist/dmg_temp"

# Copy app bundle
echo "📦 Copying Radioform.app..."
cp -R "$APP_BUNDLE" "$PROJECT_ROOT/dist/dmg_temp/Radioform.app"

# Create Applications symlink
echo "🔗 Creating Applications symlink..."
ln -s /Applications "$PROJECT_ROOT/dist/dmg_temp/Applications"

# Remove any existing DMG
rm -f "$DMG_PATH"

# Create DMG
echo "💿 Creating DMG..."
hdiutil create \
    -volname "Radioform" \
    -srcfolder "$PROJECT_ROOT/dist/dmg_temp" \
    -ov \
    -format UDZO \
    -fs HFS+ \
    "$DMG_PATH"

# Clean up temp directory
echo "🧹 Cleaning up..."
rm -rf "$PROJECT_ROOT/dist/dmg_temp"

echo ""
echo -e "${GREEN}✅ DMG created successfully!${NC}"
echo ""
echo "Location: $DMG_PATH"
echo "Size: $(du -h "$DMG_PATH" | cut -f1)"
echo ""
echo "Next steps:"
echo "  • Sign: codesign --sign \"Developer ID Application\" \"$DMG_PATH\""
echo "  • Notarize: xcrun notarytool submit \"$DMG_PATH\" ..."
echo "  • Test: open \"$DMG_PATH\""
echo ""
