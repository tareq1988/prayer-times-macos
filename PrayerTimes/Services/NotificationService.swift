import Foundation
import UserNotifications
import PrayerKit
import OSLog
import Observation

/// Schedules local notifications for the rolling today + tomorrow window
/// (spec §7.3, §7.4, §9): a prayer-entry notification, an optional early
/// reminder, and an optional iqamah notification per prayer — each with its own
/// sound. Stable identifiers per (day, prayer, type) mean re-scheduling replaces
/// rather than duplicates. Also acts as the notification-center delegate so
/// banners show while the agent is running and the Stop-Adhan action works.
@MainActor
@Observable
final class NotificationService: NSObject {
    @ObservationIgnored private let audio: AudioService
    @ObservationIgnored private let center = UNUserNotificationCenter.current()
    @ObservationIgnored private let log = Logger(subsystem: "co.tareq.prayertimes", category: "notifications")

    /// The current system authorization, mirrored so the UI can warn when
    /// notifications are off. Refreshed on launch, after a request, and when the
    /// Notifications tab appears.
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

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
        await refreshAuthorizationStatus()
    }

    /// Re-read the system authorization status into `authorizationStatus`.
    func refreshAuthorizationStatus() async {
        authorizationStatus = await center.notificationSettings().authorizationStatus
    }

    /// Fire an immediate sample notification so the user can preview the look
    /// (and confirm permissions). Uses the same wording as a real prayer-entry
    /// notification and attaches the app logo.
    func sendSampleNotification() async {
        // Make sure we're authorized first (no-op prompt if already decided).
        await requestAuthorization()

        let name = PrayerFormatting.name(.dhuhr)
        let clock = PrayerFormatting.clock(Date(), in: .current)

        let content = UNMutableNotificationContent()
        content.title = name
        content.body = String(localized: "It's time for \(name) (\(clock)).")
        content.sound = UNNotificationSound(named: UNNotificationSoundName("takbir.caf"))
        if let attachment = appIconAttachment() {
            content.attachments = [attachment]
        }

        let request = UNNotificationRequest(
            identifier: "SAMPLE-\(UUID().uuidString)",
            content: content,
            trigger: nil   // deliver immediately
        )
        do {
            try await center.add(request)
            log.notice("Sent sample notification")
        } catch {
            log.error("Sample notification failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Wrap the bundled logo PNG as a notification attachment. We copy it to a
    /// temp file because the notification center takes ownership of the URL it's
    /// given (it can't move a file out of the app bundle).
    private func appIconAttachment() -> UNNotificationAttachment? {
        guard let bundled = Bundle.main.url(forResource: "notification-icon", withExtension: "png") else {
            log.error("notification-icon.png not bundled")
            return nil
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pt-icon-\(UUID().uuidString).png")
        do {
            try FileManager.default.copyItem(at: bundled, to: url)
            return try UNNotificationAttachment(identifier: "appIcon", url: url, options: nil)
        } catch {
            log.error("Icon attachment failed: \(error.localizedDescription, privacy: .public)")
            return nil
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

        // In Manual (fixed) mode the displayed obligatory time is the jamaat; the
        // azan reminder fires this many minutes before it (design: Calculation tab).
        let manual = settings.calculationMode == .manual
        let azanBefore = manual ? Double(max(0, settings.azanBeforeJamaat)) * 60 : 0

        var requests: [UNNotificationRequest] = []
        for day in [today, tomorrow] {
            let dayKey = Self.dayKey(day.date, in: timeZone)
            for (prayer, time) in day.times {
                let cfg = settings.resolvedNotification(for: prayer)

                // Prayer-entry / azan notification. Obligatory prayers in manual
                // mode fire `azanBefore` ahead of the jamaat time.
                if cfg.notify {
                    let fireAt = (manual && prayer.isObligatory)
                        ? time.addingTimeInterval(-azanBefore) : time
                    let name = PrayerFormatting.name(prayer)
                    let clock = PrayerFormatting.clock(time, in: timeZone)
                    requests.append(contentsOf: request(
                        id: "PRAYER-\(dayKey)-\(prayer.rawValue)",
                        fireAt: fireAt, now: now,
                        title: name,
                        body: String(localized: "It's time for \(name) (\(clock))."),
                        sound: soundForEntry(cfg),
                        categoryID: cfg.playFullAdhan ? Self.adhanCategoryID : nil
                    ))
                }

                // Early reminder.
                if cfg.earlyReminderEnabled {
                    let early = time.addingTimeInterval(Double(-cfg.earlyLeadMinutes) * 60)
                    let name = PrayerFormatting.name(prayer)
                    let clock = PrayerFormatting.clock(time, in: timeZone)
                    requests.append(contentsOf: request(
                        id: "EARLY-\(dayKey)-\(prayer.rawValue)",
                        fireAt: early, now: now,
                        title: String(localized: "\(name) in \(cfg.earlyLeadMinutes) min"),
                        body: String(localized: "\(name) is at \(clock)."),
                        sound: .default,
                        categoryID: nil
                    ))
                }

                // Iqamah notification (obligatory prayers, calculated mode only —
                // in manual mode the displayed time already is the jamaat).
                if prayer.isObligatory, !manual, cfg.iqamahOffsetMinutes > 0 {
                    let iqamah = time.addingTimeInterval(Double(cfg.iqamahOffsetMinutes) * 60)
                    let name = PrayerFormatting.name(prayer)
                    let clock = PrayerFormatting.clock(iqamah, in: timeZone)
                    requests.append(contentsOf: request(
                        id: "IQAMAH-\(dayKey)-\(prayer.rawValue)",
                        fireAt: iqamah, now: now,
                        title: String(localized: "Iqamah — \(name)"),
                        body: String(localized: "Congregation at \(clock)."),
                        sound: .default,
                        categoryID: nil
                    ))
                }
            }
        }

        for request in requests {
            let id = request.identifier
            center.add(request) { [log] error in
                if let error {
                    log.error("Schedule failed \(id, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }
        }
        let authState = settings.masterNotificationsEnabled ? "on" : "off"
        log.notice("Scheduled \(requests.count) notifications (master=\(authState, privacy: .public))")
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
    private func soundForEntry(_ cfg: ResolvedNotification) -> UNNotificationSound? {
        if cfg.playFullAdhan, cfg.sound.hasFullAdhan { return nil }
        return notificationSound(cfg.sound)
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
