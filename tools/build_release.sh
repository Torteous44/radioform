#!/bin/bash
# Master build script for Radioform release builds
# Builds all components and creates distribution-ready .app bundle

set -e  # Exit on error

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Building Radioform Release"
echo "================================"
echo ""

# Function to print section headers
section() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# 1. Build DSP Library
section "1/5 Building DSP Library (C++)"
cd "$PROJECT_ROOT/packages/dsp"
mkdir -p build
cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
cmake --build . --config Release
echo "✓ DSP library built"

# 2. Build HAL Driver
section "2/5 Building HAL Driver (C++)"
cd "$PROJECT_ROOT/packages/driver"
mkdir -p build
cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
cmake --build . --config Release
echo "✓ HAL driver built"

# 3. Build Audio Host
section "3/5 Building Audio Host (Swift)"
cd "$PROJECT_ROOT/packages/host"
swift build -c release
echo "✓ Audio host built"

# 4. Build Menu Bar App
section "4/5 Building Menu Bar App (Swift)"
cd "$PROJECT_ROOT/apps/mac/RadioformApp"
swift build -c release
echo "✓ Menu bar app built"

# 5. Create .app Bundle
section "5/5 Creating .app Bundle"
cd "$PROJECT_ROOT"
"$SCRIPT_DIR/create_app_bundle.sh"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Build Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "App bundle: $PROJECT_ROOT/dist/Radioform.app"
echo ""
echo "To test the app:"
echo "  open dist/Radioform.app"
echo ""
echo "To create a DMG:"
echo "  tools/create_dmg.sh"
echo ""
