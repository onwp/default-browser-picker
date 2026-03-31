# Default Browser Picker

A macOS menu bar utility that lets you switch your default browser in one click.

![macOS](https://img.shields.io/badge/macOS-14.0%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![License](https://img.shields.io/badge/license-Custom-blue)

## Why?

Changing your default browser on macOS means navigating to **System Settings > Desktop & Dock > Default web browser**. That's a buried setting that takes 4+ clicks and pulls you away from whatever you're doing.

Default Browser Picker puts this control in the menu bar. Click the icon, pick a browser, done.

## Features

- **Menu bar icon** shows your current default browser at a glance
- **One-click switching** to any installed browser from the dropdown
- **Smart ordering** with well-known browsers listed first, others separated below
- **Start on Login** toggle to keep it available after every reboot
- **Native macOS design** using standard AppKit menus with full Tahoe vibrancy
- **Lightweight**: zero CPU when idle, under 20 MB memory, no network access
- **Universal Binary** that runs natively on Apple Silicon and Intel

## Screenshot

<!-- TODO: Add screenshot -->

## Install

### Download

Download the latest `.dmg` from [Releases](../../releases), open it, and drag **Default Browser Picker** to your Applications folder.

### Homebrew

```bash
brew install --cask default-browser-picker
```

## Build from Source

### Requirements

- Xcode 15+ (or Xcode Command Line Tools)
- macOS 14 Sonoma or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

### Steps

```bash
git clone https://github.com/onwp/default-browser-picker.git
cd default-browser-picker
xcodegen generate
open DefaultBrowserPicker.xcodeproj
```

Build and run with **⌘R** in Xcode.

Or build from the command line:

```bash
xcodebuild -project DefaultBrowserPicker.xcodeproj -scheme DefaultBrowserPicker -configuration Release build
```

## How It Works

The app uses macOS Launch Services APIs to:

1. **Detect browsers** by querying all apps registered as HTTP/HTTPS URL handlers
2. **Read the current default** by checking which app is set as the default handler
3. **Set a new default** by calling the system API, which triggers macOS's built-in confirmation dialog

The menu bar icon dynamically updates to show whichever browser is currently set as the default. The browser list refreshes every time you open the menu, so newly installed browsers appear automatically.

No data is stored, no network calls are made, and the app consumes zero CPU when you're not interacting with it.

## Supported Browsers

Any browser registered as an HTTP/HTTPS handler on macOS is detected automatically. Well-known browsers appear first in the list:

Safari, Chrome, Firefox, Arc, Brave, Edge, Opera, Vivaldi, Orion, Zen

Other HTTP-capable apps appear in a separate section below.

## Requirements

- macOS 14 Sonoma or later
- Apple Silicon or Intel Mac

## License

Free for personal and non-commercial use. Commercial use requires a license. See [LICENSE](LICENSE) for details.
