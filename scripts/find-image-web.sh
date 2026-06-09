#!/bin/bash
# Outputs the path to the image-web binary, or "npx" as fallback.
# Handles nvm installations by scanning ~/.nvm/versions/node directly
# rather than relying on PATH (which is minimal in background processes).

for p in \
    "/usr/local/bin/image-web" \
    "/opt/homebrew/bin/image-web" \
    "$HOME/.npm-global/bin/image-web" \
    "$HOME/.local/bin/image-web" \
    "/usr/bin/image-web"; do
    [[ -x "$p" ]] && echo "$p" && exit 0
done

# Scan nvm node versions, newest first
if [[ -d "$HOME/.nvm/versions/node" ]]; then
    while IFS= read -r version_dir; do
        candidate="$version_dir/bin/image-web"
        [[ -x "$candidate" ]] && echo "$candidate" && exit 0
    done < <(ls -d "$HOME/.nvm/versions/node/"* 2>/dev/null | sort -rV)
fi

echo "npx"
