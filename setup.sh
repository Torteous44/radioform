#!/bin/bash
# One-time setup for Radioform development

cd "$(dirname "$0")"

echo "🔧 Radioform Development Setup"
echo "=============================="
echo ""

# Build DSP library
echo "1. Building DSP library..."
cd packages/dsp/build
cmake .. -DCMAKE_BUILD_TYPE=Release
make
cd ../../..
echo "   ✓ DSP library built"
echo ""

# Build driver
echo "2. Building HAL driver..."
cd packages/driver
if [ -d "build" ]; then
    rm -rf build
fi
mkdir -p build
cd build
cmake ..
make
cd ../../..
echo "   ✓ Driver built"
echo ""

# Install driver (requires sudo)
echo "3. Installing driver (requires sudo)..."
sudo cp -r packages/driver/build/RadioformDriver.driver /Library/Audio/Plug-Ins/HAL/
sudo chmod -R 755 /Library/Audio/Plug-Ins/HAL/RadioformDriver.driver
echo "   ✓ Driver installed"
echo ""

# Restart coreaudiod to load driver
echo "4. Restarting coreaudiod..."
sudo killall coreaudiod
sleep 2
echo "   ✓ Audio daemon restarted"
echo ""

# Build host
echo "5. Building audio host..."
cd packages/host
swift build -c release
cd ../..
echo "   ✓ Host built"
echo ""

# Build menu bar app
echo "6. Building menu bar app..."
cd apps/mac/RadioformApp
swift build
cd ../../..
echo "   ✓ Menu bar app built"
echo ""

echo "✅ Setup complete!"
echo ""
echo "To launch Radioform, run:"
echo "  ./launch.sh"
echo ""
