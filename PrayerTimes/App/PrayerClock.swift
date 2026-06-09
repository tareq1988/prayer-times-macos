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
    private let focus: FocusModeController

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

    /// Held for the app's lifetime to keep App Nap from coalescing the 1-second
    /// tick. Without it, an idle menu-bar agent gets its timers throttled, so the
    /// tick that should catch a prayer crossing can land tens of seconds late —
    /// past the catch-up guards — and Focus Mode / in-process Adhan silently miss
    /// the prayer even though the system still delivers the scheduled notification.
    /// `…AllowingIdleSystemSleep` disables App Nap *without* keeping the Mac awake.
    @ObservationIgnored private let napActivity: any NSObjectProtocol

    init(settings: SettingsStore, notifications: NotificationService, audio: AudioService, focus: FocusModeController) {
        napActivity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep,
            reason: "Fire prayer notifications, Adhan, and Focus Mode at exact times")
        self.settings = settings
        self.notifications = notifications
        self.audio = audio
        self.focus = focus
        let start = Date()
        now = start
        previousNow = start
        let inputs = settings.resolvedInputs
        lastInputs = inputs
        let tz = TimeZone(identifier: inputs.timeZoneID) ?? .current
        lastDay = Self.civilDay(of: start, in: tz)
        today = Self.compute(inputs: inputs, dayOffset: 0, from: start)
        tomorrow = Self.compute(inputs: inputs, dayOffset: 1, from: start)

        // Immediate schedule covers the common relaunch case (permission already
        // granted). On a fresh install the authorization prompt resolves
        // asynchronously, so reschedule once it does — otherwise the first day's
        // notifications register while status is still `notDetermined` and never
        // get re-added against the granted permission.
        scheduleNotifications()
        startTicking()
        Task { [weak self] in
            await notifications.requestAuthorization()
            self?.scheduleNotifications()
        }
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

    /// The prayer window currently in progress (for the "time left" countdown):
    /// the active prayer and when its window closes. `nil` only in polar edge
    /// cases where the bounding times are undefined.
    var currentWaqt: CurrentWaqt? {
        CurrentWaqt.resolve(at: now, today: today, tomorrow: tomorrow)
    }

    /// Today's Ishraq start (sunrise + fixed offset), for the optional panel line.
    var ishraqTime: Date? { today.ishraq() }

    /// Whether the user enabled the optional Ishraq line in the panel.
    var showsIshraqTime: Bool { settings.settings.showIshraqTime }

    /// Whether the panel shows the Hijri date line.
    var showsHijriDate: Bool { settings.settings.showHijriDate }

    /// Whole-day correction applied to the displayed Hijri date (regional moon-sighting).
    var hijriDayAdjustment: Int { settings.settings.hijriDayAdjustment }

    /// Today's six times in chronological order.
    var orderedToday: [(prayer: Prayer, time: Date)] { today.ordered }

    /// Whether the full Adhan is currently playing (drives the Stop control).
    var isAdhanPlaying: Bool { audio.isPlaying }

    /// Stop in-process Adhan playback.
    func stopAdhan() { audio.stop() }

    /// Iqamah instant for a prayer, if an offset is configured (obligatory only).
    /// In Manual mode the displayed time *is* the jamaat, so no extra iqamah line.
    func iqamahTime(for prayer: Prayer, prayerTime: Date) -> Date? {
        guard prayer.isObligatory, settings.settings.calculationMode == .calculated else { return nil }
        let offset = settings.settings.resolvedNotification(for: prayer).iqamahOffsetMinutes
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
        beginFocusIfCrossed(from: previousNow, to: now)
        previousNow = now
    }

    /// Engage Focus Mode for an obligatory prayer whose instant falls in
    /// `(start, end]`, when enabled. Reuses the Adhan catch-up guard so a
    /// sleep/wake gap never slams a stale full-screen block onto the desktop.
    private func beginFocusIfCrossed(from start: Date, to end: Date) {
        guard settings.settings.focusModeEnabled else { return }
        // A larger tolerance than the Adhan's: replaying late audio is jarring, but
        // engaging the screen cover up to two minutes into a prayer is still useful
        // (the window is wide), so a slightly delayed tick shouldn't lose it.
        guard end.timeIntervalSince(start) <= Self.maxFocusCatchUp else { return }
        let trigger = settings.settings.focusTrigger
        for (prayer, time) in today.times where trigger.includes(prayer) && time > start && time <= end {
            focus.begin(prayer: prayer, settings: settings.settings)
        }
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
    ///
    /// A healthy tick advances ~1 s. A much larger gap means the loop was
    /// suspended (system sleep), so any prayer "crossed" in that window already
    /// passed while asleep — replaying its Adhan now would be wrong. Skip those.
    private static let maxAdhanCatchUp: TimeInterval = 10
    /// Focus may engage a little later than the Adhan plays (see `beginFocusIfCrossed`).
    private static let maxFocusCatchUp: TimeInterval = 120
    private func fireAdhanIfCrossed(from start: Date, to end: Date) {
        guard settings.settings.masterNotificationsEnabled else { return }
        guard end.timeIntervalSince(start) <= Self.maxAdhanCatchUp else { return }
        for (prayer, time) in today.times where time > start && time <= end {
            let cfg = settings.settings.resolvedNotification(for: prayer)
            if cfg.notify, cfg.playFullAdhan {
                audio.playFullAdhan(cfg.sound)
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
        let astronomical = PrayerTimeEngine.calculate(
            date: comps,
            coordinates: inputs.coordinates,
            params: inputs.parameters,
            timeZone: tz
        )
        // Manual (fixed) time source: replace the obligatory times with the
        // mosque's jamaat schedule, keeping Sunrise astronomical.
        guard let manual = inputs.manual else { return astronomical }
        return manual.applied(to: astronomical, day: day, timeZone: tz)
    }

    private static func civilDay(of date: Date, in timeZone: TimeZone) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return cal.startOfDay(for: date)
    }
}
