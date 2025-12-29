#!/bin/bash
# Launch Radioform Menu Bar App
# The app will automatically start the host if needed

cd "$(dirname "$0")"

echo "🎵 Launching Radioform..."
echo ""

# Check if driver is installed
if [ ! -d "/Library/Audio/Plug-Ins/HAL/RadioformDriver.driver" ]; then
    echo "⚠️  Driver not installed!"
    echo ""
    echo "Please install the driver first:"
    echo "  cd packages/driver"
    echo "  sudo ./install.sh"
    echo ""
    exit 1
fi

# Always restart coreaudiod to ensure fresh state
# This fixes various audio routing and device initialization issues
echo "Restarting coreaudiod for clean audio state..."
sudo killall coreaudiod
sleep 3

# Verify driver loaded
PROXY_DEVICES=$(system_profiler SPAudioDataType 2>/dev/null | grep -c "Radioform" || echo "0")

if [ "$PROXY_DEVICES" -eq "0" ]; then
    echo "❌ No Radioform devices found!"
    echo "   The driver may not be installed correctly."
    echo ""
    echo "Try running: ./setup.sh"
    exit 1
else
    echo "✓ Driver loaded ($PROXY_DEVICES proxy device(s) found)"
    echo ""
fi

# Kill any existing instances
pkill -f RadioformHost 2>/dev/null
pkill -f RadioformApp 2>/dev/null

sleep 1

# Launch the menu bar app (it will auto-launch the host)
echo "Starting menu bar app..."
apps/mac/RadioformApp/.build/debug/RadioformApp

echo ""
echo "✓ Radioform stopped"
