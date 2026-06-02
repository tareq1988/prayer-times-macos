import SwiftUI

/// App entry point. A menu bar agent (no Dock icon, `LSUIElement` in Info.plist)
/// with a `.window`-style `MenuBarExtra` and a Settings scene.
///
/// M2: the menu bar shell driven by a hardcoded location/method via `PrayerClock`.
/// M3 fills in the real Settings tabs and persistence.
@main
struct PrayerTimesApp: App {
    @State private var clock = PrayerClock()

    var body: some Scene {
        MenuBarExtra {
            MenuBarPanel(clock: clock)
        } label: {
            MenuBarLabel(clock: clock)
        }
        .menuBarExtraStyle(.window)

        Settings {
            PlaceholderSettingsView()
        }
    }
}

/// Temporary Settings content until the tabbed settings land in M3 (spec §7.6).
private struct PlaceholderSettingsView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Settings")
                .font(.title2)
            Text("Calculation, location, and notification settings arrive in a later build.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(width: 420, height: 200)
    }
}
