#!/bin/bash
# Show a SwiftDialog popup to choose codecs and resolutions, then convert.
# Input: image file paths as arguments ($@) or via stdin.

# Clean up any stale temp files from previous crashes
rm -f /tmp/imageweb-dialog-*.json /tmp/imageweb-out-*.json

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

# Pre-populate Output field from the first passed file
FIRST_FILE="${1:-}"
INPUT_DIR=$(dirname "$FIRST_FILE")

# Locate SwiftDialog CLI binary
DIALOG_CMD=""
for p in "/usr/local/bin/dialog" "/opt/homebrew/bin/dialog"; do
    [[ -x "$p" ]] && DIALOG_CMD="$p" && break
done
if [[ -z "$DIALOG_CMD" ]]; then
    osascript -e 'display alert "imageWeb" message "SwiftDialog not installed.\nRun: brew install swiftdialog" as warning'
    exit 1
fi

# Find Dialog.app bundle (needed for pre-launch so dialogcli can XPC-connect)
DIALOG_APP=""
_real=$(readlink "$DIALOG_CMD" 2>/dev/null || echo "")
if [[ -n "$_real" ]]; then
    _app=$(echo "$_real" | grep -o '.*\.app')
    [[ -d "$_app" ]] && DIALOG_APP="$_app"
fi
if [[ -z "$DIALOG_APP" ]]; then
    for _p in "/Library/Application Support/Dialog/Dialog.app" \
              "/Applications/dialog.app" "/Applications/Dialog.app" \
              "/Applications/SwiftDialog.app" "$HOME/Applications/dialog.app"; do
        [[ -d "$_p" ]] && DIALOG_APP="$_p" && break
    done
fi
if [[ -z "$DIALOG_APP" ]]; then
    DIALOG_APP=$(mdfind "kMDItemCFBundleIdentifier == 'au.swiftdialog.dialog'" 2>/dev/null | grep -m1 '\.app$')
fi

# Build dialog JSON
TMPFILE=$(mktemp /tmp/imageweb-dialog-XXXXX.json)
cat > "$TMPFILE" << EOF
{
  "title": "Compress with imageWeb",
  "icon": "none",
  "button1text": "Compress",
  "button2text": "Cancel",
  "moveable": false,
  "width": 580,
  "height": 700,
  "windowbuttons": "close",
  "checkboxstyle": "switch",
  "vieworder": "textfield,checkbox",
  "textfield": [
    {
      "title": "Output folder",
      "value": "$INPUT_DIR"
    }
  ],
  "checkbox": [
    {"label": "**Formats**",                 "checked": false, "disabled": true},
    {"label": "avif — best compression",     "checked": $(checked "avif"  "$SAVED_ALGOS")},
    {"label": "webp — wide browser support", "checked": $(checked "webp"  "$SAVED_ALGOS")},
    {"label": "jpg — universal",             "checked": $(checked "jpg"   "$SAVED_ALGOS")},
    {"label": "png — lossless",              "checked": $(checked "png"   "$SAVED_ALGOS")},
    {"label": "tiff — archival",             "checked": $(checked "tiff"  "$SAVED_ALGOS")},
    {"label": "**Resolutions**",             "checked": false, "disabled": true},
    {"label": "LD — 240p",                   "checked": $(checked "LD"    "$SAVED_RESS")},
    {"label": "SD — 480p",                   "checked": $(checked "SD"    "$SAVED_RESS")},
    {"label": "FHD — 1080p",                 "checked": $(checked "FHD"   "$SAVED_RESS")},
    {"label": "QHD — 1440p",                 "checked": $(checked "QHD"   "$SAVED_RESS")},
    {"label": "UHD — 4K",                    "checked": $(checked "UHD"   "$SAVED_RESS")},
    {"label": "2UHD — 8K",                   "checked": $(checked "2UHD"  "$SAVED_RESS")},
    {"label": "───────────────────────────", "checked": false, "disabled": true},
    {"label": "Save as Default",             "checked": false},
    {"label": "Replace existing files",      "checked": false}
  ]
}
EOF

# SwiftDialog v3: dialogcli XPC-connects to Dialog.app.
# From Automator's shell context, dialogcli can't launch Dialog.app itself.
# Pre-launch Dialog.app via open so it starts in the GUI session first.
if [[ -n "$DIALOG_APP" ]] && ! pgrep -xq Dialog 2>/dev/null; then
    open -g "$DIALOG_APP" 2>/dev/null
    i=0
    while ! pgrep -xq Dialog 2>/dev/null && [[ $i -lt 30 ]]; do
        sleep 0.1
        ((i++))
    done
    sleep 0.3
fi

RESULT=$("$DIALOG_CMD" --jsonfile "$TMPFILE" --quitkey w 2>/tmp/imageweb-dialog-err.txt)
EXIT_CODE=$?
rm -f "$TMPFILE"

