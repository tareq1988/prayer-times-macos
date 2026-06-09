import SwiftUI
import AppKit
import UserNotifications
import PrayerKit

/// Notification settings (spec §7.3, §7.4, design: Notifications tab). Reorganized
/// into three parts so per-prayer settings stop repeating the same five fields:
/// a **Master** switch + sample, a **Defaults** group applied to every prayer, and
/// a per-prayer **matrix** (Notify / Adhan / Remind) whose rows expand into an
/// override drawer. Per-prayer Sound / Early reminder / Iqamah inherit the
/// defaults until explicitly overridden.
struct NotificationsTab: View {
    @Bindable var settings: SettingsStore
    let audio: AudioService
    let notifications: NotificationService

    /// Prayers shown in the matrix, in order (Ishraq is panel-only, not notified).
    private let matrixPrayers: [Prayer] = [.fajr, .sunrise, .dhuhr, .asr, .maghrib, .isha]

    @State private var expanded: Set<Prayer> = []

    private var masterOn: Bool { settings.settings.masterNotificationsEnabled }

    var body: some View {
        Form {
            if let hint = systemPermissionHint {
                Section {
                    Label { Text(hint.message) } icon: {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    }
                    .font(.callout)
                    if hint.showsSystemSettingsButton {
                        Button("Open System Settings") { Self.openNotificationSettings() }
                    }
                }
            }

            Section {
                Toggle(isOn: $settings.settings.masterNotificationsEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable notifications")
                        Text("Master switch for all prayer alerts.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Spacer()
                    Button {
                        Task { await notifications.sendSampleNotification() }
                    } label: {
                        Label("Send a sample notification", systemImage: "bell.badge")
                    }
                }
            }

            defaultsSection.disabled(!masterOn)
            matrixSection.disabled(!masterOn)
        }
        .formStyle(.grouped)
        .task { await notifications.refreshAuthorizationStatus() }
    }

    // MARK: Defaults

    private var defaultsSection: some View {
        Section {
            LabeledContent("Default sound") {
                HStack(spacing: 6) {
                    previewButton(settings.settings.notificationDefaults.sound)
                    Picker("", selection: $settings.settings.notificationDefaults.sound) {
                        ForEach(NotificationSound.allCases, id: \.self) { sound in
                            Text(PrayerFormatting.soundName(sound)).tag(sound)
                        }
                    }
                    .labelsHidden().fixedSize()
                }
            }
            Toggle("Play full Adhan audio", isOn: $settings.settings.notificationDefaults.playFullAdhan)
            Picker("Early reminder", selection: $settings.settings.notificationDefaults.earlyReminderMinutes) {
                ForEach(Self.reminderOptions, id: \.self) { m in
                    Text(Self.reminderLabel(m)).tag(m)
                }
            }
            Stepper(value: $settings.settings.notificationDefaults.iqamahOffsetMinutes, in: 0...45) {
                HStack {
                    Text("Iqamah / jamaat offset")
                    Spacer(minLength: 12)
                    Text(Self.offsetLabel(settings.settings.notificationDefaults.iqamahOffsetMinutes))
                        .monospacedDigit().foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Defaults")
        } footer: {
            Text("Applied to every prayer. Expand a prayer below to override its sound, reminder, or iqamah.")
        }
    }

    // MARK: Per-prayer matrix

    private var matrixSection: some View {
        Section("Per prayer") {
            // Column headers.
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                ForEach(["Notify", "Adhan", "Remind"], id: \.self) { title in
                    Text(title).frame(width: Self.colWidth)
                }
                Spacer().frame(width: Self.gearWidth)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.tertiary)
            .textCase(.uppercase)

            ForEach(matrixPrayers, id: \.self) { prayer in
                matrixRow(prayer)
                if expanded.contains(prayer), prayer != .sunrise {
                    overrideDrawer(prayer)
                }
            }
        }
    }

    private func matrixRow(_ prayer: Prayer) -> some View {
        let cfg = configBinding(for: prayer)
        return HStack(spacing: 0) {
            Label(PrayerFormatting.name(prayer), systemImage: PrayerFormatting.icon(prayer))
                .frame(maxWidth: .infinity, alignment: .leading)

            // Notify
            Toggle("", isOn: cfg.notify).labelsHidden().controlSize(.mini)
                .frame(width: Self.colWidth)

            // Adhan (obligatory only)
            Group {
                if prayer.isObligatory {
                    Toggle("", isOn: cfg.playFullAdhan).labelsHidden().controlSize(.mini)
                } else {
                    Text("—").foregroundStyle(.tertiary)
                }
            }
            .frame(width: Self.colWidth)

            // Remind
            Toggle("", isOn: remindBinding(for: prayer)).labelsHidden().controlSize(.mini)
                .frame(width: Self.colWidth)

            // Override disclosure (obligatory only — Sunrise has nothing to override)
            Group {
                if prayer != .sunrise {
                    Button {
                        withAnimation(.snappy(duration: 0.15)) { toggleExpanded(prayer) }
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundStyle(expanded.contains(prayer) ? Color.accentColor : .secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Per-prayer overrides")
                } else {
                    Color.clear
                }
            }
            .frame(width: Self.gearWidth)
        }
        .toggleStyle(.switch)
    }

    /// Inline override drawer: Sound, Early reminder, and Iqamah — each able to
    /// inherit the default (nil sentinel) or take a per-prayer value.
    private func overrideDrawer(_ prayer: Prayer) -> some View {
        let cfg = configBinding(for: prayer)
        return VStack(spacing: 8) {
            LabeledContent("Sound") {
                HStack(spacing: 6) {
                    previewButton(cfg.soundOverride.wrappedValue ?? settings.settings.notificationDefaults.sound)
                    Picker("", selection: cfg.soundOverride) {
                        Text(inheritLabel(PrayerFormatting.soundName(settings.settings.notificationDefaults.sound)))
                            .tag(NotificationSound?.none)
                        ForEach(NotificationSound.allCases, id: \.self) { sound in
                            Text(PrayerFormatting.soundName(sound)).tag(NotificationSound?.some(sound))
                        }
                    }
                    .labelsHidden().fixedSize()
                }
            }
            Picker("Early reminder", selection: cfg.earlyLeadMinutesOverride) {
                Text(inheritLabel(Self.reminderLabel(settings.settings.notificationDefaults.earlyReminderMinutes)))
                    .tag(Int?.none)
                ForEach(Self.reminderOptions, id: \.self) { m in
                    Text(Self.reminderLabel(m)).tag(Int?.some(m))
                }
            }
            Picker("Iqamah / jamaat offset", selection: cfg.iqamahOffsetMinutesOverride) {
                Text(inheritLabel(Self.offsetLabel(settings.settings.notificationDefaults.iqamahOffsetMinutes)))
                    .tag(Int?.none)
                ForEach(Self.iqamahOptions, id: \.self) { m in
                    Text(Self.offsetLabel(m)).tag(Int?.some(m))
                }
            }
        }
        .padding(.leading, 24)
        .font(.callout)
    }

    private func previewButton(_ sound: NotificationSound) -> some View {
        Button {
            if audio.isPlaying { audio.stop() } else { audio.preview(sound) }
        } label: {
            Image(systemName: audio.isPlaying ? "stop.circle" : "play.circle")
        }
        .buttonStyle(.borderless)
        .help(audio.isPlaying ? "Stop" : "Preview sound")
        .disabled(sound == .none)
    }

    private func toggleExpanded(_ prayer: Prayer) {
        if expanded.contains(prayer) { expanded.remove(prayer) } else { expanded.insert(prayer) }
    }

    // MARK: Layout / option constants

    private static let colWidth: CGFloat = 52
    private static let gearWidth: CGFloat = 28
    private static let reminderOptions = [0, 5, 10, 15, 30]
    private static let iqamahOptions = [0, 5, 10, 15, 20, 25, 30, 45]

    private static func reminderLabel(_ m: Int) -> String {
        m == 0 ? String(localized: "Off") : String(localized: "\(m) min before")
    }
    private static func offsetLabel(_ m: Int) -> String {
        m == 0 ? String(localized: "Off") : String(localized: "+\(m) min")
    }

    // MARK: Bindings & helpers

    private func configBinding(for prayer: Prayer) -> Binding<PrayerNotificationConfig> {
        Binding(
            get: { settings.settings.notifications[prayer] ?? PrayerNotificationConfig() },
            set: { settings.settings.notifications[prayer] = $0 }
        )
    }

    /// The matrix "Remind" toggle. Enabling it when the effective lead is 0 (the
    /// global default is Off and the prayer has no override of its own) seeds a
    /// concrete per-prayer lead so the reminder actually fires — and the drawer
    /// shows that real value instead of a contradictory "inherit Off".
    private func remindBinding(for prayer: Prayer) -> Binding<Bool> {
        Binding(
            get: { settings.settings.notifications[prayer]?.earlyReminderEnabled ?? false },
            set: { on in
                var cfg = settings.settings.notifications[prayer] ?? PrayerNotificationConfig()
                cfg.earlyReminderEnabled = on
                if on, settings.settings.earlyLeadMinutes(for: prayer) <= 0 {
                    cfg.earlyLeadMinutesOverride = AppSettings.fallbackEarlyLeadMinutes
                }
                settings.settings.notifications[prayer] = cfg
            }
        )
    }

    /// "Inherit default (<value>)" — so the inheriting option is never ambiguous
    /// about what it currently resolves to.
    private func inheritLabel(_ resolved: String) -> String {
        String(localized: "Inherit default (\(resolved))")
    }

    /// In-app explanation when notifications won't appear because macOS hasn't
    /// granted permission — so the user isn't left wondering why nothing fires.
    private var systemPermissionHint: (message: LocalizedStringKey, showsSystemSettingsButton: Bool)? {
        switch notifications.authorizationStatus {
        case .denied:
            return ("macOS is blocking notifications for Prayer Times. Enable them in System Settings → Notifications to receive prayer alerts.",
                    true)
        case .notDetermined:
            return ("Prayer Times hasn't been granted notification permission yet. Send a sample notification below to trigger the macOS prompt.",
                    false)
        default:
            return nil
        }
    }

    private static func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }
}
