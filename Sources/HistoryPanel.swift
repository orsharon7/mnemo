import SwiftUI
import AppKit

enum ArrowDirection { case up, down }

// MARK: - App icon cache

@MainActor
private final class AppIconCache {
    static let shared = AppIconCache()
    private let cache: NSCache<NSString, NSImage> = {
        let c = NSCache<NSString, NSImage>()
        c.countLimit = 128
        return c
    }()
    private var missesQueue: [String] = []
    private var missesSet: Set<String> = []
    private let missesLimit = 256

    private init() {}

    func icon(forBundle bundleID: String) -> NSImage? {
        if let cached = cache.object(forKey: bundleID as NSString) {
            return cached
        }
        if missesSet.contains(bundleID) {
            return nil
        }

        let img: NSImage?
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            img = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            img = nil
        }

        if let img = img {
            cache.setObject(img, forKey: bundleID as NSString)
        } else {
            if missesQueue.count >= missesLimit {
                let evicted = missesQueue.removeFirst()
                missesSet.remove(evicted)
            }
            missesQueue.append(bundleID)
            missesSet.insert(bundleID)
        }
        return img
    }
}

// MARK: - Type badge color

private extension ClipEntryType {
    var badgeColor: Color {
        switch self {
        case .url:       return Color(red: 0.2, green: 0.55, blue: 1.0)
        case .email:     return Color(red: 0.6, green: 0.35, blue: 1.0)
        case .json:      return Color(red: 0.25, green: 0.75, blue: 0.55)
        case .code:      return Color(red: 0.95, green: 0.6, blue: 0.1)
        case .multiline: return Color(red: 0.55, green: 0.55, blue: 0.6)
        case .text:      return .secondary
        }
    }
}

struct HistoryPanel: View {
    @ObservedObject var store: HistoryStore
    @ObservedObject var panelState: PanelState
    @ObservedObject var settings: Settings = .shared
    var onPick: (ClipEntry) -> Void
    var onDismiss: () -> Void
    var onExcludeApp: ((String) -> Void)?

    @State private var query: String = ""
    @State private var selectionIndex: Int = 0
    @State private var previewing: ClipEntry?
    @State private var isSearchFocused: Bool = true

    private var filtered: [ClipEntry] {
        store.search(query)
    }

