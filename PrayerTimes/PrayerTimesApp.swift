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
    private let onboarding: OnboardingWindowManager
    private let updates = UpdateService()

    init() {
        let location = LocationService()
        let settings = SettingsStore(location: location)
        let library = CustomAdhanLibrary()
        let audio = AudioService(library: library)
        let notifications = NotificationService(audio: audio)
        let focus = FocusModeController()
        _settings = State(initialValue: settings)
        _clock = State(initialValue: PrayerClock(settings: settings, notifications: notifications, audio: audio, focus: focus))
        let onboarding = OnboardingWindowManager(settings: settings, notifications: notifications)
        self.onboarding = onboarding

        // Let the General tab relaunch the setup wizard at any time.
        settingsWindow = SettingsWindowManager(settings: settings, audio: audio, updates: updates, notifications: notifications, focus: focus, library: library, runSetupAgain: { onboarding.restart() })

        // Mirror the persisted preference into Sparkle.
        updates.automaticallyChecksForUpdates = settings.settings.autoUpdateEnabled

        // Auto-detect on launch when the user is in automatic mode (spec §7.7).
        Task { await settings.detectLocationIfNeeded() }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarPanel(
                clock: clock,
                openSettings: { settingsWindow.show() },
                checkForUpdates: { updates.checkForUpdates() }
            )
        } label: {
            // The label renders at launch, so its `.task` is a reliable hook to
            // present the first-run wizard once the app is up.
            MenuBarLabel(clock: clock, settings: settings)
                .task { onboarding.showIfNeeded() }
        }
        .menuBarExtraStyle(.window)
    }
}
