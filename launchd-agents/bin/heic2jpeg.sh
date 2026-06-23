#!/usr/bin/env bash
#
# heic2jpeg — convert HEIC files dropped into ~/Downloads to JPEG.
#
# Fired by org.zmievski.heic2jpeg via launchd WatchPaths on ~/Downloads.
# Converts each *.heic to JPEG (EXIF preserved by sips) into the AirDrop
# folder, then removes the source HEIC ONLY on a successful conversion.

set -euo pipefail

src="$HOME/Downloads"
dest="$HOME/Downloads/AirDrop"

mkdir -p "$dest"

# nullglob: no matches -> loop body skipped (not a literal "*.heic").
# nocaseglob: also match .HEIC / .Heic.
shopt -s nullglob nocaseglob

for f in "$src"/*.heic; do
    base="$(basename "$f")"
    out="$dest/${base%.*}.jpg"

    # Collision: append an epoch suffix before the extension.
    if [[ -e "$out" ]]; then
        out="$dest/${base%.*}-$(date +%s).jpg"
    fi

    # sips preserves EXIF — keep it this way. Delete source only on success.
    if sips -s format jpeg -s formatOptions best "$f" --out "$out"; then
        rm "$f"
        echo "converted: $base -> $out"
    else
        echo "FAILED, source kept: $base" >&2
    fi
done