    var body: some View {
        VStack(spacing: 0) {
            SearchField(text: $query,
                        isFocused: $isSearchFocused,
                        onSubmit: commitSelection,
                        onEscape: handleEscape,
                        onArrow: handleArrow,
                        onCommandNumber: pickNumbered,
                        onSpace: togglePreview,
                        onPin: pinSelection,
                        onDelete: deleteSelection)
                .frame(height: 28)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 6)

            Color(NSColor.separatorColor).frame(height: 1 / (NSScreen.main?.backingScaleFactor ?? 2))

            if filtered.isEmpty {
                VStack {
                    Spacer()
                    Text(store.entries.isEmpty
                         ? "Nothing copied yet.\nCopy something — it'll appear here."
                         : "No matches for \"\(query)\"")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    List(Array(filtered.enumerated()), id: \.element.id) { idx, entry in
                        HistoryRow(entry: entry,
                                   query: query,
                                   index: idx,
                                   isSelected: idx == selectionIndex)
                            .id(entry.id)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) { onPick(entry) }
                            .onTapGesture { selectionIndex = idx }
                            .listRowInsets(EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6))
                    }
                    .listStyle(.plain)
                    .onChange(of: selectionIndex) { _, newValue in
                        guard newValue < filtered.count else { return }
                        proxy.scrollTo(filtered[newValue].id, anchor: .center)
                    }
                }
            }

            Color(NSColor.separatorColor).frame(height: 1 / (NSScreen.main?.backingScaleFactor ?? 2))
            HStack(spacing: 12) {
                Text("↑↓ navigate").foregroundStyle(.secondary)
                Text("⏎ paste").foregroundStyle(.secondary)
                Text("␣ preview").foregroundStyle(.secondary)
                Text("⌘P pin").foregroundStyle(.secondary)
                Text("⌫ delete").foregroundStyle(.secondary)
                Text("⌘1–9 quick").foregroundStyle(.secondary)
                Text("/url /json /pin /code /email /text /multiline").foregroundStyle(.tertiary)
                Spacer()
                if let bundleID = panelState.previousAppBundleID,
                   let name = panelState.previousAppName,
                   !settings.excludedBundleIDs.contains(bundleID) {
                    Button("Don't capture from \(name)") {
                        onExcludeApp?(bundleID)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                Text("\(filtered.count) of \(store.entries.count)")
                    .foregroundStyle(.tertiary)
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(minWidth: 600, minHeight: 400)
        .onChange(of: query) { _, _ in selectionIndex = 0 }
        .onReceive(NotificationCenter.default.publisher(for: .clipMatePanelOpened)) { _ in
            query = ""
            selectionIndex = 0
            previewing = nil
            isSearchFocused = true
        }
        .sheet(item: $previewing) { entry in
            QuickLookView(entry: entry) { previewing = nil }
        }
    }

    private func commitSelection() {
        guard !filtered.isEmpty else { return }
        let idx = min(max(0, selectionIndex), filtered.count - 1)
        onPick(filtered[idx])
    }

    private func handleEscape() {
        if previewing != nil { previewing = nil } else { onDismiss() }
    }

    private func handleArrow(_ direction: ArrowDirection) {
        guard !filtered.isEmpty else { return }
        switch direction {
        case .down: selectionIndex = min(selectionIndex + 1, filtered.count - 1)
        case .up:   selectionIndex = max(selectionIndex - 1, 0)
        }
    }

    private func pickNumbered(_ n: Int) {
        let idx = n - 1
        if idx >= 0 && idx < filtered.count {
            onPick(filtered[idx])
        }
    }

    private func togglePreview() {
        guard !filtered.isEmpty, selectionIndex < filtered.count else { return }
        if previewing == nil {
            previewing = filtered[selectionIndex]
        } else {
            previewing = nil
        }
    }

    private func pinSelection() {
        guard !filtered.isEmpty, selectionIndex < filtered.count else { return }
        store.togglePin(filtered[selectionIndex])
    }

    private func deleteSelection() {
        guard !filtered.isEmpty, selectionIndex < filtered.count else { return }
        let entry = filtered[selectionIndex]
        store.deleteEntry(entry)
        // Keep selection anchored near where it was.
        selectionIndex = max(0, min(selectionIndex, filtered.count - 2))
    }
}

struct QuickLookView: View {
    let entry: ClipEntry
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                if let badge = entry.type.badge {
                    Text(badge)
                        .font(.system(.caption2, design: .monospaced).bold())
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.accentColor.opacity(0.18)))
                }
                if entry.isPinned {
                    Image(systemName: "pin.fill").foregroundStyle(.orange)
                }
                Text(entry.sourceName ?? "Unknown source").font(.caption).foregroundStyle(.secondary)
                Text("•").foregroundStyle(.secondary).font(.caption)
                Text("\(entry.content.count) chars").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Close") { onClose() }.keyboardShortcut(.cancelAction)
            }
            .padding(12)
            Color(NSColor.separatorColor).frame(height: 1 / (NSScreen.main?.backingScaleFactor ?? 2))
            ScrollView {
                Text(entry.content)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(12)
            }
        }
        .frame(width: 640, height: 420)
    }
}

struct HistoryRow: View {
    let entry: ClipEntry
    let query: String
    let index: Int
    let isSelected: Bool

    @State private var appIcon: NSImage? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(isSelected ? Color.accentColor : Color.clear)
                .frame(width: 3)
                .cornerRadius(1.5)
                .padding(.trailing, 7)

