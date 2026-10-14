import AppKit
import ApplicationServices
import Carbon.HIToolbox
import CoreGraphics

enum PasteService {
    /// Puts `item` on the general pasteboard. With `plainText`, only the
    /// plain string is written, so the target app pastes it unformatted.
    static func write(_ item: ClipboardItem, plainText: Bool = false) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.contentType {
        case .text:
            guard let text = item.textContent else { return }
            let entry = NSPasteboardItem()
            if !plainText {
                if let rtf = item.rtfData { entry.setData(rtf, forType: .rtf) }
                if let html = item.htmlData { entry.setData(html, forType: .html) }
            }
            entry.setString(text, forType: .string)
            pasteboard.writeObjects([entry])

        case .image:
            guard let fileName = item.imageFileName,
                  let png = ImageStore.shared.data(for: fileName) else { return }
            let entry = NSPasteboardItem()
            entry.setData(png, forType: .png)
            // Many apps only read TIFF.
            if let tiff = NSBitmapImageRep(data: png)?.tiffRepresentation {
                entry.setData(tiff, forType: .tiff)
            }
            pasteboard.writeObjects([entry])

        case .file:
            guard let urls = item.fileURLs, !urls.isEmpty else { return }
            pasteboard.writeObjects(urls as [NSURL])
        }
    }

    /// Simulates ⌘V after a short delay to let the panel dismiss and focus return.
    static func paste() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let source = CGEventSource(stateID: .combinedSessionState)
            let vKey = CGKeyCode(kVK_ANSI_V)

            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
            keyDown?.flags = .maskCommand
            keyDown?.post(tap: .cghidEventTap)

            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
            keyUp?.flags = .maskCommand
            keyUp?.post(tap: .cghidEventTap)
        }
    }

    /// Whether Clippy may post keyboard events (required to paste).
    static var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Prompts the user for Accessibility permission if not already granted.
    @discardableResult
    static func requestAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// Opens System Settings at Privacy & Security › Accessibility.
    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
