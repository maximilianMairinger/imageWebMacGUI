# imageWeb — Finder Quick Actions

Right-click context menu integration for [image-web](https://www.npmjs.com/package/image-web), a bulk image conversion and optimisation CLI.

Adds two entries under **Quick Actions** when you right-click any image in Finder:

| Action | Behaviour |
|---|---|
| **imageWeb quick** | Converts immediately using your saved defaults |
| **imageWeb modal** | Opens a dialog to pick formats, resolutions, and output folder |

![macOS Finder Quick Actions menu showing imageWeb quick and imageWeb modal]()

## Requirements

- macOS 12 or later
- [SwiftDialog](https://github.com/swiftDialog/swiftDialog) — dialog UI engine
- [image-web](https://www.npmjs.com/package/image-web) — conversion CLI


## Install

**via Homebrew (recommended):**
```bash
brew tap maximilianMairinger/imageweb
brew install imageweb-macos
imageweb-setup
```

Homebrew handles [SwiftDialog](https://github.com/swiftDialog/swiftDialog) and [image-web](https://www.npmjs.com/package/image-web) automatically.

**via curl:**
```bash
brew install swiftdialog
npm install -g image-web
curl -fsSL https://raw.githubusercontent.com/maximilianMairinger/imageWebMacGUI/master/install.sh | bash
```

The installer copies the Quick Actions to `~/Library/Services/` and refreshes Finder automatically.

> **Quick Actions not showing up?**
> System Settings → Privacy & Security → Extensions → Finder → enable both imageWeb actions.

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/maximilianMairinger/imageWebMacGUI/master/uninstall.sh | bash
```

## Usage

### imageWeb quick

Right-click any image → Quick Actions → **imageWeb quick**.

Converts immediately to your saved formats and resolution. Output lands next to the source file.

### imageWeb modal

Right-click any image → Quick Actions → **imageWeb modal**.

Opens a dialog where you can choose:

- **Output folder** — defaults to the source file's folder, editable
- **Formats** — avif, webp, jpg, png, tiff (pick any combination)
- **Resolutions** — LD 240p through 2UHD 8K
- **Save as Default** — saves your current selection for future quick actions
- **Replace existing files** — overrides output files that already exist

## Defaults

Saved defaults are stored in `~/Library/Preferences/com.imageweb.prefs.plist` (standard macOS user preferences, machine-local).

Check current defaults:
```bash
defaults read com.imageweb.prefs
```

Reset to built-in defaults (webp, QHD):
```bash
defaults delete com.imageweb.prefs
```

## Supported input formats

`png` `jpg` `jpeg` `webp` `avif` `gif` `tiff`
