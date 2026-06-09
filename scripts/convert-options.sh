#!/bin/bash
# Show a SwiftDialog popup to choose codecs and resolutions, then convert.
# Input: image file paths as arguments ($@) or via stdin.

SCRIPT_DIR="$HOME/.local/share/imageweb"
BINARY=$(bash "$SCRIPT_DIR/find-image-web.sh")

# Ensure node is in PATH (nvm installs are absent from Automator minimal env)
if [[ "$BINARY" != "npx" ]]; then
    export PATH="$(dirname "$BINARY"):$PATH"
fi

# Read saved defaults
SAVED_ALGOS=$(defaults read com.imageweb.prefs algorithms 2>/dev/null || echo "webp,avif")
SAVED_RESS=$(defaults read com.imageweb.prefs resolutions 2>/dev/null || echo "FHD")

# Returns "true" if $1 appears as a word in comma-separated list $2
checked() {
    echo "$2" | tr ',' '\n' | grep -qx "$1" && echo "true" || echo "false"
}

# Locate SwiftDialog
DIALOG_CMD=""
for p in "/usr/local/bin/dialog" "/opt/homebrew/bin/dialog"; do
    [[ -x "$p" ]] && DIALOG_CMD="$p" && break
done
if [[ -z "$DIALOG_CMD" ]]; then
    osascript -e 'display alert "Image Web" message "SwiftDialog not installed.\nRun: brew install swiftdialog" as warning'
    exit 1
fi

# Build dialog JSON
TMPFILE=$(mktemp /tmp/imageweb-dialog-XXXXX.json)
cat > "$TMPFILE" << EOF
{
  "title": "Convert with Image Web",
  "icon": "SF=photo.stack",
  "message": "Output files are saved to the same folder as the original.",
  "button1text": "Convert",
  "button2text": "Cancel",
  "moveable": true,
  "width": 520,
  "height": 700,
  "checkbox": [
    {"label": "Formats",                     "checked": false, "disabled": true},
    {"label": "avif — best compression",     "checked": $(checked "avif"  "$SAVED_ALGOS")},
    {"label": "webp — wide browser support", "checked": $(checked "webp"  "$SAVED_ALGOS")},
    {"label": "jpg — universal",             "checked": $(checked "jpg"   "$SAVED_ALGOS")},
    {"label": "png — lossless",              "checked": $(checked "png"   "$SAVED_ALGOS")},
    {"label": "tiff — archival",             "checked": $(checked "tiff"  "$SAVED_ALGOS")},
    {"label": "Resolutions",                 "checked": false, "disabled": true},
    {"label": "PREV — 15p thumbnail",        "checked": $(checked "PREV"  "$SAVED_RESS")},
    {"label": "LD — 240p",                   "checked": $(checked "LD"    "$SAVED_RESS")},
    {"label": "SD — 480p",                   "checked": $(checked "SD"    "$SAVED_RESS")},
    {"label": "HD — 720p",                   "checked": $(checked "HD"    "$SAVED_RESS")},
    {"label": "FHD — 1080p",                 "checked": $(checked "FHD"   "$SAVED_RESS")},
    {"label": "QHD — 1440p",                 "checked": $(checked "QHD"   "$SAVED_RESS")},
    {"label": "UHD — 4K",                    "checked": $(checked "UHD"   "$SAVED_RESS")},
    {"label": "2UHD — 8K",                   "checked": $(checked "2UHD"  "$SAVED_RESS")},
    {"label": "Options",                     "checked": false, "disabled": true},
    {"label": "Save as Default",             "checked": false}
  ]
}
EOF

RESULT=$("$DIALOG_CMD" --jsonfile "$TMPFILE" 2>/dev/null)
EXIT_CODE=$?
rm -f "$TMPFILE"

# Exit code 2 = Cancel
[[ $EXIT_CODE -eq 2 || $EXIT_CODE -eq 10 ]] && exit 0

# Parse JSON: map labels back to identifiers
PARSE_SCRIPT='
import sys, json

data = json.load(sys.stdin)

algo_map = {
    "avif — best compression":     "avif",
    "webp — wide browser support": "webp",
    "jpg — universal":             "jpg",
    "png — lossless":              "png",
    "tiff — archival":             "tiff",
}
res_map = {
    "PREV — 15p thumbnail": "PREV",
    "LD — 240p":            "LD",
    "SD — 480p":            "SD",
    "HD — 720p":            "HD",
    "FHD — 1080p":          "FHD",
    "QHD — 1440p":          "QHD",
    "UHD — 4K":             "UHD",
    "2UHD — 8K":            "2UHD",
}

algos, ress, save = [], [], False
for val in data.values():
    if not isinstance(val, dict) or not val.get("checked"):
        continue
    label = val.get("label", "")
    if label in algo_map:
        algos.append(algo_map[label])
    elif label in res_map:
        ress.append(res_map[label])
    elif label == "Save as Default":
        save = True

print(",".join(algos) if algos else "webp")
print(",".join(ress) if ress else "FHD")
print("true" if save else "false")
'

PARSED=$(echo "$RESULT" | python3 -c "$PARSE_SCRIPT" 2>/dev/null)
ALGOS=$(echo "$PARSED" | sed -n '1p')
RESS=$(echo "$PARSED"  | sed -n '2p')
SAVE=$(echo "$PARSED"  | sed -n '3p')

[[ -z "$ALGOS" || -z "$RESS" ]] && exit 0

[[ "$SAVE" == "true" ]] && {
    defaults write com.imageweb.prefs algorithms "$ALGOS"
    defaults write com.imageweb.prefs resolutions "$RESS"
}

run_convert() {
    local file="$1"
    [[ -z "$file" ]] && return
    local ext
    ext=$(echo "${file##*.}" | tr '[:upper:]' '[:lower:]')
    case "$ext" in
        png|jpg|jpeg|webp|avif|gif|tiff) ;;
        *) return ;;
    esac
    local outdir
    outdir="$(dirname "$file")"
    if [[ "$BINARY" == "npx" ]]; then
        npx image-web "$file" "$outdir" -a "$ALGOS" -r "$RESS" --silent
    else
        "$BINARY" "$file" "$outdir" -a "$ALGOS" -r "$RESS" --silent
    fi
}

if [[ $# -gt 0 ]]; then
    for f in "$@"; do run_convert "$f"; done
else
    while IFS= read -r f; do run_convert "$f"; done
fi
