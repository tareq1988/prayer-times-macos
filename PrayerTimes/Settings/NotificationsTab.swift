import SwiftUI
import PrayerKit

/// Notification settings (spec §7.3, §7.4): a master toggle plus the per-prayer
/// matrix — prayer-entry notification, early reminder, and iqamah, each with its
/// own sound. M3 owns the configuration surface; M4 wires the actual scheduling,
/// sound previews, and Stop-Adhan control.
struct NotificationsTab: View {
    @Bindable var settings: SettingsStore
    let audio: AudioService

    var body: some View {
        Form {
            Section {
                Toggle("Enable notifications", isOn: $settings.settings.masterNotificationsEnabled)
            }

            ForEach(Prayer.allCases, id: \.self) { prayer in
                Section(PrayerFormatting.name(prayer)) {
                    PrayerNotificationRow(prayer: prayer, config: config(for: prayer), audio: audio)
                }
                .disabled(!settings.settings.masterNotificationsEnabled)
            }
        }
        .formStyle(.grouped)
    }

    private func config(for prayer: Prayer) -> Binding<PrayerNotificationConfig> {
        Binding(
            get: { settings.settings.notifications[prayer] ?? PrayerNotificationConfig() },
            set: { settings.settings.notifications[prayer] = $0 }
        )
    }
}

/// One prayer's notification block.
private struct PrayerNotificationRow: View {
    let prayer: Prayer
    @Binding var config: PrayerNotificationConfig
    let audio: AudioService

    var body: some View {
        // Prayer-entry notification.
        Toggle("Prayer-time notification", isOn: $config.prayerNotificationEnabled)
        if config.prayerNotificationEnabled {
            soundPicker("Sound", selection: $config.prayerSound)
            if prayer.isObligatory {
                Toggle("Play full Adhan audio", isOn: $config.playFullAdhan)
            }
        }

        // Early reminder.
        Toggle("Early reminder", isOn: $config.earlyReminderEnabled)
        if config.earlyReminderEnabled {
            Stepper(value: $config.earlyLeadMinutes, in: 1...60) {
                HStack {
                    Text("Lead time")
                    Spacer(minLength: 12)
                    Text("\(config.earlyLeadMinutes) min").monospacedDigit().foregroundStyle(.secondary)
                }
            }
            soundPicker("Reminder sound", selection: $config.earlySound)
        }

        // Iqamah (obligatory prayers only — not Sunrise).
        if prayer.isObligatory {
            Stepper(value: $config.iqamahOffsetMinutes, in: 0...60) {
                HStack {
                    Text("Iqamah offset")
                    Spacer(minLength: 12)
                    Text(config.iqamahOffsetMinutes == 0 ? String(localized: "Off") : "+\(config.iqamahOffsetMinutes) min")
                        .monospacedDigit().foregroundStyle(.secondary)
                }
            }
            if config.iqamahOffsetMinutes > 0 {
                Toggle("Iqamah notification", isOn: $config.iqamahNotificationEnabled)
                if config.iqamahNotificationEnabled {
                    soundPicker("Iqamah sound", selection: $config.iqamahSound)
                }
            }
        }
    }

    private func soundPicker(_ title: LocalizedStringKey, selection: Binding<NotificationSound>) -> some View {
        HStack {
            Picker(title, selection: selection) {
                ForEach(NotificationSound.allCases, id: \.self) { sound in
                    Text(PrayerFormatting.soundName(sound)).tag(sound)
                }
            }
            Button {
                if audio.isPlaying { audio.stop() } else { audio.preview(selection.wrappedValue) }
            } label: {
                Image(systemName: audio.isPlaying ? "stop.circle" : "play.circle")
            }
            .buttonStyle(.borderless)
            .help(audio.isPlaying ? "Stop" : "Preview sound")
            .disabled(selection.wrappedValue == .none)
        }
    }
}
