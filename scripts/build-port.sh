#!/bin/bash
# Builds dist/ports/ with Metaretro.sh and metaretro/metaretro.love, ready to copy to /userdata/roms/ports/.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
out="$root/dist/ports"
rm -rf "$out"
mkdir -p "$out/metaretro"
cp "$root/port/Metaretro.sh" "$out/"
(cd "$root/src" && zip -qr "$out/metaretro/metaretro.love" .)
echo "Built $out"
