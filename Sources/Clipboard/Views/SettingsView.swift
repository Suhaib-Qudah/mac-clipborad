import Combine
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Bindable var store: ClipboardStore

    @AppStorage("historyLimit") private var historyLimit = 200
    @AppStorage("autoPaste") private var autoPaste = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var isTrusted = Paster.isTrusted
    @State private var confirmClear = false

    private let limits = [50, 100, 200, 500, 1000]
    private let trustTimer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Clipboard")
                            .font(.system(size: 20, weight: .semibold))
                        Text("Version \(version)")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            if enabled {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
                LabeledContent("Open clipboard history") {
                    Text("⇧ ⌘ V")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.quaternary, in: .rect(cornerRadius: 6))
                }
                Picker("Keep history", selection: $historyLimit) {
                    ForEach(limits, id: \.self) { Text("\($0) items").tag($0) }
                }
                .onChange(of: historyLimit) { store.applyLimit() }
            }

            Section {
                Toggle("Paste automatically", isOn: $autoPaste)
                if autoPaste && !isTrusted {
                    HStack {
                        Label("Needs Accessibility permission", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Spacer()
                        Button("Grant Access…") {
                            Paster.requestAccess()
                            Paster.openAccessibilitySettings()
                        }
                    }
                }
            } header: {
                Text("Pasting")
            } footer: {
                Text("When on, choosing an item pastes it straight into the app you were using. When off, it is copied to the clipboard.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Pause clipboard capture", isOn: $store.isPaused)
                Button("Clear History…", role: .destructive) { confirmClear = true }
            } header: {
                Text("Privacy")
            } footer: {
                Text("Passwords and content marked as concealed by apps like Passwords, Keychain and 1Password are never saved. History is stored only on this Mac.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .onReceive(trustTimer) { _ in isTrusted = Paster.isTrusted }
        .confirmationDialog("Clear clipboard history?", isPresented: $confirmClear) {
            Button("Clear All Except Pinned", role: .destructive) { store.clear(keepPinned: true) }
            Button("Clear Everything", role: .destructive) { store.clear(keepPinned: false) }
        } message: {
            Text("This can't be undone.")
        }
    }
}
