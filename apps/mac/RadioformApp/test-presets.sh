#!/usr/bin/env bash
set -euo pipefail

echo "Testing bundled preset switching..."

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
preset_src_dir="${script_dir}/Sources/Resources/Presets"
preset_dest_dir="${HOME}/Library/Application Support/Radioform"
preset_dest_file="${preset_dest_dir}/preset.json"

mkdir -p "${preset_dest_dir}"

presets=(
  "Acoustic"
  "Classical"
  "Electronic"
  "Flat"
  "Hip-Hop"
  "Pop"
  "R&B"
  "Rock"
)

for preset in "${presets[@]}"; do
  src="${preset_src_dir}/${preset}.json"
  if [[ ! -f "${src}" ]]; then
    echo "Missing preset file: ${src}" >&2
    exit 1
  fi

  echo "Applying ${preset}..."
  cp "${src}" "${preset_dest_file}"
  sleep 1.5
done

echo "Preset switch test complete."
