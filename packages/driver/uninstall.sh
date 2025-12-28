#!/bin/bash
# Radioform HAL Driver Uninstallation Script

set -e

INSTALL_PATH="/Library/Audio/Plug-Ins/HAL/RadioformDriver.driver"

echo "Radioform HAL Driver Uninstaller"
echo "================================"

# Check if installed
if [ ! -d "$INSTALL_PATH" ]; then
    echo "Driver not found at $INSTALL_PATH"
    echo "Nothing to uninstall."
    exit 0
fi

# Uninstall driver
echo "Removing driver from $INSTALL_PATH..."
sudo rm -rf "$INSTALL_PATH"

echo ""
echo "Driver uninstalled successfully!"
echo ""
echo "IMPORTANT: You must restart coreaudiod for changes to take effect:"
echo "  sudo killall coreaudiod"
echo ""
echo "WARNING: This will interrupt all audio playback (~2 seconds)."
