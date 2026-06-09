import SwiftUI
import PrayerKit

/// General settings (spec §7.6): launch at login, menu bar label style, language
/// override, and the automatic-update toggle.
struct GeneralTab: View {
    @Bindable var settings: SettingsStore
    let updates: UpdateService
    @State private var loginError: String?

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: launchAtLoginBinding)
                if let loginError {
                    Text(loginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Menu bar") {
                Picker("Label style", selection: $settings.settings.menuBarStyle) {
                    ForEach(MenuBarStyle.allCases, id: \.self) { style in
                        Text(PrayerFormatting.menuBarStyleName(style)).tag(style)
                    }
                }
                if settings.settings.menuBarStyle.value == .countdown {
                    Picker("Countdown shows", selection: $settings.settings.menuBarCountdownMode) {
                        ForEach(MenuBarCountdownMode.allCases, id: \.self) { mode in
                            Text(PrayerFormatting.countdownModeName(mode)).tag(mode)
                        }
                    }
                }
            }

            Section("Panel") {
                Toggle("Show Ishraq time", isOn: $settings.settings.showIshraqTime)
                Toggle("Show Hijri date", isOn: $settings.settings.showHijriDate)
            }

            Section("Language") {
                Picker("Language", selection: languageBinding) {
                    Text("Follow system").tag(String?.none)
                    Text(verbatim: "English").tag(String?.some("en"))
                    Text(verbatim: "العربية").tag(String?.some("ar"))
                    Text(verbatim: "Türkçe").tag(String?.some("tr"))
                    Text(verbatim: "বাংলা").tag(String?.some("bn"))
                }
                Text("Changing the language relaunches the app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Updates") {
                Toggle("Check for updates automatically", isOn: autoUpdateBinding)
            }
        }
        .formStyle(.grouped)
        .onAppear { settings.settings.launchAtLogin = LoginItemService.isEnabled }
    }

    // MARK: Bindings

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { settings.settings.launchAtLogin },
            set: { enabled in
                do {
                    try LoginItemService.setEnabled(enabled)
                    settings.settings.launchAtLogin = enabled
                    loginError = nil
                } catch {
                    loginError = String(localized: "Couldn't update login item: \(error.localizedDescription)")
                }
            }
        )
    }

    private var autoUpdateBinding: Binding<Bool> {
        Binding(
            get: { settings.settings.autoUpdateEnabled },
            set: { enabled in
                settings.settings.autoUpdateEnabled = enabled
                updates.automaticallyChecksForUpdates = enabled
            }
        )
    }

    private var languageBinding: Binding<String?> {
        Binding(
            get: { settings.settings.languageOverride },
            set: { code in
                guard code != settings.settings.languageOverride else { return }
                settings.applyLanguageOverride(code)   // persists + relaunches
            }
        )
    }
}
