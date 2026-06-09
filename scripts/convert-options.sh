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
SAVED_ALGOS=$(defaults read com.imageweb.prefs algorithms 2>/dev/null || echo "webp")
SAVED_RESS=$(defaults read com.imageweb.prefs resolutions 2>/dev/null || echo "QHD")

# Returns "true" if $1 appears as a word in comma-separated list $2
checked() {
    echo "$2" | tr ',' '\n' | grep -qx "$1" && echo "true" || echo "false"
}

# Locate SwiftDialog CLI binary
DIALOG_CMD=""
for p in "/usr/local/bin/dialog" "/opt/homebrew/bin/dialog"; do
    [[ -x "$p" ]] && DIALOG_CMD="$p" && break
done
if [[ -z "$DIALOG_CMD" ]]; then
    osascript -e 'display alert "Image Web" message "SwiftDialog not installed.\nRun: brew install swiftdialog" as warning'
    exit 1
fi

# Find Dialog.app bundle — needed so `open` launches it via LaunchServices
# (running the bare binary from Automator's background context exits with code 5:
#  no window server access; `open` fixes this by going through the GUI session)
DIALOG_APP=""
# First: resolve the symlink from the CLI binary to find the .app bundle
_real=$(readlink "$DIALOG_CMD" 2>/dev/null || echo "")
if [[ -n "$_real" ]]; then
    _app=$(echo "$_real" | grep -o '.*\.app')
    [[ -d "$_app" ]] && DIALOG_APP="$_app"
fi
# Fallback: common install locations
if [[ -z "$DIALOG_APP" ]]; then
    for _p in "/Library/Application Support/Dialog/Dialog.app" \
              "/Applications/dialog.app" "/Applications/Dialog.app" \
              "/Applications/SwiftDialog.app" "$HOME/Applications/dialog.app"; do
        [[ -d "$_p" ]] && DIALOG_APP="$_p" && break
    done
fi
# Last resort: Spotlight
if [[ -z "$DIALOG_APP" ]]; then
    DIALOG_APP=$(mdfind "kMDItemCFBundleIdentifier == 'au.swiftdialog.dialog'" 2>/dev/null | grep -m1 '\.app$')
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

OUTFILE=$(mktemp /tmp/imageweb-out-XXXXX.json)

if [[ -n "$DIALOG_APP" ]]; then
    # Launch via open so macOS gives it a proper GUI/window-server session
    open -Wn "$DIALOG_APP" --args \
        --jsonfile "$TMPFILE" --jsonoutputfile "$OUTFILE" \
        2>/tmp/imageweb-dialog-err.txt
    EXIT_CODE=$?
else
    # Fallback: direct binary (may fail with exit 5 if window server unavailable)
    "$DIALOG_CMD" --jsonfile "$TMPFILE" --jsonoutputfile "$OUTFILE" \
        2>/tmp/imageweb-dialog-err.txt
    EXIT_CODE=$?
fi
rm -f "$TMPFILE"

RESULT=$(cat "$OUTFILE" 2>/dev/null)
rm -f "$OUTFILE"

# Exit code 2/10 = Cancel / Esc
[[ $EXIT_CODE -eq 2 || $EXIT_CODE -eq 10 ]] && { rm -f /tmp/imageweb-dialog-err.txt; exit 0; }

# Guard: empty result also means cancel/close
[[ -z "$RESULT" ]] && { rm -f /tmp/imageweb-dialog-err.txt; exit 0; }

# Any other non-zero exit = SwiftDialog failed — surface the error
if [[ $EXIT_CODE -ne 0 ]]; then
    ERR=$(cat /tmp/imageweb-dialog-err.txt 2>/dev/null | head -3)
    rm -f /tmp/imageweb-dialog-err.txt
    osascript -e "display alert \"Image Web: dialog failed (exit $EXIT_CODE)\" message \"$ERR\" as warning"
    exit 1
fi
rm -f /tmp/imageweb-dialog-err.txt

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

PARSED=$(echo "$RESULT" | python3 -c "$PARSE_SCRIPT")
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