            if let badge = entry.type.badge {
                Text(badge)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 4).padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(isSelected
                                  ? Color.white.opacity(0.25)
                                  : entry.type.badgeColor.opacity(0.18))
                    )
                    .foregroundStyle(isSelected ? .white : entry.type.badgeColor)
                    .frame(width: 36, alignment: .center)
                    .padding(.trailing, 6)
                    .padding(.top, 3)
            } else {
                Spacer().frame(width: 42)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    if entry.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(isSelected ? .white : .orange)
                    }
                    Text(preview(entry.content))
                        .font(.system(size: 13))
                        .lineLimit(2)
                        .foregroundStyle(isSelected ? .white : .primary)
                }

                HStack(spacing: 5) {
                    if let icon = appIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 13, height: 13)
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                    }
                    if entry.copyCount > 1 {
                        Text("\(entry.copyCount)×")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(isSelected ? Color.white.opacity(0.20) : Color.secondary.opacity(0.12))
                            )
                            .foregroundStyle(isSelected ? .white : .secondary)
                    }
                    if let src = entry.sourceName {
                        Text(src)
                        Text("•")
                    }
                    Text(relativeTime(entry.lastUsedAt))
                    if entry.truncated {
                        Text("• truncated")
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
            }

            Spacer(minLength: 0)

            Text(index < 9 ? "⌘\(index + 1)" : "")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(isSelected ? AnyShapeStyle(Color.white.opacity(0.7)) : AnyShapeStyle(HierarchicalShapeStyle.quaternary))
                .frame(width: 24, alignment: .trailing)
                .padding(.top, 3)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.06) : Color.clear)
        )
        .onAppear {
            if let bundleID = entry.sourceBundle {
                appIcon = AppIconCache.shared.icon(forBundle: bundleID)
            }
        }
    }

    private func preview(_ s: String) -> String {
        let collapsed = s.replacingOccurrences(of: "\n", with: " ⏎ ")
        if collapsed.count <= 160 { return collapsed }
        return String(collapsed.prefix(160)) + "…"
    }

    private func relativeTime(_ d: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: d, relativeTo: Date())
    }
}

struct SearchField: NSViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    var onSubmit: () -> Void
    var onEscape: () -> Void
    var onArrow: (ArrowDirection) -> Void
    var onCommandNumber: (Int) -> Void
    var onSpace: () -> Void
    var onPin: () -> Void
    var onDelete: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSTextField {
        let tf = NSTextField()
        tf.placeholderString = "Search clipboard history…"
        tf.font = NSFont.systemFont(ofSize: 18, weight: .regular)
        tf.isBordered = false
        tf.drawsBackground = false
        tf.focusRingType = .none
        tf.delegate = context.coordinator
        tf.target = context.coordinator
        tf.action = #selector(Coordinator.submit(_:))
        context.coordinator.attach(field: tf)
        DispatchQueue.main.async { tf.window?.makeFirstResponder(tf) }
        return tf
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        context.coordinator.parent = self
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        if isFocused {
            DispatchQueue.main.async {
                if nsView.window?.firstResponder !== nsView.currentEditor() {
                    nsView.window?.makeFirstResponder(nsView)
                }
            }
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: SearchField
        private weak var field: NSTextField?
        private var monitor: Any?

        init(_ parent: SearchField) { self.parent = parent }

        deinit { uninstall() }

        func attach(field: NSTextField) {
            self.field = field
            install()
        }

        private func install() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self = self else { return event }
                return self.route(event)
            }
        }

        private func uninstall() {
            if let m = monitor {
                NSEvent.removeMonitor(m)
                monitor = nil
            }
        }

        /// Pre-empts the field editor for navigation/action keys; lets typed text fall through.
        private func route(_ event: NSEvent) -> NSEvent? {
            guard let field = field,
                  let window = field.window,
                  window.isKeyWindow else { return event }

            let isEmpty = field.stringValue.isEmpty
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let hasCmd = flags.contains(.command)
            let onlyCmd = flags.subtracting(.command).isEmpty

            switch event.keyCode {
            case 125:                                  // ↓
                parent.onArrow(.down); return nil
            case 126:                                  // ↑
                parent.onArrow(.up); return nil
            case 53:                                   // esc
                parent.onEscape(); return nil
            case 36, 76:                               // return / numpad enter
                parent.onSubmit(); return nil
            case 49 where isEmpty && flags.isEmpty:    // space (only when search is empty)
                parent.onSpace(); return nil
            case 51 where hasCmd && isEmpty:           // ⌘⌫ (only when search is empty)
                parent.onDelete(); return nil
            default:
                break
            }

            if hasCmd, onlyCmd, let chars = event.charactersIgnoringModifiers {
                if chars.lowercased() == "p" {
                    parent.onPin()
                    return nil
                }
                if let n = Int(chars), n >= 1, n <= 9 {
                    parent.onCommandNumber(n)
                    return nil
                }
            }
            return event
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let tf = obj.object as? NSTextField else { return }
            parent.text = tf.stringValue
        }

        @objc func submit(_ sender: Any?) {
            parent.onSubmit()
        }
    }
}