[[ $EXIT_CODE -eq 2 || $EXIT_CODE -eq 10 ]] && { rm -f /tmp/imageweb-dialog-err.txt; exit 0; }
[[ -z "$RESULT" ]] && { rm -f /tmp/imageweb-dialog-err.txt; exit 0; }

if [[ $EXIT_CODE -ne 0 ]]; then
    ERR=$(cat /tmp/imageweb-dialog-err.txt 2>/dev/null | head -3)
    rm -f /tmp/imageweb-dialog-err.txt
    osascript -e "display alert \"imageWeb: dialog failed (exit $EXIT_CODE)\" message \"$ERR\" as warning"
    exit 1
fi
rm -f /tmp/imageweb-dialog-err.txt

# Parse SwiftDialog output — format is:  key : value  or  "key" : "value"
PARSE_SCRIPT='
import sys

data = {}
for line in sys.stdin.read().strip().splitlines():
    if " : " not in line:
        continue
    key, _, value = line.partition(" : ")
    data[key.strip().strip("\"'"'"'")] = value.strip().strip("\"'"'"'")

algo_map = {
    "avif — best compression":     "avif",
    "webp — wide browser support": "webp",
    "jpg — universal":             "jpg",
    "png — lossless":              "png",
    "tiff — archival":             "tiff",
}
res_map = {
    "LD — 240p":   "LD",
    "SD — 480p":   "SD",
    "FHD — 1080p": "FHD",
    "QHD — 1440p": "QHD",
    "UHD — 4K":    "UHD",
    "2UHD — 8K":   "2UHD",
}

algos, ress, save, force = [], [], False, False
for key, value in data.items():
    if value == "true":
        if key in algo_map:
            algos.append(algo_map[key])
        elif key in res_map:
            ress.append(res_map[key])
        elif key == "Save as Default":
            save = True
        elif key == "Replace existing files":
            force = True

out_dir = data.get("Output folder", "")

print(",".join(algos) if algos else "webp")
print(",".join(ress) if ress else "QHD")
print("true" if save else "false")
print("true" if force else "false")
print(out_dir)
'

PARSED=$(echo "$RESULT" | python3 -c "$PARSE_SCRIPT")
ALGOS=$(echo "$PARSED"  | sed -n '1p')
RESS=$(echo "$PARSED"   | sed -n '2p')
SAVE=$(echo "$PARSED"   | sed -n '3p')
FORCE=$(echo "$PARSED"  | sed -n '4p')
OUTDIR=$(echo "$PARSED" | sed -n '5p')

[[ -z "$ALGOS" || -z "$RESS" ]] && exit 0

[[ "$SAVE" == "true" ]] && {
    defaults write com.imageweb.prefs algorithms "$ALGOS"
    defaults write com.imageweb.prefs resolutions "$RESS"
}

FORCE_FLAG=""
[[ "$FORCE" == "true" ]] && FORCE_FLAG="-f"

_do_convert() {
    local file="$1" outdir="$2" force="$3"
    local err code
    if [[ "$BINARY" == "npx" ]]; then
        err=$(npx image-web "$file" "$outdir" -a "$ALGOS" -r "$RESS" --silent $force 2>&1)
    else
        err=$("$BINARY" "$file" "$outdir" -a "$ALGOS" -r "$RESS" --silent $force 2>&1)
    fi
    code=$?
    [[ $code -ne 0 ]] && echo "$err"
    return $code
}

run_convert() {
    local file="$1"
    [[ -z "$file" ]] && return 0
    local ext
    ext=$(echo "${file##*.}" | tr '[:upper:]' '[:lower:]')
    case "$ext" in
        png|jpg|jpeg|webp|avif|gif|tiff) ;;
        *) return 0 ;;
    esac
    local outdir="${OUTDIR:-$(dirname "$file")}"
    local err
    err=$(_do_convert "$file" "$outdir" "$FORCE_FLAG")
    if [[ $? -ne 0 ]]; then
        if echo "$err" | grep -q "already exists"; then
            local ans
            ans=$(osascript -e 'display dialog "Output file already exists. Override?" buttons {"Cancel", "Override"} default button "Override" with icon caution' 2>/dev/null)
            if echo "$ans" | grep -q "Override"; then
                err=$(_do_convert "$file" "$outdir" "-f")
                if [[ $? -ne 0 ]]; then
                    local msg
                    msg=$(echo "$err" | grep "^Error:" | head -1)
                    osascript -e "display alert \"imageWeb\" message \"${msg:-Conversion failed}\" as warning"
                fi
            fi
        else
            local msg
            msg=$(echo "$err" | grep "^Error:" | head -1)
            osascript -e "display alert \"imageWeb\" message \"${msg:-Conversion failed}\" as warning"
        fi
    fi
}

if [[ $# -gt 0 ]]; then
    for f in "$@"; do run_convert "$f"; done
else
    while IFS= read -r f; do run_convert "$f"; done
fi
