import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class PanelState {
    var query = ""
    var filter: ClipFilter = .all
    var selectedID: ClipItem.ID?
    var focusToken = 0

    func visibleItems(in items: [ClipItem]) -> [ClipItem] {
        let query = query.trimmingCharacters(in: .whitespaces)
        return items.filter { item in
            filter.matches(item) && (query.isEmpty || item.searchableText.localizedStandardContains(query))
        }
    }
}

final class ClipboardPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    static let size = NSSize(width: 780, height: 500)

    let store: ClipboardStore
    let state = PanelState()
    var onOpenSettings: () -> Void = {}

    private var panel: ClipboardPanel!
    private var keyMonitor: Any?
    private var previousApp: NSRunningApplication?
    private var lastHidden = Date.distantPast

    var isVisible: Bool { panel.isVisible }

    init(store: ClipboardStore) {
        self.store = store
        super.init()

        panel = ClipboardPanel(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .utilityWindow
        panel.delegate = self

        let root = HistoryView(
            store: store,
            state: state,
            onActivate: { [weak self] item in self?.activate(item) },
            onOpenSettings: { [weak self] in self?.openSettings() }
        )
        panel.contentView = NSHostingView(rootView: root)
    }

    func toggle() {
        if panel.isVisible {
            hide()
        } else if Date().timeIntervalSince(lastHidden) > 0.25 {
            show()
        }
    }

    func show() {
        let front = NSWorkspace.shared.frontmostApplication
        if front?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApp = front
        }
        state.query = ""
        state.filter = .all
        state.selectedID = store.items.first?.id
        position()
        panel.makeKeyAndOrderFront(nil)
        state.focusToken += 1
        installKeyMonitor()
    }

    func hide() {
        guard panel.isVisible else { return }
        lastHidden = Date()
        panel.orderOut(nil)
        removeKeyMonitor()
    }

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    private func openSettings() {
        hide()
        onOpenSettings()
    }

    private func position() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }
        let size = panel.frame.size
        let origin = NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.minY + frame.height * 0.6 - size.height / 2
        )
        panel.setFrameOrigin(origin)
    }

    // MARK: - Actions

    private var visibleItems: [ClipItem] { state.visibleItems(in: store.items) }

    private var selectedItem: ClipItem? {
        visibleItems.first { $0.id == state.selectedID }
    }

    func activate(_ item: ClipItem) {
        store.copyToPasteboard(item)
        let target = previousApp
        hide()

        guard UserDefaults.standard.bool(forKey: "autoPaste") else { return }
        guard Paster.isTrusted else {
            Paster.requestAccess()
            return
        }
        if NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier {
            target?.activate()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            Paster.pasteIntoFrontApp()
        }
    }

    private func moveSelection(by offset: Int) {
        let items = visibleItems
        guard !items.isEmpty else { return }
        let current = items.firstIndex { $0.id == state.selectedID } ?? -1
        let next = min(max(current + offset, 0), items.count - 1)
        state.selectedID = items[next].id
    }

    private func cycleFilter(backwards: Bool) {
        let all = ClipFilter.allCases
        let index = all.firstIndex(of: state.filter) ?? 0
        state.filter = all[(index + (backwards ? -1 : 1) + all.count) % all.count]
        state.selectedID = visibleItems.first?.id
    }

    private func deleteSelected() {
        let items = visibleItems
        guard let item = selectedItem, let index = items.firstIndex(of: item) else { return }
        store.delete(item)
        let remaining = visibleItems
        state.selectedID = remaining.isEmpty ? nil : remaining[min(index, remaining.count - 1)].id
    }

    // MARK: - Keyboard

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.panel else { return event }
            return self.handle(event) ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    private func handle(_ event: NSEvent) -> Bool {
        let command = event.modifierFlags.contains(.command)
        switch event.keyCode {
        case 53:
            hide()
            return true
        case 125:
            moveSelection(by: 1)
            return true
        case 126:
            moveSelection(by: -1)
            return true
        case 36, 76:
            if let item = selectedItem { activate(item) }
            return true
        case 48:
            cycleFilter(backwards: event.modifierFlags.contains(.shift))
            return true
        case 51 where command:
            deleteSelected()
            return true
        default:
            break
        }

        guard command, let characters = event.charactersIgnoringModifiers?.lowercased() else { return false }
        switch characters {
        case "p":
            if let item = selectedItem { store.togglePin(item) }
            return true
        case ",":
            openSettings()
            return true
        case "w":
            hide()
            return true
        default:
            if let number = Int(characters), (1...9).contains(number) {
                let items = visibleItems
                if number <= items.count { activate(items[number - 1]) }
                return true
            }
            return false
        }
    }
}
