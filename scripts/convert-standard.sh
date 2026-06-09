#!/bin/bash
# Convert selected image(s) using saved defaults.
# Input: image file paths as arguments ($@) or via stdin.

SCRIPT_DIR="$HOME/.local/share/imageweb"
BINARY=$(bash "$SCRIPT_DIR/find-image-web.sh")
ALGORITHMS=$(defaults read com.imageweb.prefs algorithms 2>/dev/null || echo "webp,avif")
RESOLUTIONS=$(defaults read com.imageweb.prefs resolutions 2>/dev/null || echo "FHD")

run_convert() {
    local file="$1"
    [[ -z "$file" ]] && return
    local ext="${file##*.}"
    case "${ext,,}" in
        png|jpg|jpeg|webp|avif|gif|tiff) ;;
        *) return ;;
    esac
    local outdir
    outdir="$(dirname "$file")"
    if [[ "$BINARY" == "npx" ]]; then
        npx image-web "$file" "$outdir" -a "$ALGORITHMS" -r "$RESOLUTIONS" --silent
    else
        "$BINARY" "$file" "$outdir" -a "$ALGORITHMS" -r "$RESOLUTIONS" --silent
    fi
}

if [[ $# -gt 0 ]]; then
    for f in "$@"; do run_convert "$f"; done
else
    while IFS= read -r f; do run_convert "$f"; done
fi
