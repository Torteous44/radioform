#!/bin/bash
# Check if Radioform driver is already loaded and functional

# Check if RadioformDriver devices are visible to the system
if system_profiler SPAudioDataType 2>/dev/null | grep -q "Radioform"; then
    echo "✓ Radioform driver is already loaded"
    exit 0
else
    echo "✗ Radioform driver not found"
    exit 1
fi
