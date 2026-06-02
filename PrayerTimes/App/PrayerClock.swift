import Foundation
import Observation
import PrayerKit

/// The live clock that drives the menu bar. It computes today's (and tomorrow's)
/// prayer times from `PrayerKit` using the current `SettingsStore` inputs, tracks
/// the current instant once per second for the countdown, and recomputes on day
/// rollover or whenever a setting that affects the times changes.
///
/// M4 adds notification/Adhan scheduling driven by the same recompute hook.
@MainActor
@Observable
final class PrayerClock {

    private let settings: SettingsStore
    private let notifications: NotificationService
    private let audio: AudioService

    // MARK: Live state
    private(set) var today: PrayerTimes
    private(set) var tomorrow: PrayerTimes
    private(set) var now: Date

    /// Cached inputs the current `today`/`tomorrow` were computed from, plus the
    /// civil day, so `tick()` can detect both setting changes and rollover.
    private var lastInputs: ResolvedInputs
    private var lastDay: Date
    /// Previous tick instant, used to detect when a prayer time was just crossed.
    private var previousNow: Date

    private var tickTask: Task<Void, Never>?

    init(settings: SettingsStore, notifications: NotificationService, audio: AudioService) {
        self.settings = settings
        self.notifications = notifications
        self.audio = audio
        let start = Date()
        now = start
        previousNow = start
        let inputs = settings.resolvedInputs
        lastInputs = inputs
        let tz = TimeZone(identifier: inputs.timeZoneID) ?? .current
        lastDay = Self.civilDay(of: start, in: tz)
        today = Self.compute(inputs: inputs, dayOffset: 0, from: start)
        tomorrow = Self.compute(inputs: inputs, dayOffset: 1, from: start)

        Task { await notifications.requestAuthorization() }
        scheduleNotifications()
        startTicking()
    }

    // MARK: Derived values (read live from settings)

    var coordinates: Coordinates { settings.resolvedCoordinates }
    var timeZone: TimeZone { settings.resolvedTimeZone }
    var methodName: String { settings.resolvedMethodName }

    /// The upcoming prayer: the next one today, or tomorrow's Fajr after Isha.
    var nextEvent: (prayer: Prayer, time: Date)? {
        today.next(after: now) ?? tomorrow.next(after: now)
    }

    /// Seconds remaining until the next prayer (never negative).
    var secondsUntilNext: TimeInterval {
        guard let next = nextEvent else { return 0 }
        return max(0, next.time.timeIntervalSince(now))
    }

    /// Today's six times in chronological order.
    var orderedToday: [(prayer: Prayer, time: Date)] { today.ordered }

    /// Whether the full Adhan is currently playing (drives the Stop control).
    var isAdhanPlaying: Bool { audio.isPlaying }

    /// Stop in-process Adhan playback.
    func stopAdhan() { audio.stop() }

    /// Iqamah instant for a prayer, if an offset is configured (obligatory only).
    func iqamahTime(for prayer: Prayer, prayerTime: Date) -> Date? {
        guard prayer.isObligatory else { return nil }
        let offset = settings.settings.notifications[prayer]?.iqamahOffsetMinutes ?? 0
        guard offset > 0 else { return nil }
        return prayerTime.addingTimeInterval(Double(offset) * 60)
    }

    // MARK: Ticking, rollover & settings changes

    private func startTicking() {
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { break }
                self.tick()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func tick() {
        now = Date()
        let inputs = settings.resolvedInputs
        let tz = TimeZone(identifier: inputs.timeZoneID) ?? .current
        let day = Self.civilDay(of: now, in: tz)
        if inputs != lastInputs || day != lastDay {
            lastInputs = inputs
            lastDay = day
            today = Self.compute(inputs: inputs, dayOffset: 0, from: now)
            tomorrow = Self.compute(inputs: inputs, dayOffset: 1, from: now)
            scheduleNotifications()
        }
        fireAdhanIfCrossed(from: previousNow, to: now)
        previousNow = now
    }

    /// Reschedule the rolling notification window from current settings/times.
    private func scheduleNotifications() {
        notifications.reschedule(
            today: today, tomorrow: tomorrow,
            settings: settings.settings, timeZone: timeZone, now: now
        )
    }

    /// Play the full Adhan in-process for any prayer whose instant falls in
    /// `(start, end]` and has full-Adhan playback enabled (spec §9). Reliable
    /// because the agent is always running.
    private func fireAdhanIfCrossed(from start: Date, to end: Date) {
        guard settings.settings.masterNotificationsEnabled else { return }
        for (prayer, time) in today.times where time > start && time <= end {
            let cfg = settings.settings.notifications[prayer] ?? PrayerNotificationConfig()
            if cfg.prayerNotificationEnabled, cfg.playFullAdhan {
                audio.playFullAdhan(cfg.prayerSound)
            }
        }
    }

    // MARK: Engine bridge

    private static func compute(inputs: ResolvedInputs, dayOffset: Int, from reference: Date) -> PrayerTimes {
        let tz = TimeZone(identifier: inputs.timeZoneID) ?? .current
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let day = cal.date(byAdding: .day, value: dayOffset, to: reference) ?? reference
        let comps = cal.dateComponents([.year, .month, .day], from: day)
        return PrayerTimeEngine.calculate(
            date: comps,
            coordinates: inputs.coordinates,
            params: inputs.parameters,
            timeZone: tz
        )
    }

    private static func civilDay(of date: Date, in timeZone: TimeZone) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return cal.startOfDay(for: date)
    }
}
