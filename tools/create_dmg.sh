#!/bin/bash
# Create DMG with custom background for Radioform

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
APP_BUNDLE="$PROJECT_ROOT/dist/Radioform.app"
DMG_NAME="Radioform.dmg"
DMG_PATH="$PROJECT_ROOT/dist/${DMG_NAME}"
BACKGROUND_IMG="$SCRIPT_DIR/dmg/dmg-background.png"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
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

# Check if create-dmg is installed
if ! command -v create-dmg &> /dev/null; then
    echo -e "${YELLOW}  create-dmg not found. Install with: brew install create-dmg${NC}"
    echo "Falling back to basic DMG creation..."

    # Fallback to basic hdiutil method
    rm -rf "$PROJECT_ROOT/dist/dmg_temp"
    mkdir -p "$PROJECT_ROOT/dist/dmg_temp"
    cp -R "$APP_BUNDLE" "$PROJECT_ROOT/dist/dmg_temp/Radioform.app"
    ln -s /Applications "$PROJECT_ROOT/dist/dmg_temp/Applications"
    rm -f "$DMG_PATH"
    hdiutil create -volname "Radioform" -srcfolder "$PROJECT_ROOT/dist/dmg_temp" -ov -format UDZO -fs HFS+ "$DMG_PATH"
    rm -rf "$PROJECT_ROOT/dist/dmg_temp"
    echo -e "${GREEN}✓ DMG created (basic layout)${NC}"
    exit 0
fi

# Check if background image exists
if [ ! -f "$BACKGROUND_IMG" ]; then
    echo -e "${YELLOW}  Background image not found at $BACKGROUND_IMG${NC}"
    echo "Creating DMG without custom background..."
    BACKGROUND_ARG=""
else
    echo "📷 Using custom background: $BACKGROUND_IMG"
    BACKGROUND_ARG="--background $BACKGROUND_IMG"
fi

# Remove any existing DMG
rm -f "$DMG_PATH"

# Create DMG with create-dmg
echo " Creating DMG with custom layout..."
create-dmg \
    --volname "Radioform" \
    $BACKGROUND_ARG \
    --window-pos 200 120 \
    --window-size 660 450 \
    --icon-size 100 \
    --icon "Radioform.app" 210 220 \
    --app-drop-link 455 220 \
    --hide-extension "Radioform.app" \
    --no-internet-enable \
    "$DMG_PATH" \
    "$APP_BUNDLE"

echo ""
echo -e "${GREEN}✓ DMG created successfully!${NC}"
echo ""
echo "Location: $DMG_PATH"
echo "Size: $(du -h "$DMG_PATH" | cut -f1)"
echo ""
echo "Next steps:"
echo "  • Sign: codesign --sign \"Developer ID Application\" \"$DMG_PATH\""
echo "  • Notarize: xcrun notarytool submit \"$DMG_PATH\" ..."
echo "  • Test: open \"$DMG_PATH\""
echo ""
