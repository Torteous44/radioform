#!/bin/bash
# Radioform HAL Driver Installation Script

set -e

DRIVER_PATH="./build/RadioformDriver.driver"
INSTALL_PATH="/Library/Audio/Plug-Ins/HAL/RadioformDriver.driver"

echo "Radioform HAL Driver Installer"
echo "=============================="

# Check if driver was built
if [ ! -d "$DRIVER_PATH" ]; then
    echo "Error: Driver not found at $DRIVER_PATH"
    echo "Please build the driver first: cd build && cmake --build ."
    exit 1
fi

# Check if already installed
if [ -d "$INSTALL_PATH" ]; then
    echo "Driver already installed at $INSTALL_PATH"
    echo "Uninstalling old version first..."
    sudo rm -rf "$INSTALL_PATH"
fi

# Install driver
echo "Installing driver to $INSTALL_PATH..."
sudo cp -R "$DRIVER_PATH" "$INSTALL_PATH"
sudo chown -R root:wheel "$INSTALL_PATH"

echo ""
echo "Driver installed successfully!"
echo ""
echo "IMPORTANT: You must restart coreaudiod for changes to take effect:"
echo "  sudo killall coreaudiod"
echo ""
echo "WARNING: This will interrupt all audio playback (~2 seconds)."
echo "Make sure Radioform is NOT selected as the default output device before restarting."
