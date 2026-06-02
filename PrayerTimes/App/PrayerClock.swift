import Foundation
import Observation
import PrayerKit

/// The live clock that drives the menu bar. It computes today's (and tomorrow's)
/// prayer times from `PrayerKit`, tracks the current instant once per second for
/// the countdown, and recomputes on day rollover.
///
/// M2 scope: location, timezone, and method are hardcoded. M3 replaces these
/// with `SettingsStore`, and M4 adds notification/Adhan scheduling. The
/// computation and "next prayer" logic live here so those milestones only need
/// to swap the inputs.
@MainActor
@Observable
final class PrayerClock {

    // MARK: Hardcoded inputs (replaced by SettingsStore in M3)
    let coordinates = Coordinates(latitude: 41.0082, longitude: 28.9784)   // Istanbul
    let timeZone = TimeZone(identifier: "Europe/Istanbul") ?? .current
    let methodName = "Diyanet İşleri (Türkiye)"
    private let method = DiyanetAdapter()

    // MARK: Live state
    private(set) var today: PrayerTimes
    private(set) var tomorrow: PrayerTimes
    private(set) var now: Date

    private var tickTask: Task<Void, Never>?

    init() {
        let start = Date()
        now = start
        today = Self.compute(method: method, coordinates: coordinates,
                             timeZone: timeZone, dayOffset: 0, from: start)
        tomorrow = Self.compute(method: method, coordinates: coordinates,
                                timeZone: timeZone, dayOffset: 1, from: start)
        startTicking()
    }

    // MARK: Derived values

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

    // MARK: Ticking & rollover

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
        let current = Date()
        now = current
        // Recompute when the calendar day (in the master timezone) has rolled over.
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        if !cal.isDate(current, inSameDayAs: today.date) {
            recompute(from: current)
        }
    }

    /// Force a recomputation (e.g. after a settings change in later milestones).
    func recompute(from reference: Date = Date()) {
        today = Self.compute(method: method, coordinates: coordinates,
                             timeZone: timeZone, dayOffset: 0, from: reference)
        tomorrow = Self.compute(method: method, coordinates: coordinates,
                                timeZone: timeZone, dayOffset: 1, from: reference)
    }

    // MARK: Engine bridge

    private static func compute(
        method: some CalculationMethodAdapter,
        coordinates: Coordinates,
        timeZone: TimeZone,
        dayOffset: Int,
        from reference: Date
    ) -> PrayerTimes {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let day = cal.date(byAdding: .day, value: dayOffset, to: reference) ?? reference
        let comps = cal.dateComponents([.year, .month, .day], from: day)
        return PrayerTimeEngine.calculate(
            date: comps,
            coordinates: coordinates,
            params: method.resolve(for: coordinates),
            timeZone: timeZone
        )
    }
}
