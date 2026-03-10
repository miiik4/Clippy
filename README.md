# Clippy

A lightweight clipboard history manager for macOS. Lives in your menu bar, stores everything you copy, and lets you paste any previous item with a quick keyboard shortcut.

![Clipboard History Panel](assets/clippy.png)

## Features

- **Clipboard history** — automatically captures text and images (up to 200 items)
- **Global hotkey** — press `⌥⌘C` to open the floating panel from anywhere
- **Quick paste** — `⌘1` through `⌘9` to paste recent items, or `Return` to paste selected
- **Paste as plain text** — `Shift+Return` to paste without formatting
- **Search** — filter your history instantly by typing
- **Snippets** — save items permanently with `⌘S`, switch with `Tab`
- **Clipboard merging** — rapid successive copies append text instead of creating new entries
- **App ignore list** — skip clipboard captures from password managers and banking apps
- **Image preview** — arrow keys to expand/collapse image previews inline
- **Source app icons** — see which app each item was copied from
- **Launch at login** — start Clippy automatically when you log in
- **Privacy** — automatically ignores concealed, transient, and auto-generated clipboard data

## Screenshots

| Menu Bar | Settings |
|----------|----------|
| ![Menu Bar](assets/toolbar_widget.png) | ![Settings](assets/settings.png) |

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Toggle Clippy | `⌥⌘C` |
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

## Building

Open `Clippy.xcodeproj` in Xcode and build with `⌘B`. No external dependencies.
