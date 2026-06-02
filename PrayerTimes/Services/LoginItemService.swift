import Foundation
import ServiceManagement

/// Thin wrapper over the modern login-item API (`SMAppService.mainApp`, macOS 13+,
/// spec §3). Registering adds the app as a launch-at-login agent; the status is
/// read back from the system so the toggle reflects reality.
///
/// Note: during local development the app runs from DerivedData, where macOS may
/// refuse registration (the binary isn't in /Applications). Errors are surfaced,
/// not swallowed, so the UI can show them; the released, installed app registers
/// normally.
enum LoginItemService {

    /// Whether the app is currently registered to launch at login.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Register or unregister the app as a login item.
    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
