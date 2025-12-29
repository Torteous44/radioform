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

# Kill any existing instances first
pkill -f RadioformHost 2>/dev/null
pkill -f RadioformApp 2>/dev/null
sleep 1

# Always restart coreaudiod to ensure fresh state
# This fixes various audio routing and device initialization issues
echo "Restarting coreaudiod for clean audio state..."
sudo killall coreaudiod
sleep 3

# Note: Radioform devices won't appear until the host starts and creates the control file
# The host will be started by the menu bar app, so we don't check for devices here

# Launch the menu bar app (it will auto-launch the host, which creates the control file)
echo "Starting menu bar app..."
echo "   (Radioform devices will appear once the host starts)"
echo ""

# Set environment variable so app can find the host executable
export RADIOFORM_ROOT="$(pwd)"

apps/mac/RadioformApp/.build/debug/RadioformApp

echo ""
echo "✓ Radioform stopped"
