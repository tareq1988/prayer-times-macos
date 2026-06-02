import SwiftUI
import PrayerKit

/// Notification settings (spec §7.3, §7.4): a master toggle plus the per-prayer
/// matrix — prayer-entry notification, early reminder, and iqamah, each with its
/// own sound. M3 owns the configuration surface; M4 wires the actual scheduling,
/// sound previews, and Stop-Adhan control.
struct NotificationsTab: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        Form {
            Section {
                Toggle("Enable notifications", isOn: $settings.settings.masterNotificationsEnabled)
                Text("Scheduling and Adhan playback are wired up in a later build.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(Prayer.allCases, id: \.self) { prayer in
                Section(PrayerFormatting.name(prayer)) {
                    PrayerNotificationRow(prayer: prayer, config: config(for: prayer))
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
                LabeledContent("Lead time", value: "\(config.earlyLeadMinutes) min")
            }
            soundPicker("Reminder sound", selection: $config.earlySound)
        }

        // Iqamah (obligatory prayers only — not Sunrise).
        if prayer.isObligatory {
            Stepper(value: $config.iqamahOffsetMinutes, in: 0...60) {
                LabeledContent("Iqamah offset",
                    value: config.iqamahOffsetMinutes == 0 ? "Off" : "+\(config.iqamahOffsetMinutes) min")
            }
            if config.iqamahOffsetMinutes > 0 {
                Toggle("Iqamah notification", isOn: $config.iqamahNotificationEnabled)
                if config.iqamahNotificationEnabled {
                    soundPicker("Iqamah sound", selection: $config.iqamahSound)
                }
            }
        }
    }

    private func soundPicker(_ title: String, selection: Binding<NotificationSound>) -> some View {
        Picker(title, selection: selection) {
            ForEach(NotificationSound.allCases, id: \.self) { sound in
                Text(PrayerFormatting.soundName(sound)).tag(sound)
            }
        }
    }
}
