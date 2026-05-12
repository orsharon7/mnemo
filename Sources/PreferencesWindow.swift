import SwiftUI
import AppKit
import Carbon.HIToolbox
import UniformTypeIdentifiers

struct PreferencesView: View {
    @ObservedObject var settings: Settings = .shared
    @State private var recording = false
    @State private var accessibilityTrusted = Paster.isAccessibilityTrusted
    @State private var selectedExcludedBundleID: String?

    var body: some View {
        Form {
            Section("Hotkey") {
                HStack {
                    Text("Open history:")
                    HotkeyRecorder(recording: $recording,
                                   current: settings.hotkey) { newKey in
                        settings.hotkey = newKey
                        NotificationCenter.default.post(name: .clipMateHotkeyChanged, object: nil)
                    }
                    Button("Reset") {
                        settings.hotkey = HotkeyConfig(keyCode: UInt32(kVK_ANSI_V),
                                                       modifiers: UInt32(optionKey | cmdKey))
                        NotificationCenter.default.post(name: .clipMateHotkeyChanged, object: nil)
                    }
                }
            }

            Section("Behavior") {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)

                Toggle("Auto-paste on Enter (requires Accessibility)",
                       isOn: $settings.autoPasteOnEnter)
                if settings.autoPasteOnEnter && !accessibilityTrusted {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        Text("Mnemo needs Accessibility permission to auto-paste.")
                            .font(.callout)
                        Button("Grant…") {
                            Paster.promptForAccessibility()
                            // Permission state only becomes accurate after relaunch in many cases.
                            accessibilityTrusted = Paster.isAccessibilityTrusted
                        }
                    }
                }
            }

            Section("Privacy") {
                Toggle("Block likely secrets (API keys, tokens, JWTs)",
                       isOn: $settings.blockLikelySecrets)
                Text("Skips entries that look like credentials. Pasteboard hints (1Password, concealed/transient types) are always honored.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Excluded Apps") {
                Text("Clipboard changes are not captured when one of these apps is frontmost.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                List(selection: $selectedExcludedBundleID) {
                    ForEach(settings.excludedBundleIDs, id: \.self) { bundleID in
                        Text(bundleID).tag(bundleID as String?)
                    }
                }
                .frame(minHeight: 100, maxHeight: 160)
                HStack {
                    Button("Add…") { addExcludedApp() }
                    Button("Remove") {
                        if let sel = selectedExcludedBundleID {
                            settings.excludedBundleIDs.removeAll { $0 == sel }
                            selectedExcludedBundleID = nil
                        }
                    }
                    .disabled(selectedExcludedBundleID == nil)
                }
            }

            Section("Search") {
                Toggle("Semantic search (on-device)",
                       isOn: $settings.semanticSearchEnabled)
                Text("Finds clips by meaning, not just literal text. Runs locally via Apple's NaturalLanguage — no network, no API key.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Storage") {
                Stepper(value: $settings.maxEntries, in: 100...20000, step: 100) {
                    Text("Keep up to \(settings.maxEntries) entries")
                }
                Stepper(value: $settings.retentionDays, in: 1...365) {
                    Text("Drop entries older than \(settings.retentionDays) day\(settings.retentionDays == 1 ? "" : "s")")
                }
            }

            Section {
                HStack {
                    Spacer()
                    Text("Mnemo v0.4.0 — local clipboard history. No cloud, ever.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 500)
        .onAppear { accessibilityTrusted = Paster.isAccessibilityTrusted }
    }

    private func addExcludedApp() {
        let panel = NSOpenPanel()
        panel.title = "Choose an application to exclude"
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let bundleID = Bundle(url: url)?.bundleIdentifier else { return }
        if !settings.excludedBundleIDs.contains(bundleID) {
            settings.excludedBundleIDs.append(bundleID)
        }
    }
}

/// Borderless recorder that grabs the next keyDown with modifiers and reports a new HotkeyConfig.
struct HotkeyRecorder: NSViewRepresentable {
    @Binding var recording: Bool
    var current: HotkeyConfig
    var onCapture: (HotkeyConfig) -> Void

    func makeNSView(context: Context) -> RecorderField {
        let v = RecorderField()
        v.onCapture = { cfg in
            recording = false
            onCapture(cfg)
        }
        v.onClick = { recording.toggle(); v.isRecording = recording }
        v.refresh(current: current, recording: recording)
        return v
    }

    func updateNSView(_ nsView: RecorderField, context: Context) {
        nsView.refresh(current: current, recording: recording)
    }
}

final class RecorderField: NSView {
    var onCapture: ((HotkeyConfig) -> Void)?
    var onClick: (() -> Void)?

    fileprivate var isRecording = false { didSet { needsDisplay = true } }
    private var currentText: String = ""

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 6
    }
    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize { NSSize(width: 140, height: 24) }

    func refresh(current: HotkeyConfig, recording: Bool) {
        self.isRecording = recording
        self.currentText = recording ? "Press a key…" : current.displayString
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        onClick?()
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { super.keyDown(with: event); return }
        if event.keyCode == 53 { // esc cancels
            isRecording = false
            return
        }
        if let cfg = HotkeyConfig.from(event: event) {
            currentText = cfg.displayString
            onCapture?(cfg)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let bg = isRecording
            ? NSColor.systemBlue.withAlphaComponent(0.18)
            : NSColor.controlBackgroundColor
        bg.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6).fill()

        let border = isRecording ? NSColor.systemBlue : NSColor.separatorColor
        border.setStroke()
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
                                xRadius: 6, yRadius: 6)
        path.lineWidth = 1
        path.stroke()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.labelColor
        ]
        let s = NSAttributedString(string: currentText, attributes: attrs)
        let size = s.size()
        let r = NSRect(x: (bounds.width - size.width) / 2,
                       y: (bounds.height - size.height) / 2,
                       width: size.width, height: size.height)
        s.draw(in: r)
    }
}

extension Notification.Name {
    static let clipMateHotkeyChanged = Notification.Name("MnemoHotkeyChanged")
}
