#!/bin/bash
echo "Testing preset switching..."

for preset in BassBoost VocalEnhance TrebleBoost Flat Jazz Rock; do
    echo "→ Applying $preset..."
    preset_dir="$HOME/Library/Application Support/Radioform"
    mkdir -p "$preset_dir"
    cat "Sources/Resources/Presets/${preset}.json" > "$preset_dir/preset.json"
    sleep 1.5
done

echo "✓ Test complete! Check the 'Now Playing' in menu bar UI"
