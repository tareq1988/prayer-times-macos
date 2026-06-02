import Foundation
import Sparkle

/// Thin wrapper around Sparkle's standard updater (spec §7.8). The app is
/// unsandboxed (spec §12), so Sparkle needs no XPC services or extra
/// entitlements — just `SUFeedURL` + `SUPublicEDKey` in Info.plist.
///
/// Releases are EdDSA-signed; updates are delivered via an appcast hosted on
/// GitHub (see .github/workflows/release.yml and RELEASING.md).
@MainActor
final class UpdateService {
    private let controller: SPUStandardUpdaterController

    init() {
        // startingUpdater: true begins automatic background checks per the
        // user's preference (mirrored from AppSettings.autoUpdateEnabled).
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    /// Present the "Check for Updates" flow (menu action).
    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }

    /// Whether a check can run right now (e.g. not already in progress).
    var canCheckForUpdates: Bool {
        controller.updater.canCheckForUpdates
    }

    /// Mirror of the user's "check automatically" preference.
    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }
}
