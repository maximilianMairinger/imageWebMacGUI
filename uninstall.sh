#!/bin/bash
# uninstall.sh — removes all Image Web Quick Actions and scripts from this Mac.

set -e

SCRIPTS_DEST="$HOME/.local/share/imageweb"
SERVICES_DIR="$HOME/Library/Services"

echo "=== Image Web Quick Actions — Uninstaller ==="
echo

rm -rf "$SERVICES_DIR/Convert with Image Web.workflow"
rm -rf "$SERVICES_DIR/Convert with Image Web Options.workflow"
echo "✓ Quick Actions removed"

rm -rf "$SCRIPTS_DEST"
echo "✓ Scripts removed"

defaults delete com.imageweb.prefs 2>/dev/null && echo "✓ Saved preferences cleared" || echo "  (no saved preferences)"

/System/Library/CoreServices/pbs -update 2>/dev/null || true
killall Finder 2>/dev/null || true
echo "✓ Services database refreshed (Finder restarted)"
echo
echo "Uninstall complete."
