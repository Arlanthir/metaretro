#!/bin/bash
# Draws the port's art for EmulationStation into port/: screenshot.png (gameplay in town), cover.png
# (box art) and logo.png (the name, on transparency). Runs a copy of src/ with scripts/port-art/driver.lua
# appended. LOVE overrides the love binary.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
love=${LOVE:-$( [ -x /Applications/love.app/Contents/MacOS/love ] && echo /Applications/love.app/Contents/MacOS/love || echo love )}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cp -R "$root/src/." "$work"
sed -i.orig 's/^local app = /app = /' "$work/main.lua"
cat "$root/scripts/port-art/driver.lua" >> "$work/main.lua"
PORT_ART_OUT="$root/port" "$love" "$work" --backend mock
