import AppKit
import SwiftUI
import Observation

@Observable
final class ClipboardPanelState {
    var searchText = ""
    var selectedIndex = 0
    var showCount = 0
}

final class ClipboardPanelController {
    let state = ClipboardPanelState()
    let clipboardMonitor: ClipboardMonitor

    private var panel: FloatingPanel?
    private var localKeyMonitor: Any?
    private var globalClickMonitor: Any?

    var isVisible: Bool { panel?.isVisible ?? false }

    init(clipboardMonitor: ClipboardMonitor) {
        self.clipboardMonitor = clipboardMonitor
    }

    func toggle() {
        if isVisible { hide() } else { show() }
    }

    func show() {
        if panel == nil { createPanel() }
        guard let panel else { return }

        // Reset state
        state.searchText = ""
        state.selectedIndex = 0
        state.showCount += 1

        // Center on screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let panelSize = panel.frame.size
            let x = screenFrame.midX - panelSize.width / 2
            let y = screenFrame.midY - panelSize.height / 2 + 80
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.makeKeyAndOrderFront(nil)

        // Monitor keyboard events
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyEvent(event) == true {
                return nil // consume event
            }
            return event
        }

        // Dismiss on click outside
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.hide()
        }
    }

    func hide() {
        panel?.orderOut(nil)

        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
    }

    // MARK: - Key Event Handling

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        switch Int(event.keyCode) {
        case 53: // Escape
            hide()
            return true

        case 126: // Up arrow
            if state.selectedIndex > 0 {
                state.selectedIndex -= 1
            }
            return true

        case 125: // Down arrow
            let items = currentFilteredItems
            if state.selectedIndex < items.count - 1 {
                state.selectedIndex += 1
            }
            return true

        case 36: // Return
            pasteItemAtIndex(state.selectedIndex)
            return true

        default:
            break
        }

        // Cmd+1 through Cmd+9
        if event.modifierFlags.contains(.command) {
            if let chars = event.charactersIgnoringModifiers,
               let digit = Int(chars), digit >= 1, digit <= 9 {
                pasteItemAtIndex(digit - 1)
                return true
            }
        }

        return false
    }

    // MARK: - Paste

    private func pasteItemAtIndex(_ index: Int) {
        let items = currentFilteredItems
        guard index >= 0, index < items.count else { return }
        let item = items[index]

        clipboardMonitor.setIgnoreNextChange()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.contentType {
        case .text:
            if let text = item.textContent {
                pasteboard.setString(text, forType: .string)
            }
        case .image:
            if let data = item.imageData, let image = NSImage(data: data) {
                pasteboard.writeObjects([image])
            }
        }

        hide()
        PasteService.paste()
    }

    private var currentFilteredItems: [ClipboardItem] {
        clipboardMonitor.filteredItems(searchText: state.searchText)
    }

    // MARK: - Panel Creation

    private func createPanel() {
        let panelRect = NSRect(x: 0, y: 0, width: 640, height: 460)
        let panel = FloatingPanel(contentRect: panelRect)

        let listView = ClipboardListView(state: state, monitor: clipboardMonitor)

        let hostingView = NSHostingView(rootView: listView)

        // Visual effect background for translucency
        let visualEffect = NSVisualEffectView(frame: panelRect)
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 12
        visualEffect.layer?.masksToBounds = true

        hostingView.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: visualEffect.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
        ])

        panel.contentView = visualEffect
        self.panel = panel
    }
}
