import AppKit
import SwiftUI

final class PanelController {
    private let store: HistoryStore
    private var panel: NSPanel?
    private var previousApp: NSRunningApplication?

    init(store: HistoryStore) {
        self.store = store
    }

    func toggle() {
        if let p = panel, p.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        previousApp = NSWorkspace.shared.frontmostApplication

        let panel = self.panel ?? makePanel()
        self.panel = panel

        if let screen = NSScreen.screens.first(where: {
            NSMouseInRect(NSEvent.mouseLocation, $0.frame, false)
        }) ?? NSScreen.main {
            let size = panel.frame.size
            let origin = NSPoint(
                x: screen.frame.midX - size.width / 2,
                y: screen.frame.midY - size.height / 2 + 80
            )
            panel.setFrameOrigin(origin)
        }

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .clipMatePanelOpened, object: nil)
    }

    func hide() {
        panel?.orderOut(nil)
        if let prev = previousApp {
            prev.activate()
        }
    }

    private func makePanel() -> NSPanel {
        let contentRect = NSRect(x: 0, y: 0, width: 640, height: 420)
        let panel = ClipMatePanel(
            contentRect: contentRect,
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        let content = HistoryPanel(store: store, onPick: { [weak self] entry in
            self?.commit(entry: entry)
        }, onDismiss: { [weak self] in
            self?.hide()
        })
        let host = NSHostingView(rootView: content)
        host.frame = contentRect
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        return panel
    }

    private func commit(entry: ClipEntry) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(entry.content, forType: .string)
        store.useEntry(entry)
        let shouldAutoPaste = Settings.shared.autoPasteOnEnter
        hide()
        if shouldAutoPaste {
            // Brief delay so focus has time to land back on the previous app.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                Paster.pasteCommandV()
            }
        }
    }
}

final class ClipMatePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

extension Notification.Name {
    static let clipMatePanelOpened = Notification.Name("ClipMatePanelOpened")
}
