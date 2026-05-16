import AppKit
import SwiftUI
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate {

    private let updater = Updater.shared

    private var statusItem: NSStatusItem!
    private var panelController: PanelController!
    private var watcher: ClipboardWatcher!
    private var hotkey: GlobalHotkey?
    private var prefsWindow: NSWindow?
    private var statsWindow: NSWindow?

    let store = HistoryStore()
    private let settings = Settings.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()

        // Push Settings-controlled retention into the store.
        store.applySettings()

        panelController = PanelController(store: store)

        watcher = ClipboardWatcher(store: store)
        watcher.start()

        rebindHotkey()
        NotificationCenter.default.addObserver(
            self, selector: #selector(rebindHotkey),
            name: .clipMateHotkeyChanged, object: nil)

        updateStatusIcon()
        maybeShowOnboarding()
    }

    private func maybeShowOnboarding() {
        guard !settings.hasCompletedOnboarding else { return }
        // Defer so the status bar item is fully visible first, and run NON-modally
        // so the pasteboard watcher Timer (which uses default/common runloop modes)
        // keeps firing while the welcome is visible.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.showOnboardingPanel()
        }
    }

    private var onboardingWindow: NSWindow?

    private func showOnboardingPanel() {
        let hotkey = settings.hotkey.displayString
        let view = OnboardingView(hotkeyDisplay: hotkey,
                                  onDismiss: { [weak self] openPrefs in
            self?.settings.hasCompletedOnboarding = true
            self?.onboardingWindow?.close()
            self?.onboardingWindow = nil
            if openPrefs { self?.openPreferences() }
        })
        let host = NSHostingController(rootView: view)
        let w = NSWindow(contentViewController: host)
        w.title = "Welcome to Mnemo"
        w.styleMask = [.titled, .closable]
        w.isReleasedWhenClosed = false
        w.level = .floating
        w.center()
        onboardingWindow = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }

    @objc private func rebindHotkey() {
        hotkey = nil // triggers deinit -> UnregisterEventHotKey
        let cfg = settings.hotkey
        hotkey = GlobalHotkey(keyCode: cfg.keyCode, modifiers: cfg.modifiers) { [weak self] in
            self?.togglePanel()
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard",
                                   accessibilityDescription: "Mnemo")
            button.image?.isTemplate = true
        }

        let menu = NSMenu()

        let open = NSMenuItem(title: "Open History  \(settings.hotkey.displayString)",
                              action: #selector(togglePanelMenu),
                              keyEquivalent: "")
        open.target = self
        menu.addItem(open)

        menu.addItem(.separator())

        let pause = NSMenuItem(title: "Pause Capture",
                               action: #selector(togglePause),
                               keyEquivalent: "")
        pause.target = self
        menu.addItem(pause)

        let clear = NSMenuItem(title: "Clear History…",
                               action: #selector(clearHistory),
                               keyEquivalent: "")
        clear.target = self
        menu.addItem(clear)

        menu.addItem(.separator())

        let stats = NSMenuItem(title: "Stats…",
                               action: #selector(openStats),
                               keyEquivalent: "")
        stats.target = self
        menu.addItem(stats)

        let prefs = NSMenuItem(title: "Preferences…",
                               action: #selector(openPreferences),
                               keyEquivalent: ",")
        prefs.target = self
        menu.addItem(prefs)

        let about = NSMenuItem(title: "About Mnemo",
                               action: #selector(showAbout),
                               keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        let checkUpdates = NSMenuItem(title: "Check for Updates…",
                                      action: #selector(Updater.checkForUpdates(_:)),
                                      keyEquivalent: "")
        checkUpdates.target = updater
        menu.addItem(checkUpdates)

        menu.addItem(NSMenuItem(title: "Quit Mnemo",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))

        statusItem.menu = menu
    }

    private func updateStatusIcon() {
        guard let button = statusItem.button else { return }
        let symbol = store.captureEnabled ? "doc.on.clipboard" : "doc.on.clipboard.fill"
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Mnemo")
        button.image?.isTemplate = true
        button.appearsDisabled = !store.captureEnabled
    }

    @objc private func togglePanelMenu() { togglePanel() }

    private func togglePanel() {
        panelController.toggle()
    }

    @objc private func togglePause() {
        store.captureEnabled.toggle()
        for item in statusItem.menu?.items ?? [] {
            if item.title == "Pause Capture" || item.title == "Resume Capture" {
                item.title = store.captureEnabled ? "Pause Capture" : "Resume Capture"
            }
        }
        updateStatusIcon()
    }

    @objc private func clearHistory() {
        let alert = NSAlert()
        alert.messageText = "Clear all clipboard history?"
        alert.informativeText = "This deletes every saved clip from this Mac. This cannot be undone."
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            store.clearAll()
        }
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Mnemo"
        alert.informativeText = "A tiny local clipboard history for macOS.\n\nHotkey: \(settings.hotkey.displayString)\nHistory is stored locally, never uploaded."
        alert.runModal()
    }

    @objc private func openStats() {
        if let w = statsWindow {
            NSApp.activate(ignoringOtherApps: true)
            w.makeKeyAndOrderFront(nil)
            return
        }
        let host = NSHostingController(rootView: StatsView(store: store))
        let window = NSWindow(contentViewController: host)
        window.title = "Mnemo Stats"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.center()
        statsWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func openPreferences() {
        if let w = prefsWindow {
            NSApp.activate(ignoringOtherApps: true)
            w.makeKeyAndOrderFront(nil)
            return
        }
        let host = NSHostingController(rootView: PreferencesView())
        let window = NSWindow(contentViewController: host)
        window.title = "Mnemo Preferences"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        prefsWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
