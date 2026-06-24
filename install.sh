#!/bin/bash
# install.sh — sets up the Image Web Quick Actions on this Mac.
# Safe to re-run after any edits to scripts or workflows.

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

# When piped through bash (curl | bash), $0 is /dev/stdin and the repo files
# aren't on disk. Download the tarball and re-exec from there.
if [[ ! -d "$REPO_DIR/scripts" || ! -d "$REPO_DIR/workflows" ]]; then
    TMPDIR_DL=$(mktemp -d)
    echo "Downloading imageWebMacGUI..."
    curl -fsSL https://github.com/maximilianMairinger/imageWebMacGUI/archive/refs/heads/master.tar.gz \
        | tar xz -C "$TMPDIR_DL"
    trap "rm -rf '$TMPDIR_DL'" EXIT
    exec bash "$TMPDIR_DL/imageWebMacGUI-master/install.sh"
fi
SCRIPTS_DEST="$HOME/.local/share/imageweb"
SERVICES_DIR="$HOME/Library/Services"

echo "=== Image Web Quick Actions — Installer ==="
echo

# ── 1. Prerequisites ─────────────────────────────────────────────────────────

# Check for SwiftDialog
if ! command -v dialog &>/dev/null; then
    echo "SwiftDialog is not installed. Installing via Homebrew..."
    if ! command -v brew &>/dev/null; then
        echo "ERROR: Homebrew is not installed."
        echo "Install it first: https://brew.sh"
        exit 1
    fi
    brew install swiftdialog
fi
echo "✓ SwiftDialog found: $(command -v dialog)"

# Check for image-web (warn but don't block)
IMAGE_WEB_BINARY=$(bash "$REPO_DIR/scripts/find-image-web.sh")
if [[ "$IMAGE_WEB_BINARY" == "npx" ]]; then
    echo "⚠  image-web not found as a global binary — will fall back to npx."
    echo "   To install globally: npm install -g image-web"
else
    echo "✓ image-web found: $IMAGE_WEB_BINARY"
fi
echo

# ── 2. Install scripts ────────────────────────────────────────────────────────

mkdir -p "$SCRIPTS_DEST"
cp "$REPO_DIR/scripts/find-image-web.sh"  "$SCRIPTS_DEST/"
cp "$REPO_DIR/scripts/convert-standard.sh" "$SCRIPTS_DEST/"
cp "$REPO_DIR/scripts/convert-options.sh"  "$SCRIPTS_DEST/"
chmod +x "$SCRIPTS_DEST/"*.sh
echo "✓ Scripts installed to $SCRIPTS_DEST"

# ── 3. Install Quick Actions ──────────────────────────────────────────────────

mkdir -p "$SERVICES_DIR"

# Remove old versions (both old and new names) first
rm -rf "$SERVICES_DIR/Convert with Image Web.workflow"
rm -rf "$SERVICES_DIR/Convert with Image Web Options.workflow"
rm -rf "$SERVICES_DIR/Quick Compress with imageWeb.workflow"
rm -rf "$SERVICES_DIR/Compress with imageWeb.workflow"

cp -R "$REPO_DIR/workflows/Quick Compress with imageWeb.workflow" "$SERVICES_DIR/"
cp -R "$REPO_DIR/workflows/Compress with imageWeb.workflow"       "$SERVICES_DIR/"
echo "✓ Quick Actions installed to $SERVICES_DIR"

# ── 4. Register services ──────────────────────────────────────────────────────
# Rebuild the services database and restart Finder so changes take effect
# immediately without a logout. Safe to run on re-installs.
/System/Library/CoreServices/pbs -update 2>/dev/null || true
killall cfprefsd 2>/dev/null || true
killall Finder 2>/dev/null || true
echo "✓ Services database refreshed (Finder restarted)"
echo

# ── 5. Done ───────────────────────────────────────────────────────────────────

echo "════════════════════════════════════════════════"
echo "  Installation complete!"
echo "════════════════════════════════════════════════"
echo
echo "HOW TO USE:"
echo "  1. Right-click any image file in Finder"
echo "  2. Choose 'Quick Actions' from the menu"
echo "  3. Select 'imageWeb quick'  (uses saved defaults)"
echo "     or  'imageWeb modal'    (shows format/resolution picker)"
echo
echo "If Quick Actions don't appear:"
echo "  → System Settings → Privacy & Security → Extensions → Finder"
echo "  → Make sure both imageWeb actions are enabled"
echo
echo "To reset defaults:"
echo "  defaults delete com.imageweb.prefs"
echo
