import SwiftUI
import PrayerKit

/// General settings (spec §7.6): launch at login, menu bar label style, language
/// override, and the automatic-update toggle.
struct GeneralTab: View {
    @Bindable var settings: SettingsStore
    @State private var loginError: String?

    var body: some View {
        Form {
            Section {
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
            }

            Section("Language") {
                Picker("Language", selection: languageBinding) {
                    Text("Follow system").tag(String?.none)
                    Text("English").tag(String?.some("en"))
                    Text("العربية").tag(String?.some("ar"))
                    Text("Türkçe").tag(String?.some("tr"))
                    Text("বাংলা").tag(String?.some("bn"))
                }
                Text("Full localization arrives in a later build.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Updates") {
                Toggle("Check for updates automatically", isOn: $settings.settings.autoUpdateEnabled)
                Text("Automatic updates are enabled in a later build.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                    loginError = "Couldn't update login item: \(error.localizedDescription)"
                }
            }
        )
    }

    private var languageBinding: Binding<String?> {
        Binding(
            get: { settings.settings.languageOverride },
            set: { settings.settings.languageOverride = $0 }
        )
    }
}
