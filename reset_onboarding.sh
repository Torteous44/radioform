#!/bin/bash
# Convenience script to reset and test onboarding

echo "🔄 Resetting onboarding state..."

# Find the RadioformApp executable
if [ -f ".build/arm64-apple-macosx/debug/RadioformApp" ]; then
    EXEC=".build/arm64-apple-macosx/debug/RadioformApp"
elif [ -f ".build/x86_64-apple-macosx/debug/RadioformApp" ]; then
    EXEC=".build/x86_64-apple-macosx/debug/RadioformApp"
elif [ -f ".build/debug/RadioformApp" ]; then
    EXEC=".build/debug/RadioformApp"
else
    echo "❌ RadioformApp executable not found. Build it first with: swift build"
    exit 1
fi

# Kill any running instances
pkill -f "RadioformApp" 2>/dev/null

# Reset onboarding and launch
"$EXEC" --reset-onboarding

echo "✓ Onboarding reset complete. Next launch will show onboarding."
