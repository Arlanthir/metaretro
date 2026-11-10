#!/bin/sh
# Refreshes src/assets/gotx/winners.tsv, the GotX winners the game ships with (it downloads newer
# ones itself, weekly). Takes the GotX Randomizer's database (github.com/blakekl/gotx-randomizer,
# MIT), keeps only the winners (src/assets/gotx/winners.sql) and deletes the database.
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
url="https://raw.githubusercontent.com/blakekl/gotx-randomizer/main/src/gotx-randomizer.sqlite"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
curl -sfL --max-time 120 -o "$work/gotx.sqlite" "$url"
sqlite3 -readonly -separator "$(printf '\t')" "$work/gotx.sqlite" < "$root/src/assets/gotx/winners.sql" \
  > "$work/winners.tsv"
mv "$work/winners.tsv" "$root/src/assets/gotx/winners.tsv"
echo "$(wc -l < "$root/src/assets/gotx/winners.tsv") winners, latest $(cut -f2 "$root/src/assets/gotx/winners.tsv" | sort | tail -1)"
