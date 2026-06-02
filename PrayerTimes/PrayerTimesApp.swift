import SwiftUI

/// App entry point. A menu bar agent (no Dock icon, `LSUIElement` in Info.plist)
/// with a `.window`-style `MenuBarExtra`. The Settings window is managed directly
/// by `SettingsWindowManager` (see that type for why we avoid the SwiftUI
/// `Settings` scene in an agent app).
@main
struct PrayerTimesApp: App {
    @State private var settings: SettingsStore
    @State private var clock: PrayerClock
    private let settingsWindow: SettingsWindowManager

    init() {
        let settings = SettingsStore()
        _settings = State(initialValue: settings)
        _clock = State(initialValue: PrayerClock(settings: settings))
        settingsWindow = SettingsWindowManager(settings: settings)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarPanel(clock: clock, openSettings: { settingsWindow.show() })
        } label: {
            MenuBarLabel(clock: clock, settings: settings)
        }
        .menuBarExtraStyle(.window)
    }
}
