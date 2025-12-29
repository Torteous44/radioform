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

# Kill existing instances
echo "Stopping existing Radioform processes..."
pkill -f RadioformApp 2>/dev/null
pkill -f RadioformHost 2>/dev/null
sleep 1

# Save old control file to detect changes
CONTROL_FILE="/tmp/radioform-devices.txt"
OLD_DEVICES=""
if [ -f "$CONTROL_FILE" ]; then
    OLD_DEVICES=$(cat "$CONTROL_FILE")
fi

# Start RadioformHost first so it writes the control file
echo "Starting RadioformHost..."
packages/host/.build/arm64-apple-macosx/release/RadioformHost &
sleep 1.5

# Check if device list changed
NEW_DEVICES=$(cat "$CONTROL_FILE" 2>/dev/null || echo "")

if [ "$OLD_DEVICES" != "$NEW_DEVICES" ] || [ -z "$OLD_DEVICES" ]; then
    echo "Device list changed, activating audio devices (requires password)..."
    sudo killall coreaudiod
    sleep 2
    echo "✓ Audio devices activated"
else
    echo "✓ Device list unchanged, skipping coreaudiod restart"
    echo "   (Your music will continue playing!)"
fi
echo ""

# Launch the menu bar app
echo "Starting menu bar app..."
echo ""

# Set environment variable so app can find the host executable
export RADIOFORM_ROOT="$(pwd)"

apps/mac/RadioformApp/.build/debug/RadioformApp

echo ""
echo "✓ Radioform stopped"
