#!/bin/bash
echo "Testing preset switching..."

for preset in BassBoost VocalEnhance TrebleBoost Flat Jazz Rock; do
    echo "→ Applying $preset..."
    cat "Sources/Resources/Presets/${preset}.json" > /tmp/radioform-preset.json
    sleep 1.5
done

echo "✓ Test complete! Check the 'Now Playing' in menu bar UI"
