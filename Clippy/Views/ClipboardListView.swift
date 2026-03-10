import SwiftUI

struct ClipboardListView: View {
    @Bindable var state: ClipboardPanelState
    var monitor: ClipboardMonitor
    @FocusState private var isSearchFocused: Bool

    private var filteredItems: [ClipboardItem] {
        monitor.filteredItems(searchText: state.searchText)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                TextField("Search clipboard history\u{2026}", text: $state.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .focused($isSearchFocused)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()
                .padding(.horizontal, 8)

            // Items list
            if filteredItems.isEmpty {
                emptyStateView
            } else {
                itemListView
            }

            // Footer
            if let selectedItem = filteredItems[safe: state.selectedIndex] {
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

    // MARK: - Subviews

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: state.searchText.isEmpty ? "clipboard" : "magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text(state.searchText.isEmpty ? "No clipboard history yet" : "No matching items")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private var itemListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                        ClipboardItemRow(
                            item: item,
                            index: index,
                            isSelected: index == state.selectedIndex
                        )
                        .id(item.id)
                    }
                }
                .padding(.vertical, 4)
            }
            .onChange(of: state.selectedIndex) { _, newIndex in
                if let item = filteredItems[safe: newIndex] {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        proxy.scrollTo(item.id, anchor: .center)
                    }
                }
            }
        }
    }

    private func footerView(for item: ClipboardItem) -> some View {
        HStack {
            if item.contentType == .text {
                Text("\(item.wordCount) words \u{00B7} \(item.charCount) chars")
            } else {
                Text("Image")
            }
            Spacer()
            Text("Copied \(item.relativeTimeString)")
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
