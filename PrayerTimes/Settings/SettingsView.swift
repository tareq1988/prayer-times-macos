import SwiftUI

/// Tabbed settings container (spec §7.6). Each tab edits the shared
/// `SettingsStore`, which persists on every change and feeds `PrayerClock`.
struct SettingsView: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        TabView {
            GeneralTab(settings: settings)
                .tabItem { Label("General", systemImage: "gearshape") }
            LocationTimeTab(settings: settings)
                .tabItem { Label("Location & Time", systemImage: "location") }
            CalculationTab(settings: settings)
                .tabItem { Label("Calculation", systemImage: "moon.circle") }
            NotificationsTab(settings: settings)
                .tabItem { Label("Notifications", systemImage: "bell") }
        }
        .frame(width: 500)
    }
}
