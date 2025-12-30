#!/bin/bash
set -e

# Radioform Notarization Script
# Submits the signed app to Apple for notarization

APP_PATH="dist/Radioform.app"
ZIP_PATH="dist/Radioform.zip"

echo ""
echo "📤 Notarizing Radioform.app..."
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Checking Prerequisites"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo "❌ ERROR: $APP_PATH not found"
    echo "   Run 'make bundle' and 'make sign' first"
    exit 1
fi

# Check for required environment variables
if [ -z "$APPLE_ID" ]; then
    echo "❌ ERROR: APPLE_ID environment variable not set"
    echo ""
    echo "Set your Apple ID email:"
    echo "  export APPLE_ID=\"your.email@example.com\""
    echo ""
    exit 1
fi

if [ -z "$APPLE_ID_PASSWORD" ]; then
    echo "❌ ERROR: APPLE_ID_PASSWORD environment variable not set"
    echo ""
    echo "This must be an app-specific password, NOT your Apple ID password!"
    echo "Create one at: https://appleid.apple.com/ → Security → App-Specific Passwords"
    echo ""
    echo "Then set it:"
    echo "  export APPLE_ID_PASSWORD=\"xxxx-xxxx-xxxx-xxxx\""
    echo ""
    exit 1
fi

if [ -z "$APPLE_TEAM_ID" ]; then
    echo "❌ ERROR: APPLE_TEAM_ID environment variable not set"
    echo ""
    echo "Find your Team ID at: https://developer.apple.com/account/ → Membership"
    echo "Or from your certificate: security find-identity -v -p codesigning"
    echo ""
    echo "Then set it:"
    echo "  export APPLE_TEAM_ID=\"F3KSR2SF6L\""
    echo ""
    exit 1
fi

echo "✓ App found: $APP_PATH"
echo "✓ Apple ID: $APPLE_ID"
echo "✓ Team ID: $APPLE_TEAM_ID"
echo "✓ App-specific password: ****"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Creating ZIP Archive"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Remove old zip if exists
rm -f "$ZIP_PATH"

# Create zip for notarization
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
echo "✓ Created $ZIP_PATH"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Submitting to Apple Notary Service"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "This may take a few minutes..."
echo ""

# Submit for notarization and wait for result
xcrun notarytool submit "$ZIP_PATH" \
    --apple-id "$APPLE_ID" \
    --password "$APPLE_ID_PASSWORD" \
    --team-id "$APPLE_TEAM_ID" \
    --wait

# Check if notarization succeeded
NOTARIZATION_RESULT=$?

if [ $NOTARIZATION_RESULT -ne 0 ]; then
    echo ""
    echo "❌ Notarization failed!"
    echo ""
    echo "To see detailed logs, run:"
    echo "  xcrun notarytool log <submission-id> --apple-id \"$APPLE_ID\" --password \"$APPLE_ID_PASSWORD\" --team-id \"$APPLE_TEAM_ID\""
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Stapling Notarization Ticket"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Staple the notarization ticket to the app
xcrun stapler staple "$APP_PATH"

echo "✓ Notarization ticket stapled to app"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Verifying Notarization"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Verify the notarization
spctl --assess -vv "$APP_PATH"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Notarization Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Your app is now notarized and ready for distribution!"
echo "Location: $APP_PATH"
echo ""
echo "Next step: Create DMG for distribution"
echo "  ./tools/create_dmg.sh"
echo ""

# Clean up zip
rm -f "$ZIP_PATH"

