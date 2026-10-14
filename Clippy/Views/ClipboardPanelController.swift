import AppKit
import Carbon.HIToolbox
import SwiftUI
import Observation

enum PanelTab: Int {
    case history
    case snippets
}

struct PanelFlash: Equatable {
    let message: String
    let systemImage: String
    var isWarning = false
}

@Observable
final class ClipboardPanelState {
    var searchText = ""
    var selectedIndex = 0
    var showCount = 0
    var activeTab: PanelTab = .history
    var flash: PanelFlash?
    var expandedItemID: UUID?
    var isAccessibilityGranted = true

    /// Snippet being edited, with the draft values.
    var editingSnippet: ClipboardItem?
    var editTitle = ""
    var editText = ""
}

final class ClipboardPanelController {
    let state = ClipboardPanelState()
    let clipboardMonitor: ClipboardMonitor

    private var panel: FloatingPanel?
    private var localKeyMonitor: Any?
    private var globalClickMonitor: Any?
    private var flashWorkItem: DispatchWorkItem?

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
        state.flash = nil
        state.expandedItemID = nil
        state.editingSnippet = nil
        state.isAccessibilityGranted = PasteService.isAccessibilityGranted
        state.showCount += 1

        // Center on the screen the mouse is on
        let mouse = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main {
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

    func openAccessibilitySettings() {
        hide()
        PasteService.openAccessibilitySettings()
    }

    // MARK: - Key Event Handling

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let keyCode = Int(event.keyCode)
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // While the snippet editor is open, only Escape and ⌘Return are ours.
        if state.editingSnippet != nil {
            switch keyCode {
            case kVK_Escape:
                cancelEditing()
                return true
            case kVK_Return where flags.contains(.command):
                commitEditing()
                return true
            default:
                return false
            }
        }

        switch keyCode {
        case kVK_Escape:
            hide()
            return true

        case kVK_UpArrow, kVK_DownArrow:
            let delta = keyCode == kVK_UpArrow ? -1 : 1
            if state.activeTab == .snippets, flags.contains([.command, .option]) {
                moveSelectedSnippet(by: delta)
            } else {
                let newIndex = state.selectedIndex + delta
                if newIndex >= 0, newIndex < currentDisplayItems.count {
                    state.selectedIndex = newIndex
                    state.expandedItemID = nil
                }
            }
            return true

        case kVK_RightArrow: // Expand preview
            guard let item = currentDisplayItems[safe: state.selectedIndex],
                  item.isExpandable, state.expandedItemID != item.id else { return false }
            state.expandedItemID = item.id
            return true

        case kVK_LeftArrow: // Collapse preview
            guard state.expandedItemID != nil else { return false }
            state.expandedItemID = nil
            return true

        case kVK_Return:
            pasteItemAtIndex(state.selectedIndex, plainText: flags.contains(.shift))
            return true

        case kVK_ForwardDelete: // fn+Backspace
            deleteSelectedItem()
            return true

        case kVK_Tab:
            state.activeTab = state.activeTab == .history ? .snippets : .history
            state.selectedIndex = 0
            state.searchText = ""
            state.expandedItemID = nil
            return true

        default:
            break
        }

        guard flags.contains(.command), let chars = event.charactersIgnoringModifiers?.lowercased() else {
            return false
        }

        // ⌘1 through ⌘9
        if let digit = Int(chars), digit >= 1, digit <= 9 {
            pasteItemAtIndex(digit - 1)
            return true
        }

        switch chars {
        case "s": // Save/unsave snippet
            toggleSnippet()
            return true
        case "p" where state.activeTab == .history: // Pin/unpin
            togglePin()
            return true
        case "e" where state.activeTab == .snippets: // Edit snippet
            beginEditing()
            return true
        default:
            return false
        }
    }

    // MARK: - Delete

    private func deleteSelectedItem() {
        guard let item = currentDisplayItems[safe: state.selectedIndex] else { return }

        if state.activeTab == .snippets {
            clipboardMonitor.deleteSnippet(item)
        } else {
            clipboardMonitor.deleteItem(item)
        }
        clampSelection()
    }

