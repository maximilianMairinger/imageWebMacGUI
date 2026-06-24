# imageWeb — Finder Quick Actions

Right-click context menu integration for [image-web](https://github.com/your/image-web), a bulk image conversion CLI tool.

## What it adds

Two entries appear under **Quick Actions** when you right-click any image in Finder:

| Menu item | Behaviour |
|---|---|
| **Quick: Compress with imageWeb** | Converts immediately using your saved defaults |
| **Compress with imageWeb** | Opens a dialog to pick formats, resolutions, and output folder |

## Requirements

- macOS 12 or later
- [SwiftDialog](https://github.com/swiftDialog/swiftDialog) — the dialog UI engine
- [image-web](https://www.npmjs.com/package/image-web) — the conversion CLI

## Install

```bash
# 1. Install SwiftDialog (if not already installed)
brew install swiftdialog

# 2. Install image-web (if not already installed)
npm install -g image-web

# 3. Clone this repo and run the installer
git clone <repo-url>
cd imageWebMacGUI
bash install.sh
```

The installer copies the Quick Actions to `~/Library/Services/` and refreshes Finder automatically.

If the menu items don't appear after install:

> **System Settings → Privacy & Security → Extensions → Finder**
> Enable both imageWeb actions.

## Uninstall

```bash
bash uninstall.sh
```

Removes all Quick Actions, scripts, and saved preferences.

## Saved preferences

When you click **Compress** with *Save as Default* toggled on, your chosen formats and resolution are saved to `~/Library/Preferences/com.imageweb.prefs.plist` and used by all future conversions (including the quick action).

To reset to defaults:

```bash
defaults delete com.imageweb.prefs
```

## Supported image formats (input)

`png` `jpg` `jpeg` `webp` `avif` `gif` `tiff`
