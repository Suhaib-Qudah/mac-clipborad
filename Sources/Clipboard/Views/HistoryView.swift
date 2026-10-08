import SwiftUI

struct HistoryView: View {
    let store: ClipboardStore
    @Bindable var state: PanelState
    var onActivate: (ClipItem) -> Void
    var onOpenSettings: () -> Void

    @AppStorage("autoPaste") private var autoPaste = true
    @FocusState private var searchFocused: Bool

    private var items: [ClipItem] { state.visibleItems(in: store.items) }

    private var selectedItem: ClipItem? {
        items.first { $0.id == state.selectedID } ?? items.first
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            filterBar
            Divider().opacity(0.6)
            HStack(spacing: 0) {
                list
                    .frame(width: 320)
                Divider().opacity(0.6)
                PreviewPane(item: selectedItem, store: store)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Divider().opacity(0.6)
            footer
        }
        .frame(width: PanelController.size.width, height: PanelController.size.height)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
        .onChange(of: state.focusToken) { searchFocused = true }
        .onChange(of: state.query) { state.selectedID = items.first?.id }
        .onChange(of: state.filter) { state.selectedID = items.first?.id }
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("Search clipboard history", text: $state.query)
                .textFieldStyle(.plain)
                .font(.system(size: 21, weight: .regular))
                .focused($searchFocused)
            if !state.query.isEmpty {
                Button {
                    state.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .glassEffect(.regular.interactive(), in: .circle)
            .help("Settings (⌘,)")
        }
        .padding(.horizontal, 20)
        .frame(height: 60)
    }

    private var filterBar: some View {
        HStack(spacing: 6) {
            ForEach(ClipFilter.allCases) { filter in
                let isSelected = state.filter == filter
                Button {
                    state.filter = filter
                } label: {
                    Label(filter.title, systemImage: filter.symbol)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .foregroundStyle(isSelected ? Color.white : Color.secondary)
                        .background {
                            Capsule().fill(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.quaternary.opacity(0.6)))
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
            if store.isPaused {
                Label("Paused", systemImage: "pause.circle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    // MARK: - List

    private var list: some View {
        Group {
            if items.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                ClipRow(
                                    item: item,
                                    index: index,
                                    isSelected: item.id == selectedItem?.id,
                                    store: store
                                )
                                .id(item.id)
                                .onTapGesture(count: 2) { onActivate(item) }
                                .simultaneousGesture(TapGesture().onEnded { state.selectedID = item.id })
                                .contextMenu { contextMenu(for: item) }
                            }
                        }
                        .padding(8)
                    }
                    .scrollIndicators(.never)
                    .onChange(of: state.selectedID) { _, id in
                        guard let id else { return }
                        withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(id) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func contextMenu(for item: ClipItem) -> some View {
        Button(autoPaste ? "Paste" : "Copy", systemImage: "doc.on.clipboard") { onActivate(item) }
        Button(item.isPinned ? "Unpin" : "Pin", systemImage: item.isPinned ? "pin.slash" : "pin") {
            store.togglePin(item)
        }
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive) { store.delete(item) }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: state.query.isEmpty ? "list.clipboard" : "magnifyingglass")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.tertiary)
            Text(state.query.isEmpty ? "Nothing here yet" : "No Results")
                .font(.system(size: 15, weight: .semibold))
            Text(state.query.isEmpty ? "Copy text, links, images or files\nand they'll appear here." : "Try a different search.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "list.clipboard.fill")
                    .foregroundStyle(.tint)
                Text("\(store.items.count) \(store.items.count == 1 ? "item" : "items")")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            KeyHint(key: "↩", label: autoPaste ? "Paste" : "Copy")
            KeyHint(key: "⌘P", label: "Pin")
            KeyHint(key: "⌘⌫", label: "Delete")
            KeyHint(key: "⇥", label: "Filter")
            KeyHint(key: "esc", label: "Close")
        }
        .font(.system(size: 11, weight: .medium))
        .padding(.horizontal, 18)
        .frame(height: 38)
    }
}

private struct KeyHint: View {
    let key: String
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Text(key)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .padding(.horizontal, 5)
                .frame(minWidth: 20, minHeight: 18)
                .background(.quaternary.opacity(0.8), in: .rect(cornerRadius: 5))
            Text(label)
                .foregroundStyle(.secondary)
        }
    }
}
