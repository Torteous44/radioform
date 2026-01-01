#!/bin/bash
# Uninstall Radioform driver (for testing)

echo "  Uninstalling Radioform driver..."

osascript -e 'do shell script "rm -rf /Library/Audio/Plug-Ins/HAL/RadioformDriver.driver && killall coreaudiod" with administrator privileges'

if [ $? -eq 0 ]; then
    echo "✓ Driver uninstalled successfully"
    echo "✓ Audio system restarted"
else
    echo "❌ Failed to uninstall driver"
    exit 1
fi

echo ""
echo "Driver removed. Audio system will restart momentarily."
