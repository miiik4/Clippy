import AppKit
import SwiftUI
import Observation

enum PanelTab: Int {
    case history
    case snippets
}

@Observable
final class ClipboardPanelState {
    var searchText = ""
    var selectedIndex = 0
    var showCount = 0
    var activeTab: PanelTab = .history
    var snippetSavedFlash = false
    var expandedImageID: UUID?
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

    deinit {
        hide()
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
        state.activeTab = .history
        state.snippetSavedFlash = false
        state.expandedImageID = nil
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
                state.expandedImageID = nil
            }
            return true

        case 125: // Down arrow
            let items = currentDisplayItems
            if state.selectedIndex < items.count - 1 {
                state.selectedIndex += 1
                state.expandedImageID = nil
            }
            return true

        case 124: // Right arrow — expand image preview
            if let item = currentDisplayItems[safe: state.selectedIndex],
               item.contentType == .image {
                state.expandedImageID = item.id
            }
            return true

        case 123: // Left arrow — collapse image preview
            state.expandedImageID = nil
            return true

        case 36: // Return
            let plain = event.modifierFlags.contains(.shift)
            pasteItemAtIndex(state.selectedIndex, plainText: plain)
            return true

        case 117: // Forward Delete (fn+Backspace)
            deleteSelectedItem()
            return true

        default:
            break
        }

        // ⌘1 through ⌘9
        if event.modifierFlags.contains(.command) {
            if let chars = event.charactersIgnoringModifiers {
                if let digit = Int(chars), digit >= 1, digit <= 9 {
                    pasteItemAtIndex(digit - 1)
                    return true
                }

                // ⌘S — save/unsave snippet
                if chars == "s" {
                    toggleSnippet()
                    return true
                }
            }
        }

        // Tab key — switch between History and Snippets
        if Int(event.keyCode) == 48 { // Tab
            state.activeTab = state.activeTab == .history ? .snippets : .history
            state.selectedIndex = 0
            state.searchText = ""
            return true
        }

        return false
    }

    // MARK: - Delete

    private func deleteSelectedItem() {
        let items = currentDisplayItems
        guard state.selectedIndex >= 0, state.selectedIndex < items.count else { return }
        let item = items[state.selectedIndex]

        if state.activeTab == .snippets {
            clipboardMonitor.deleteSnippet(item)
        } else {
            clipboardMonitor.deleteItem(item)
        }

        // Clamp selection to new list bounds
        let updatedItems = currentDisplayItems
        if state.selectedIndex >= updatedItems.count {
            state.selectedIndex = max(0, updatedItems.count - 1)
        }
    }

    // MARK: - Save as Snippet

    private func toggleSnippet() {
        let items = currentDisplayItems
        guard state.selectedIndex >= 0, state.selectedIndex < items.count else { return }
        let item = items[state.selectedIndex]

        if state.activeTab == .snippets {
            clipboardMonitor.deleteSnippet(item)
            let updatedItems = currentDisplayItems
            if state.selectedIndex >= updatedItems.count {
                state.selectedIndex = max(0, updatedItems.count - 1)
            }
            state.snippetSavedFlash = false
        } else {
            clipboardMonitor.saveAsSnippet(item)
            state.snippetSavedFlash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.state.snippetSavedFlash = false
            }
        }
    }

    // MARK: - Paste

    /// Paste the item at the given index, used for click-to-paste from the list.
    func pasteItem(at index: Int, plainText: Bool = false) {
        pasteItemAtIndex(index, plainText: plainText)
    }

    private func pasteItemAtIndex(_ index: Int, plainText: Bool = false) {
        let items = currentDisplayItems
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
            if let fileName = item.imageFileName,
               let data = ImageStore.shared.data(for: fileName),
               let image = NSImage(data: data) {
                pasteboard.writeObjects([image])
            }
        }

        hide()
        if plainText {
            PasteService.pastePlain()
        } else {
            PasteService.paste()
        }
    }

    var currentDisplayItems: [ClipboardItem] {
        switch state.activeTab {
        case .history:
            return clipboardMonitor.filteredItems(searchText: state.searchText)
        case .snippets:
            guard !state.searchText.isEmpty else { return clipboardMonitor.snippets }
            return clipboardMonitor.snippets.filter { item in
                item.textContent?.localizedCaseInsensitiveContains(state.searchText) ?? false
            }
        }
    }

    // MARK: - Panel Creation

    private func createPanel() {
        let panelRect = NSRect(x: 0, y: 0, width: 640, height: 460)
        let panel = FloatingPanel(contentRect: panelRect)

        let listView = ClipboardListView(state: state, monitor: clipboardMonitor, panelController: self)

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
