# Clippy

A lightweight clipboard history manager for macOS. Lives in your menu bar, stores everything you copy, and lets you paste any previous item with a quick keyboard shortcut.

![Clipboard History Panel](assets/clippy.png)

## Installation

### Download

1. Go to the [latest release](https://github.com/miiik4/Clippy/releases/latest)
2. Download the `.zip` file
3. Extract it to get the `.dmg` file
4. Open the `.dmg` and drag **Clippy** to your Applications folder
5. On first launch, macOS may warn about an unidentified developer — right-click the app and choose **Open** to bypass Gatekeeper

### Build from source

If you want to verify the code or make your own changes:

1. Clone the repo:
   ```
   git clone https://github.com/miiik4/Clippy.git
   ```
2. Open `Clippy.xcodeproj` in Xcode
3. Select the **Clippy** scheme and your Mac as the run destination
4. Build and run with `⌘R` (or `⌘B` to build only)

No external dependencies — just Xcode 15+ and macOS 14.0 or later.

## Features

- **Clipboard history** — automatically captures text and images (up to 200 items)
- **Global hotkey** — press `⌥⌘V` to open the floating panel from anywhere (customizable in settings)
- **Quick paste** — `⌘1` through `⌘9` to paste recent items, or `Return` to paste selected
- **Click to paste** — single-click an item to select it, double-click to paste it instantly
- **Paste as plain text** — `Shift+Return` to paste without formatting
- **Search** — filter your history instantly by typing
- **Snippets** — save items permanently with `⌘S`, switch with `Tab`
- **Clipboard merging** — rapid successive copies append text instead of creating new entries
- **App ignore list** — skip clipboard captures from password managers and banking apps
- **Sensitive content protection** — text from password managers is masked in the panel and encrypted at rest (key stored in your Keychain), decrypted only in memory when you paste
- **Image preview** — arrow keys to expand/collapse image previews inline
- **Source app icons** — see which app each item was copied from
- **Launch at login** — start Clippy automatically when you log in
- **Automatic updates** — checks for new releases and prompts you from the menu bar when one is available
- **Privacy** — automatically ignores concealed, transient, and auto-generated clipboard data

## Screenshots

| Menu Bar | Settings |
|----------|----------|
| ![Menu Bar](assets/toolbar_widget.png) | ![Settings](assets/settings.png) |

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Toggle Clippy | `⌥⌘V` |
| Paste item | `⌘1` – `⌘9` |
| Paste selected | `Return` |
| Paste as plain text | `Shift+Return` |
| Save/unsave snippet | `⌘S` |
| Switch History/Snippets | `Tab` |
| Preview image | `→` / `←` |
| Delete item | `fn+Delete` |
| Dismiss | `Escape` |

## Requirements

- macOS 14.0 or later
- Xcode 15+ (if building from source)
