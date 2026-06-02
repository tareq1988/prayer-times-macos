import Foundation
import UserNotifications
import PrayerKit
import OSLog

/// Schedules local notifications for the rolling today + tomorrow window
/// (spec §7.3, §7.4, §9): a prayer-entry notification, an optional early
/// reminder, and an optional iqamah notification per prayer — each with its own
/// sound. Stable identifiers per (day, prayer, type) mean re-scheduling replaces
/// rather than duplicates. Also acts as the notification-center delegate so
/// banners show while the agent is running and the Stop-Adhan action works.
@MainActor
final class NotificationService: NSObject {
    private let audio: AudioService
    private let center = UNUserNotificationCenter.current()
    private let log = Logger(subsystem: "com.wedevs.prayertimes", category: "notifications")

    private nonisolated static let adhanCategoryID = "PRAYER_ADHAN"
    private nonisolated static let stopAdhanActionID = "STOP_ADHAN"

    init(audio: AudioService) {
        self.audio = audio
        super.init()
        center.delegate = self
        registerCategories()
    }

    /// Request alert/sound/badge authorization (spec §7.3). Safe to call on launch.
    func requestAuthorization() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            log.notice("Notification authorization granted=\(granted)")
        } catch {
            log.error("Authorization error: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Replace all scheduled notifications with a fresh set for the given days.
    func reschedule(today: PrayerTimes, tomorrow: PrayerTimes, settings: AppSettings,
                    timeZone: TimeZone, now: Date) {
        center.removeAllPendingNotificationRequests()
        guard settings.masterNotificationsEnabled else {
            log.debug("Master notifications off; cleared schedule")
            return
        }

        var requests: [UNNotificationRequest] = []
        for day in [today, tomorrow] {
            let dayKey = Self.dayKey(day.date, in: timeZone)
            for (prayer, time) in day.times {
                let cfg = settings.notifications[prayer] ?? PrayerNotificationConfig()

                // Prayer-entry notification.
                if cfg.prayerNotificationEnabled {
                    let sound = soundForEntry(cfg)
                    requests.append(contentsOf: request(
                        id: "PRAYER-\(dayKey)-\(prayer.rawValue)",
                        fireAt: time, now: now,
                        title: PrayerFormatting.name(prayer),
                        body: "It's time for \(PrayerFormatting.name(prayer)) (\(PrayerFormatting.clock(time, in: timeZone))).",
                        sound: sound,
                        categoryID: cfg.playFullAdhan ? Self.adhanCategoryID : nil
                    ))
                }

                // Early reminder.
                if cfg.earlyReminderEnabled {
                    let early = time.addingTimeInterval(Double(-cfg.earlyLeadMinutes) * 60)
                    requests.append(contentsOf: request(
                        id: "EARLY-\(dayKey)-\(prayer.rawValue)",
                        fireAt: early, now: now,
                        title: "\(PrayerFormatting.name(prayer)) in \(cfg.earlyLeadMinutes) min",
                        body: "\(PrayerFormatting.name(prayer)) is at \(PrayerFormatting.clock(time, in: timeZone)).",
                        sound: notificationSound(cfg.earlySound),
                        categoryID: nil
                    ))
                }

                // Iqamah notification (obligatory prayers only).
                if prayer.isObligatory, cfg.iqamahOffsetMinutes > 0, cfg.iqamahNotificationEnabled {
                    let iqamah = time.addingTimeInterval(Double(cfg.iqamahOffsetMinutes) * 60)
                    requests.append(contentsOf: request(
                        id: "IQAMAH-\(dayKey)-\(prayer.rawValue)",
                        fireAt: iqamah, now: now,
                        title: "Iqamah — \(PrayerFormatting.name(prayer))",
                        body: "Congregation at \(PrayerFormatting.clock(iqamah, in: timeZone)).",
                        sound: notificationSound(cfg.iqamahSound),
                        categoryID: nil
                    ))
                }
            }
        }

        for request in requests {
            center.add(request)
        }
        log.notice("Scheduled \(requests.count) notifications")
    }

    // MARK: Building requests

    /// Returns a single-element array (or empty if the fire time is in the past).
    private func request(id: String, fireAt: Date, now: Date,
                         title: String, body: String,
                         sound: UNNotificationSound?, categoryID: String?) -> [UNNotificationRequest] {
        let interval = fireAt.timeIntervalSince(now)
        guard interval > 0.5 else { return [] }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = sound
        if let categoryID { content.categoryIdentifier = categoryID }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        return [UNNotificationRequest(identifier: id, content: content, trigger: trigger)]
    }

    /// Prayer-entry sound: when full Adhan plays in-process, mute the
    /// notification sound to avoid double audio (spec §9).
    private func soundForEntry(_ cfg: PrayerNotificationConfig) -> UNNotificationSound? {
        if cfg.playFullAdhan, cfg.prayerSound.hasFullAdhan { return nil }
        return notificationSound(cfg.prayerSound)
    }

    private func notificationSound(_ sound: NotificationSound) -> UNNotificationSound? {
        switch sound {
        case .none: return nil
        case .systemDefault: return .default
        default:
            if let clip = sound.notificationClipFileName {
                return UNNotificationSound(named: UNNotificationSoundName(clip))
            }
            return .default
        }
    }

    private func registerCategories() {
        let stop = UNNotificationAction(identifier: Self.stopAdhanActionID,
                                        title: "Stop Adhan", options: [.foreground])
        let category = UNNotificationCategory(identifier: Self.adhanCategoryID,
                                              actions: [stop], intentIdentifiers: [], options: [])
        center.setNotificationCategories([category])
    }

    private static func dayKey(_ date: Date, in timeZone: TimeZone) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d%02d%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    /// Show banners/sound even though the agent counts as "foreground".
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    /// Handle the Stop-Adhan action.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        if response.actionIdentifier == Self.stopAdhanActionID {
            await audio.stop()
        }
    }
}
