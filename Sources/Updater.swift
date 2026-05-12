import Sparkle

/// Thin wrapper around `SPUStandardUpdaterController` so AppDelegate stays tidy.
///
/// Sparkle reads `SUFeedURL` and `SUPublicEDKey` from Info.plist. Updates are
/// EdDSA-signed; the matching private key lives only in the repo's GitHub
/// Actions secret `SPARKLE_ED_PRIVATE_KEY`.
final class Updater: NSObject {

    static let shared = Updater()

    private let controller: SPUStandardUpdaterController

    private override init() {
        // startingUpdater: true asks Sparkle to begin its scheduled checks immediately.
        // delegate / userDriverDelegate left nil → default behaviour (we don't need custom UI).
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
    }

    /// Action wired to the "Check for Updates…" menu item.
    @objc func checkForUpdates(_ sender: Any?) {
        controller.checkForUpdates(sender)
    }
}
