#!/bin/bash
# Update all component versions from git tag or provided version
# Usage: ./tools/update_versions.sh [version]
#   If version not provided, extracts from latest git tag (v1.0.5 -> 1.0.5)

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Determine version
if [ -n "$1" ]; then
    VERSION="$1"
else
    # Get latest tag
    GIT_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v1.0.0")
    VERSION="${GIT_TAG#v}"  # Remove 'v' prefix
fi

echo "📦 Updating all components to version: $VERSION"
echo ""

# Update RadioformApp Info.plist
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

# Update RadioformDriver Info.plist
DRIVER_PLIST="$PROJECT_ROOT/packages/driver/Info.plist"
if [ -f "$DRIVER_PLIST" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$DRIVER_PLIST" 2>/dev/null || \
        /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $VERSION" "$DRIVER_PLIST"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$DRIVER_PLIST" 2>/dev/null || \
        /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $VERSION" "$DRIVER_PLIST"
    echo "✓ Updated packages/driver/Info.plist"
else
    echo "⚠️  Warning: $DRIVER_PLIST not found"
fi

# Update RadioformHost Info.plist
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

# Update driver CMakeLists.txt version
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

echo ""
echo "✅ All component versions updated to $VERSION"
echo ""
echo "Updated files:"
echo "  - apps/mac/RadioformApp/Info.plist"
echo "  - packages/driver/Info.plist"
echo "  - packages/host/Info.plist"
echo "  - packages/driver/CMakeLists.txt"