    private func clampSelection() {
        let count = currentDisplayItems.count
        if state.selectedIndex >= count {
            state.selectedIndex = max(0, count - 1)
        }
    }

    // MARK: - Snippets & pins

    private func toggleSnippet() {
        guard let item = currentDisplayItems[safe: state.selectedIndex] else { return }

        if state.activeTab == .snippets {
            clipboardMonitor.deleteSnippet(item)
            clampSelection()
            showFlash(PanelFlash(message: "Removed from Snippets", systemImage: "bookmark.slash"))
        } else if clipboardMonitor.saveAsSnippet(item) {
            showFlash(PanelFlash(message: "Saved to Snippets", systemImage: "bookmark.fill"))
        } else {
            showFlash(PanelFlash(message: "Already in Snippets", systemImage: "bookmark", isWarning: true))
        }
    }

    private func togglePin() {
        guard let item = currentDisplayItems[safe: state.selectedIndex] else { return }
        clipboardMonitor.togglePin(item)
        // Keep the same item selected after it moves in or out of the pinned group.
        if let newIndex = currentDisplayItems.firstIndex(where: { $0.id == item.id }) {
            state.selectedIndex = newIndex
        }
        showFlash(PanelFlash(message: item.isPinned ? "Unpinned" : "Pinned", systemImage: item.isPinned ? "pin.slash" : "pin.fill"))
    }

    private func moveSelectedSnippet(by offset: Int) {
        // Reordering a filtered list would be ambiguous.
        guard state.searchText.isEmpty,
              let item = currentDisplayItems[safe: state.selectedIndex],
              let newIndex = clipboardMonitor.moveSnippet(item, by: offset) else { return }
        state.selectedIndex = newIndex
    }

    func beginEditing() {
        guard state.activeTab == .snippets,
              let item = currentDisplayItems[safe: state.selectedIndex] else { return }
        state.editTitle = item.title ?? ""
        state.editText = item.textContent ?? ""
        state.editingSnippet = item
    }

    func commitEditing() {
        guard let item = state.editingSnippet else { return }
        clipboardMonitor.updateSnippet(item, title: state.editTitle, text: item.contentType == .text ? state.editText : nil)
        state.editingSnippet = nil
        state.showCount += 1 // refocus search
    }

    func cancelEditing() {
        state.editingSnippet = nil
        state.showCount += 1
    }

    private func showFlash(_ flash: PanelFlash) {
        flashWorkItem?.cancel()
        state.flash = flash
        let work = DispatchWorkItem { [weak self] in self?.state.flash = nil }
        flashWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
    }

    // MARK: - Paste

    /// Paste the item at the given index, used for click-to-paste from the list.
    func pasteItem(at index: Int, plainText: Bool = false) {
        pasteItemAtIndex(index, plainText: plainText)
    }

    private func pasteItemAtIndex(_ index: Int, plainText: Bool = false) {
        guard let item = currentDisplayItems[safe: index] else { return }

        clipboardMonitor.setIgnoreNextChange()
        PasteService.write(item, plainText: plainText)
        if state.activeTab == .history {
            clipboardMonitor.markUsed(item)
        }

        hide()
        PasteService.paste()
    }

    var currentDisplayItems: [ClipboardItem] {
        let query = SearchQuery(state.searchText)
        switch state.activeTab {
        case .history:
            return clipboardMonitor.filteredItems(query)
        case .snippets:
            return clipboardMonitor.filteredSnippets(query)
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

extension ClipboardItem {
    /// Whether → shows a larger preview: images, and text too long for the row.
    var isExpandable: Bool {
        switch contentType {
        case .image:
            return true
        case .text:
            guard !isSensitive, let text = textContent else { return false }
            return text.count > 120 || text.contains("\n")
        case .file:
            return (fileURLs?.count ?? 0) > 1
        }
    }
}
