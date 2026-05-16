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
    var onPickFilled: ((ClipEntry, String) -> Void)? = nil
    var onDismiss: () -> Void
    var onExcludeApp: ((String) -> Void)?

    @Environment(\.displayScale) private var displayScale

    @State private var query: String = ""
    @State private var selectionIndex: Int = 0
    @State private var previewing: ClipEntry?
    @State private var isSearchFocused: Bool = true
    @State private var scrollToTopToken: Int = 0
    @State private var templateEntry: ClipEntry? = nil
    @State private var templatePlaceholders: [SnippetPlaceholder] = []
    @State private var templateValues: [String: String] = [:]

    private var filtered: [ClipEntry] {
        store.search(query)
    }

    var body: some View {
        let filteredEntries = filtered
        return Group {
            if let tEntry = templateEntry {
                SnippetFormView(
                    entry: tEntry,
                    placeholders: templatePlaceholders,
                    values: $templateValues,
                    onCommit: commitTemplate,
                    onCancel: cancelTemplate
                )
                .frame(minWidth: 600, minHeight: 400)
            } else {
                searchAndListBody(filteredEntries: filteredEntries)
            }
        }
        .onChange(of: query) { _, _ in selectionIndex = 0 }
        .onReceive(NotificationCenter.default.publisher(for: .clipMatePanelOpened)) { _ in
            query = ""
            selectionIndex = 0
            previewing = nil
            isSearchFocused = true
            scrollToTopToken &+= 1
            templateEntry = nil
            templatePlaceholders = []
            templateValues = [:]
        }
        .sheet(item: $previewing) { entry in
            QuickLookView(entry: entry) { previewing = nil }
        }
    }

    @ViewBuilder
    private func searchAndListBody(filteredEntries: [ClipEntry]) -> some View {
        VStack(spacing: 0) {
            SearchField(text: $query,
                        isFocused: $isSearchFocused,
                        onSubmit: commitSelection,
                        onEscape: handleEscape,
                        onArrow: handleArrow,
                        onCommandNumber: pickNumbered,
                        onSpace: togglePreview,
                        onPin: pinSelection,
                        onDelete: deleteSelection,
                        onOpen: openSelection)
                .frame(height: 26)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(
                            isSearchFocused
                                ? Color.accentColor.opacity(0.75)
                                : Color.primary.opacity(0.08),
                            lineWidth: 1 / displayScale
                        )
                )
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 8)

            Color(NSColor.separatorColor).frame(height: 1 / displayScale)

            Color.clear.frame(height: 6)

            if filteredEntries.isEmpty {
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
                    List(Array(filteredEntries.enumerated()), id: \.element.id) { idx, entry in
                        HistoryRow(entry: entry,
                                   query: query,
                                   index: idx,
                                   isSelected: idx == selectionIndex)
                            .id(entry.id)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) { pickEntry(entry) }
                            .onTapGesture { selectionIndex = idx }
                            .listRowInsets(EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6))
                    }
                    .listStyle(.plain)
                    .onChange(of: selectionIndex) { _, newValue in
                        guard newValue < filteredEntries.count else { return }
                        proxy.scrollTo(filteredEntries[newValue].id, anchor: .center)
                    }
                    .onChange(of: scrollToTopToken) { _, _ in
                        scrollToTop(proxy: proxy)
                    }
                    .onAppear { scrollToTop(proxy: proxy) }
                }
            }

            Color(NSColor.separatorColor).frame(height: 1 / displayScale)
            HStack(spacing: 12) {
                Text("↑↓ navigate").foregroundStyle(.secondary)
                Text("⏎ paste").foregroundStyle(.secondary)
                Text("␣ preview").foregroundStyle(.secondary)
                Text("⌘P pin").foregroundStyle(.secondary)
                Text("⌘⌫ delete").foregroundStyle(.secondary)
                if let action = quickActionLabel(for: filteredEntries) {
                    Text(action).foregroundStyle(.secondary)
                }
                Text("⌘1–9 quick").foregroundStyle(.secondary)
                Text("/url /json /pin /code /email /text /multiline").foregroundStyle(.tertiary)
                Text("⏎ on pinned {{template}} to fill").foregroundStyle(.tertiary)
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
                Text("\(filteredEntries.count) of \(store.entries.count)")
                    .foregroundStyle(.tertiary)
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    private func commitSelection() {
        guard !filtered.isEmpty else { return }
        let idx = min(max(0, selectionIndex), filtered.count - 1)
        pickEntry(filtered[idx])
    }

    private func pickEntry(_ entry: ClipEntry) {
        if entry.isPinned, SnippetTemplate.hasPlaceholders(entry.content) {
            beginTemplate(for: entry)
            return
        }
        onPick(entry)
    }

    private func beginTemplate(for entry: ClipEntry) {
        let phs = SnippetTemplate.placeholders(in: entry.content)
        guard !phs.isEmpty else { onPick(entry); return }
        templatePlaceholders = phs
        templateValues = Dictionary(uniqueKeysWithValues: phs.map { ($0.name, "") })
        templateEntry = entry
    }

    private func commitTemplate() {
        guard let entry = templateEntry else { return }
        let filled = SnippetTemplate.fill(entry.content, with: templateValues)
        let pick = onPickFilled ?? { e, _ in onPick(e) }
        templateEntry = nil
        templatePlaceholders = []
        templateValues = [:]
        pick(entry, filled)
    }

    private func cancelTemplate() {
        templateEntry = nil
        templatePlaceholders = []
        templateValues = [:]
        isSearchFocused = true
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
            pickEntry(filtered[idx])
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
        selectionIndex = max(0, min(selectionIndex, filtered.count - 2))
    }

    /// Footer hint for the contextual ⌘O quick action, if the selected entry has one.
    private func quickActionLabel(for entries: [ClipEntry]) -> String? {
        guard !entries.isEmpty, selectionIndex < entries.count else { return nil }
        return QuickAction.label(for: entries[selectionIndex])
    }

    private func openSelection() {
        guard !filtered.isEmpty, selectionIndex < filtered.count else { return }
        let entry = filtered[selectionIndex]
        if QuickAction.perform(for: entry) {
            store.useEntry(entry)
            onDismiss()
        } else if entry.type == .json {
            previewing = entry
        }
    }

    private func scrollToTop(proxy: ScrollViewProxy) {
        guard let firstID = filtered.first?.id else { return }
        // Defer to the next runloop so the List finishes its initial layout
        // before we try to scroll — otherwise the first row can render
        // clipped under the search bar on panel open.
        DispatchQueue.main.async {
            proxy.scrollTo(firstID, anchor: .top)
        }
    }
}

