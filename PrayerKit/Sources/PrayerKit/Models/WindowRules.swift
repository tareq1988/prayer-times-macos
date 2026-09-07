import Foundation

/// Where the Isha window is treated as ending for reminder purposes.
public enum IshaEnd: String, Codable, Sendable, CaseIterable, Hashable {
    /// Halfway from sunset to the next Fajr; delaying Isha past it is disliked.
    case islamicMidnight
    /// The next day's Fajr, the hard limit of the window.
    case fajr
}

/// When each prayer should be treated as *ending* for the "time running out"
/// reminder and the time-left countdown. The astronomical window is the hard
/// limit; some prayers have an earlier last-recommended time. Whole minutes.
public struct WindowRules: Codable, Sendable, Equatable, Hashable {
    /// Fajr must be finished before sunrise: treat it as ending this many
    /// minutes earlier.
    public var fajrEndMarginMinutes: Int
    /// Asr in the last stretch before sunset (the sun yellowing) is makruh:
    /// treat it as ending this many minutes before Maghrib.
    public var asrEndMarginMinutes: Int
    public var ishaEnd: IshaEnd

    public init(fajrEndMarginMinutes: Int = 10, asrEndMarginMinutes: Int = 20, ishaEnd: IshaEnd = .islamicMidnight) {
        self.fajrEndMarginMinutes = fajrEndMarginMinutes
        self.asrEndMarginMinutes = asrEndMarginMinutes
        self.ishaEnd = ishaEnd
    }

    /// Resilient decode: a missing key falls back to its default rather than
    /// failing the whole settings blob (matches `AppSettings`).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = WindowRules()
        fajrEndMarginMinutes = try c.decodeIfPresent(Int.self, forKey: .fajrEndMarginMinutes) ?? d.fajrEndMarginMinutes
        asrEndMarginMinutes = try c.decodeIfPresent(Int.self, forKey: .asrEndMarginMinutes) ?? d.asrEndMarginMinutes
        ishaEnd = try c.decodeIfPresent(IshaEnd.self, forKey: .ishaEnd) ?? d.ishaEnd
    }
}

public extension PrayerTimes {
    /// The last recommended instant to pray `prayer` on this day under `rules`:
    /// the cut-off the "time running out" reminder and the time-left countdown
    /// count toward. Dhuhr and Maghrib run to the next prayer; Fajr and Asr end
    /// a margin before sunrise / sunset; Isha needs `nextFajr` (the following
    /// day's Fajr) and is `nil` without it. Also `nil` for Sunrise or when a
    /// bounding time is undefined (polar edge cases).
    func deadline(for prayer: Prayer, nextFajr: Date? = nil, rules: WindowRules) -> Date? {
        switch prayer {
        case .fajr:
            return self[.sunrise].map { $0.addingTimeInterval(-Double(rules.fajrEndMarginMinutes) * 60) }
        case .sunrise:
            return nil
        case .dhuhr:
            return self[.asr]
        case .asr:
            return self[.maghrib].map { $0.addingTimeInterval(-Double(rules.asrEndMarginMinutes) * 60) }
        case .maghrib:
            return self[.isha]
        case .isha:
            guard let nextFajr else { return nil }
            switch rules.ishaEnd {
            case .fajr:
                return nextFajr
            case .islamicMidnight:
                return self[.maghrib].map { $0.addingTimeInterval(nextFajr.timeIntervalSince($0) / 2) }
            }
        }
    }
}
