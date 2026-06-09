import SwiftUI
import PrayerKit

/// Focus Mode settings (issue #2): cover the screen at each obligatory prayer for
/// a set duration as a gentle discipline aid. Mirrors the reference layout —
/// enable, duration, blur intensity, emergency exit — plus a "Try it" preview so
/// the user can see the overlay and confirm the emergency exit before relying on it.
struct FocusModeTab: View {
    @Bindable var settings: SettingsStore
    let focus: FocusModeController

    private var enabled: Bool { settings.settings.focusModeEnabled }

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $settings.settings.focusModeEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable Focus Mode")
                        Text("Covers the entire screen during prayer time")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            if enabled {
                Section("Behaviour") {
                    LabeledContent("Prayer duration") {
                        HStack(spacing: 8) {
                            Text(durationLabel)
                            Stepper("", value: $settings.settings.focusDurationMinutes, in: 2...45)
                                .labelsHidden()
                        }
                    }

                    Picker("Blur intensity", selection: $settings.settings.focusBlurIntensity) {
                        ForEach(FocusBlurIntensity.allCases, id: \.self) { level in
                            Text(PrayerFormatting.blurIntensityName(level)).tag(level)
                        }
                    }

                    Picker("Trigger on", selection: $settings.settings.focusTrigger) {
                        ForEach(FocusTrigger.allCases, id: \.self) { trigger in
                            Text(PrayerFormatting.focusTriggerName(trigger)).tag(trigger)
                        }
                    }

                    Toggle(isOn: $settings.settings.focusEmergencyExitEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Emergency exit")
                            Text("Allow ⌘ Esc to exit early")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Button {
                        focus.runDemo(settings: settings.settings)
                    } label: {
                        Label("Try it for 10 seconds", systemImage: "eye")
                    }
                }

                Section {
                    Label {
                        Text("Focus Mode covers your whole screen at each obligatory prayer. It's a discipline aid, not a lock — Force Quit always works, and it won't engage while a fullscreen app (a call or presentation) is frontmost.")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var durationLabel: String {
        let m = settings.settings.focusDurationMinutes
        return "\(m) " + (m == 1 ? String(localized: "minute") : String(localized: "minutes"))
    }
}
