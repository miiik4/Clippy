import SwiftUI

struct ClipboardListView: View {
    @Bindable var state: ClipboardPanelState
    var monitor: ClipboardMonitor
    var panelController: ClipboardPanelController
    @FocusState private var isSearchFocused: Bool

    private var displayItems: [ClipboardItem] {
        panelController.currentDisplayItems
    }

    var body: some View {
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

            Divider()
                .padding(.horizontal, 8)

            // Items list
            ZStack {
                if displayItems.isEmpty {
                    emptyStateView
                } else {
                    itemListView
                }

                // Snippet saved flash
                if state.snippetSavedFlash {
                    VStack {
                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: "bookmark.fill")
                            Text("Saved to Snippets")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(.green.opacity(0.85))
                        )
                        .padding(.bottom, 12)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.2), value: state.snippetSavedFlash)
                }
            }

            // Footer
            if let selectedItem = displayItems[safe: state.selectedIndex] {
                Divider()
                    .padding(.horizontal, 8)
                footerView(for: selectedItem)
            }
        }
        .onChange(of: state.searchText) { _, _ in
            state.selectedIndex = 0
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
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private var itemListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(Array(displayItems.enumerated()), id: \.element.id) { index, item in
                        ClipboardItemRow(
                            item: item,
                            index: index,
                            isSelected: index == state.selectedIndex,
                            isSnippet: state.activeTab == .snippets,
                            isExpanded: item.id == state.expandedImageID
                        )
                        .id(item.id)
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
            } else if item.contentType == .text {
                Text("\(item.wordCount) words \u{00B7} \(item.charCount) chars")
            } else {
                Text("Image")
            }
            if let appName = item.sourceAppName {
                Text("\u{00B7} \(appName)")
            }
            Spacer()
            if state.activeTab == .history {
                Text("Copied \(item.relativeTimeString)")
            } else {
                Text("\u{2318}S to save \u{00B7} Tab to switch")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

// MARK: - Safe Collection Subscript

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