struct QuickLookView: View {
    let entry: ClipEntry
    var onClose: () -> Void

    @Environment(\.displayScale) private var displayScale

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
            Color(NSColor.separatorColor).frame(height: 1 / displayScale)
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
    var onOpen: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSTextField {
        let tf = NSTextField()
        tf.font = NSFont.systemFont(ofSize: 18, weight: .regular)
        tf.placeholderAttributedString = NSAttributedString(
            string: "Search clipboard history…",
            attributes: [
                .foregroundColor: NSColor.secondaryLabelColor,
                .font: tf.font ?? NSFont.systemFont(ofSize: 18, weight: .regular)
            ]
        )
        tf.textColor = NSColor.labelColor
        tf.isBordered = false
        tf.drawsBackground = false
        tf.focusRingType = .none
        tf.delegate = context.coordinator
        tf.target = context.coordinator
        tf.action = #selector(Coordinator.submit(_:))
        context.coordinator.attach(field: tf)
        if isFocused {
            DispatchQueue.main.async { tf.window?.makeFirstResponder(tf) }
        }
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
                if chars.lowercased() == "o" {
                    parent.onOpen()
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

        func controlTextDidBeginEditing(_ obj: Notification) {
            let parent = self.parent
            DispatchQueue.main.async { parent.isFocused = true }
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            let parent = self.parent
            DispatchQueue.main.async { parent.isFocused = false }
        }

        @objc func submit(_ sender: Any?) {
            parent.onSubmit()
        }
    }
}

// MARK: - Snippet template form

struct SnippetFormView: View {
    let entry: ClipEntry
    let placeholders: [SnippetPlaceholder]
    @Binding var values: [String: String]
    var onCommit: () -> Void
    var onCancel: () -> Void

    @Environment(\.displayScale) private var displayScale
    @FocusState private var focused: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "pin.fill").foregroundStyle(.orange)
                Text("Fill in template").font(.headline)
                Spacer()
                Text("Tab next \u{00B7} Return paste \u{00B7} Esc cancel")
                    .font(.caption).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Color(NSColor.separatorColor).frame(height: 1 / displayScale)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(placeholders.enumerated()), id: \.element.name) { idx, p in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(p.name)
                                    .font(.system(.caption, design: .monospaced).bold())
                                    .foregroundStyle(.secondary)
                                if let def = p.defaultValue, !def.isEmpty {
                                    Text("default: \(def)")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            TextField(p.defaultValue ?? "Value for \(p.name)", text: bindingFor(p.name))
                                .textFieldStyle(.roundedBorder)
                                .focused($focused, equals: p.name)
                                .onSubmit { advanceOrCommit(from: idx) }
                        }
                    }
                }
                .padding(14)
            }

            Color(NSColor.separatorColor).frame(height: 1 / displayScale)

            VStack(alignment: .leading, spacing: 6) {
                Text("Preview").font(.caption).foregroundStyle(.secondary)
                ScrollView {
                    Text(SnippetTemplate.fill(entry.content, with: values))
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(NSColor.textBackgroundColor).opacity(0.6))
                        )
                }
                .frame(maxHeight: 120)
            }
            .padding(14)

            Color(NSColor.separatorColor).frame(height: 1 / displayScale)

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Paste", action: onCommit)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .onAppear {
            focused = placeholders.first?.name
        }
    }

    private func bindingFor(_ name: String) -> Binding<String> {
        Binding(
            get: { values[name] ?? "" },
            set: { values[name] = $0 }
        )
    }

    private func advanceOrCommit(from idx: Int) {
        let next = idx + 1
        if next < placeholders.count {
            focused = placeholders[next].name
        } else {
            onCommit()
        }
    }
}
