#!/bin/bash
# Update component versions
# Usage:
#   ./tools/update_versions.sh [version] [--app-only|--driver-only|--host-only]
#   If version not provided, extracts from latest git tag (v1.0.5 -> 1.0.5)
#   Without flags, updates all components

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Parse arguments
VERSION=""
UPDATE_APP=true
UPDATE_DRIVER=true
UPDATE_HOST=true

for arg in "$@"; do
    case $arg in
        --app-only)
            UPDATE_DRIVER=false
            UPDATE_HOST=false
            ;;
        --driver-only)
            UPDATE_APP=false
            UPDATE_HOST=false
            ;;
        --host-only)
            UPDATE_APP=false
            UPDATE_DRIVER=false
            ;;
        *)
            if [ -z "$VERSION" ]; then
                VERSION="$arg"
            fi
            ;;
    esac
done

# Determine version if not provided
if [ -z "$VERSION" ]; then
    # Get latest tag
    GIT_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v1.0.0")
    VERSION="${GIT_TAG#v}"  # Remove 'v' prefix
fi

echo "📦 Updating component versions to: $VERSION"
echo ""

# Update RadioformApp Info.plist
if [ "$UPDATE_APP" = true ]; then
    APP_PLIST="$PROJECT_ROOT/apps/mac/RadioformApp/Info.plist"
    if [ -f "$APP_PLIST" ]; then
        /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP_PLIST" 2>/dev/null || \
            /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $VERSION" "$APP_PLIST"
        /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP_PLIST" 2>/dev/null || \
            /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $VERSION" "$APP_PLIST"
        echo "✓ Updated apps/mac/RadioformApp/Info.plist"
    else
        echo "⚠️  Warning: $APP_PLIST not found"
    fi
fi

# Update RadioformDriver Info.plist and VERSION file
if [ "$UPDATE_DRIVER" = true ]; then
    DRIVER_PLIST="$PROJECT_ROOT/packages/driver/Info.plist"
    if [ -f "$DRIVER_PLIST" ]; then
        /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$DRIVER_PLIST" 2>/dev/null || \
            /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $VERSION" "$DRIVER_PLIST"
        /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$DRIVER_PLIST" 2>/dev/null || \
            /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $VERSION" "$DRIVER_PLIST"
        echo "✓ Updated packages/driver/Info.plist"

        # Update VERSION file
        echo "$VERSION" > "$PROJECT_ROOT/packages/driver/VERSION"
        echo "✓ Updated packages/driver/VERSION"
    else
        echo "⚠️  Warning: $DRIVER_PLIST not found"
    fi
fi

# Update RadioformHost Info.plist
if [ "$UPDATE_HOST" = true ]; then
    HOST_PLIST="$PROJECT_ROOT/packages/host/Info.plist"
    if [ -f "$HOST_PLIST" ]; then
        /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$HOST_PLIST" 2>/dev/null || \
            /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $VERSION" "$HOST_PLIST"
        /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$HOST_PLIST" 2>/dev/null || \
            /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $VERSION" "$HOST_PLIST"
        echo "✓ Updated packages/host/Info.plist"
    else
        echo "⚠️  Warning: $HOST_PLIST not found (will be created next)"
    fi
fi

# Update driver CMakeLists.txt version
if [ "$UPDATE_DRIVER" = true ]; then
    DRIVER_CMAKE="$PROJECT_ROOT/packages/driver/CMakeLists.txt"
    if [ -f "$DRIVER_CMAKE" ]; then
        # Use sed to replace the version in project() line
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS sed requires -i with extension or '' and different regex syntax
            sed -i '' "s/project(RadioformDriver VERSION [0-9.]*/project(RadioformDriver VERSION $VERSION/" "$DRIVER_CMAKE"
        else
            sed -i "s/project(RadioformDriver VERSION [0-9.]\+/project(RadioformDriver VERSION $VERSION/" "$DRIVER_CMAKE"
        fi
        echo "✓ Updated packages/driver/CMakeLists.txt"
    else
        echo "⚠️  Warning: $DRIVER_CMAKE not found"
    fi
fi

echo ""
echo "✅ Version update complete"
echo ""
echo "Updated components:"
if [ "$UPDATE_APP" = true ]; then
    echo "  - App: $VERSION (apps/mac/RadioformApp/Info.plist)"
fi
if [ "$UPDATE_DRIVER" = true ]; then
    echo "  - Driver: $VERSION (packages/driver/Info.plist, CMakeLists.txt, VERSION)"
fi
if [ "$UPDATE_HOST" = true ]; then
    echo "  - Host: $VERSION (packages/host/Info.plist)"
fi
