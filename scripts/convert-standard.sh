#!/bin/bash
# Convert selected image(s) using saved defaults.
# Input: image file paths as arguments ($@) or via stdin.

SCRIPT_DIR="$HOME/.local/share/imageweb"
BINARY=$(bash "$SCRIPT_DIR/find-image-web.sh")

# Ensure node is in PATH (nvm installs don't appear in Automator's minimal env)
if [[ "$BINARY" != "npx" ]]; then
    export PATH="$(dirname "$BINARY"):$PATH"
fi

ALGORITHMS=$(defaults read com.imageweb.prefs algorithms 2>/dev/null || echo "webp")
RESOLUTIONS=$(defaults read com.imageweb.prefs resolutions 2>/dev/null || echo "QHD")

run_convert() {
    local file="$1"
    local force_flag="${2:-}"
    [[ -z "$file" ]] && return 0
    local ext
    ext=$(echo "${file##*.}" | tr '[:upper:]' '[:lower:]')
    case "$ext" in
        png|jpg|jpeg|webp|avif|gif|tiff) ;;
        *) return 0 ;;
    esac
    local outdir
    outdir="$(dirname "$file")"
    local err
    if [[ "$BINARY" == "npx" ]]; then
        err=$(npx image-web "$file" "$outdir" -a "$ALGORITHMS" -r "$RESOLUTIONS" --silent $force_flag 2>&1)
    else
        err=$("$BINARY" "$file" "$outdir" -a "$ALGORITHMS" -r "$RESOLUTIONS" --silent $force_flag 2>&1)
    fi
    local code=$?
    [[ $code -ne 0 ]] && echo "$err"
    return $code
}

# Collect files
FILES=()
if [[ $# -gt 0 ]]; then
    FILES=("$@")
else
    while IFS= read -r f; do FILES+=("$f"); done
fi

# First pass — no force
FAILED_OUTPUT=""
for f in "${FILES[@]}"; do
    OUT=$(run_convert "$f")
    if [[ $? -ne 0 ]]; then
        FAILED_OUTPUT="$OUT"
    fi
done

[[ -z "$FAILED_OUTPUT" ]] && exit 0

# Check if failure is due to existing output files
if echo "$FAILED_OUTPUT" | grep -q "already exists"; then
    ANSWER=$(osascript -e 'display dialog "Some output files already exist. Override them?" buttons {"Cancel", "Override"} default button "Override" with icon caution' 2>/dev/null)
    if echo "$ANSWER" | grep -q "Override"; then
        for f in "${FILES[@]}"; do run_convert "$f" "-f"; done
    fi
else
    MSG=$(echo "$FAILED_OUTPUT" | head -5)
    osascript -e "display alert \"imageWeb error\" message \"$MSG\" as warning"
fi
