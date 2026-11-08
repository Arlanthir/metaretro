#!/bin/bash
# Builds the Retro Town Story port: dist/ports/ (the launcher and ports/retrotownstory/, ready to
# copy to /userdata/roms/ports/) and dist/retrotownstory-<version>.zip (the same, for PortMaster to
# install), with the version from src/core/version.lua.
# The port's art in port/ comes from scripts/port-art.sh.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
out="$root/dist/ports"
game="$out/retrotownstory"
version=$(sed -n 's/^return "\(.*\)"$/\1/p' "$root/src/core/version.lua")
[ -n "$version" ] || { echo "No version in src/core/version.lua" >&2; exit 1; }
zip="$root/dist/retrotownstory-$version.zip"
rm -rf "$out" "$root"/dist/retrotownstory*.zip
mkdir -p "$game/licenses"
cp "$root/port/Retro Town Story.sh" "$out/"
cp "$root/port/port.json" "$root/port/gameinfo.xml" "$root/port/README.md" \
  "$root/port/screenshot.png" "$root/port/cover.png" "$root/port/logo.png" "$game/"
cp "$root/src/assets/ninja-adventure/LICENSE.txt" "$game/licenses/NinjaAdventure-LICENSE.txt"
cp "$root/src/assets/fonts/ArkPixel-OFL.txt" "$game/licenses/"
(cd "$root/src" && zip -qr "$game/retrotownstory.love" .)
(cd "$out" && zip -qr "$zip" "Retro Town Story.sh" retrotownstory)
echo "Built $out and $zip"
