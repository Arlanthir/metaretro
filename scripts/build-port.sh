#!/bin/bash
# Builds the Retro Town Story port: dist/ports/ (the launcher and ports/retrotownstory/, ready to
# copy to /userdata/roms/ports/) and dist/retrotownstory.zip (the same, for PortMaster to install).
# The port's art in port/ comes from scripts/port-art.sh.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
out="$root/dist/ports"
game="$out/retrotownstory"
rm -rf "$out" "$root/dist/retrotownstory.zip"
mkdir -p "$game/licenses"
cp "$root/port/Retro Town Story.sh" "$out/"
cp "$root/port/port.json" "$root/port/gameinfo.xml" "$root/port/README.md" \
  "$root/port/screenshot.png" "$root/port/cover.png" "$root/port/logo.png" "$game/"
cp "$root/src/assets/ninja-adventure/LICENSE.txt" "$game/licenses/NinjaAdventure-LICENSE.txt"
cp "$root/src/assets/fonts/ArkPixel-OFL.txt" "$game/licenses/"
(cd "$root/src" && zip -qr "$game/retrotownstory.love" .)
(cd "$out" && zip -qr "$root/dist/retrotownstory.zip" "Retro Town Story.sh" retrotownstory)
echo "Built $out and $root/dist/retrotownstory.zip"
