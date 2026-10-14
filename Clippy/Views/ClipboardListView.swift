import SwiftUI

struct ClipboardListView: View {
    @Bindable var state: ClipboardPanelState
    var monitor: ClipboardMonitor
    var panelController: ClipboardPanelController
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        // Filter once per render and hand the result to the subviews.
        let displayItems = panelController.currentDisplayItems

        VStack(spacing: 0) {
            // Search bar + tabs
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                TextField("Search \(state.activeTab == .history ? "clipboard history" : "snippets")\u{2026}", text: $state.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .focused($isSearchFocused)

                HStack(spacing: 2) {
                    tabButton("History", icon: "clock", tab: .history)
                    tabButton("Snippets", icon: "bookmark", tab: .snippets)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            if !state.isAccessibilityGranted {
                accessibilityBanner
            }

            Divider()
                .padding(.horizontal, 8)

            // Items list
            ZStack {
                if displayItems.isEmpty {
                    emptyStateView
                } else {
                    itemListView(displayItems)
                }

                if let flash = state.flash {
                    flashView(flash)
                }

                if state.editingSnippet != nil {
                    SnippetEditorView(state: state, panelController: panelController)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: state.flash)

            // Footer
            if let selectedItem = displayItems[safe: state.selectedIndex] {
                Divider()
                    .padding(.horizontal, 8)
                footerView(for: selectedItem)
            }
        }
        .onChange(of: state.searchText) { _, _ in
            state.selectedIndex = 0
            state.expandedItemID = nil
        }
        .onChange(of: state.showCount) { _, _ in
            isSearchFocused = true
        }
        .onAppear {
            isSearchFocused = true
        }
    }

    // MARK: - Tab Button

    private func tabButton(_ label: String, icon: String, tab: PanelTab) -> some View {
        Button {
            state.activeTab = tab
            state.selectedIndex = 0
            state.searchText = ""
            state.expandedItemID = nil
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(state.activeTab == tab ? Color.accentColor.opacity(0.15) : .clear)
            )
            .foregroundStyle(state.activeTab == tab ? .primary : .secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Subviews

    private var accessibilityBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("Clippy needs Accessibility access to paste. Items are copied to the clipboard until then.")
                .font(.system(size: 11))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button("Open Settings") {
                panelController.openAccessibilitySettings()
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
    }

    private func flashView(_ flash: PanelFlash) -> some View {
        VStack {
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: flash.systemImage)
                Text(flash.message)
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill((flash.isWarning ? Color.orange : Color.green).opacity(0.85))
            )
            .padding(.bottom, 12)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            if state.activeTab == .snippets {
                Image(systemName: "bookmark")
                    .font(.system(size: 28))
                    .foregroundStyle(.tertiary)
                Text(state.searchText.isEmpty ? "No snippets saved yet" : "No matching snippets")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                if state.searchText.isEmpty {
                    Text("Select an item and press \u{2318}S to save")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            } else {
                Image(systemName: state.searchText.isEmpty ? "clipboard" : "magnifyingglass")
                    .font(.system(size: 28))
                    .foregroundStyle(.tertiary)
                Text(state.searchText.isEmpty ? "No clipboard history yet" : "No matching items")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                if !state.searchText.isEmpty {
                    Text("Filters: app:Safari  type:text, image, file, link, color, pinned")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private func itemListView(_ displayItems: [ClipboardItem]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(Array(displayItems.enumerated()), id: \.element.id) { index, item in
                        ClipboardItemRow(
                            item: item,
                            index: index,
                            isSelected: index == state.selectedIndex,
                            isSnippet: state.activeTab == .snippets,
                            isExpanded: item.id == state.expandedItemID
                        )
                        .id(item.id)
                        .onTapGesture(count: 2) {
                            state.selectedIndex = index
                            panelController.pasteItem(at: index)
                        }
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in
                                    if state.selectedIndex != index {
                                        state.selectedIndex = index
                                    }
                                }
                        )
                    }
                }
                .padding(.vertical, 4)
            }
            .onChange(of: state.selectedIndex) { _, newIndex in
                if let item = displayItems[safe: newIndex] {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        proxy.scrollTo(item.id, anchor: .center)
                    }
                }
            }
        }
    }

    private func footerView(for item: ClipboardItem) -> some View {
        HStack {
            if item.isSensitive {
                Text("Sensitive content")
            } else {
                switch item.contentType {
                case .text:
                    Text("\(item.wordCount) words \u{00B7} \(item.charCount) chars")
                    if item.hasRichText {
                        Text("\u{00B7} Formatted (\u{21E7}\u{21A9} plain)")
                    }
                case .image:
                    Text("Image")
                case .file:
                    let count = item.fileURLs?.count ?? 0
                    Text(count == 1 ? "1 file" : "\(count) files")
                }
            }
            if let appName = item.sourceAppName {
                Text("\u{00B7} \(appName)")
            }
            Spacer()
            if state.activeTab == .history {
                Text("Copied \(item.relativeTimeString)")
            } else {
                Text("\u{2318}E edit \u{00B7} \u{2318}\u{2325}\u{2191}\u{2193} reorder")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

// MARK: - Snippet Editor

private struct SnippetEditorView: View {
    @Bindable var state: ClipboardPanelState
    var panelController: ClipboardPanelController
    @FocusState private var isTitleFocused: Bool

    private var isText: Bool { state.editingSnippet?.contentType == .text }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Edit Snippet")
                .font(.headline)

            TextField("Name (optional)", text: $state.editTitle)
                .textFieldStyle(.roundedBorder)
                .focused($isTitleFocused)

            if isText {
                TextEditor(text: $state.editText)
                    .font(.system(size: 12, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
            } else {
                Spacer()
            }

            HStack {
                Text("\u{2318}\u{21A9} save \u{00B7} \u{238B} cancel")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { panelController.cancelEditing() }
                Button("Save") { panelController.commitEditing() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .onAppear { isTitleFocused = true }
    }
}

// MARK: - Safe Collection Subscript

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
