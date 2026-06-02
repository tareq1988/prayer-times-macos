import SwiftUI

/// App entry point. A menu bar agent (no Dock icon, `LSUIElement` in Info.plist)
/// with a `.window`-style `MenuBarExtra` and a tabbed Settings scene.
@main
struct PrayerTimesApp: App {
    @State private var settings: SettingsStore
    @State private var clock: PrayerClock

    init() {
        let settings = SettingsStore()
        _settings = State(initialValue: settings)
        _clock = State(initialValue: PrayerClock(settings: settings))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarPanel(clock: clock)
        } label: {
            MenuBarLabel(clock: clock, settings: settings)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(settings: settings)
        }
    }
}
