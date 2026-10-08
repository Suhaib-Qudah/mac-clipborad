import AppKit
import Carbon.HIToolbox
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = ClipboardStore()
    private var panel: PanelController!
    private var statusItem: NSStatusItem!
    private var hotKey: HotKey?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: ["autoPaste": true, "historyLimit": 200])

        store.start()
        panel = PanelController(store: store)
        panel.onOpenSettings = { [weak self] in self?.openSettings() }
        setUpStatusItem()

        hotKey = HotKey(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey | shiftKey)) { [weak self] in
            MainActor.assumeIsolated { self?.panel.toggle() }
        }

        let defaults = UserDefaults.standard
        if CommandLine.arguments.contains("--show") || !defaults.bool(forKey: "didLaunchBefore") {
            defaults.set(true, forKey: "didLaunchBefore")
            panel.show()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        panel.show()
        return false
    }

    // MARK: - Status item

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "list.clipboard", accessibilityDescription: "Clipboard")
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            statusItem.menu = makeMenu()
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            panel.toggle()
        }
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        let show = NSMenuItem(title: "Show Clipboard History", action: #selector(showPanel), keyEquivalent: "v")
        show.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(show)
        menu.addItem(.separator())

        let pause = NSMenuItem(title: "Pause Capture", action: #selector(togglePause), keyEquivalent: "")
        pause.state = store.isPaused ? .on : .off
        menu.addItem(pause)
        menu.addItem(NSMenuItem(title: "Clear History", action: #selector(clearHistory), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Clipboard", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        for item in menu.items where item.action != #selector(NSApplication.terminate(_:)) {
            item.target = self
        }
        return menu
    }

    @objc private func showPanel() { panel.show() }

    @objc private func togglePause() { store.isPaused.toggle() }

    @objc private func clearHistory() { store.clear() }

    @objc func openSettings() {
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView(store: store))
            let window = NSWindow(contentViewController: hosting)
            window.title = "Clipboard Settings"
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
