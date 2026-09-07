import XCTest
@testable import PrayerKit

/// The per-prayer cut-off ("last recommended time") used by the time-running-out
/// reminder and the time-left countdown, plus resilient decoding of the rules.
final class WindowRulesTests: XCTestCase {

    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func at(_ hour: Int, _ minute: Int, day: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 6, day: 8 + day, hour: hour, minute: minute))!
    }

    private lazy var today = PrayerTimes(date: at(0, 0), times: [
        .fajr: at(5, 0), .sunrise: at(6, 30), .dhuhr: at(12, 0),
        .asr: at(15, 30), .maghrib: at(18, 0), .isha: at(19, 30),
    ])
    private lazy var nextFajr = at(5, 0, day: 1)
    private let rules = WindowRules()   // Fajr 10, Asr 20, Isha at Islamic midnight

    func testFajrEndsAMarginBeforeSunrise() {
        XCTAssertEqual(today.deadline(for: .fajr, rules: rules), at(6, 20))
    }

    func testDhuhrAndMaghribRunToTheNextPrayer() {
        XCTAssertEqual(today.deadline(for: .dhuhr, rules: rules), at(15, 30))
        XCTAssertEqual(today.deadline(for: .maghrib, rules: rules), at(19, 30))
    }

    func testAsrEndsAMarginBeforeSunset() {
        XCTAssertEqual(today.deadline(for: .asr, rules: rules), at(17, 40))
        XCTAssertEqual(today.deadline(for: .asr, rules: WindowRules(asrEndMarginMinutes: 0)), at(18, 0))
    }

    func testIshaEndsAtIslamicMidnightOrFajr() {
        // Halfway from 18:00 to 05:00 next day (11 h) is 23:30.
        XCTAssertEqual(today.deadline(for: .isha, nextFajr: nextFajr, rules: rules), at(23, 30))
        XCTAssertEqual(today.deadline(for: .isha, nextFajr: nextFajr, rules: WindowRules(ishaEnd: .fajr)), nextFajr)
        XCTAssertNil(today.deadline(for: .isha, rules: rules), "Isha needs the next Fajr")
    }

    func testSunriseHasNoDeadline() {
        XCTAssertNil(today.deadline(for: .sunrise, rules: rules))
    }

    func testDecodingMissingKeysFallsBackToDefaults() throws {
        let decoded = try JSONDecoder().decode(WindowRules.self, from: Data(#"{"asrEndMarginMinutes": 25}"#.utf8))
        XCTAssertEqual(decoded, WindowRules(asrEndMarginMinutes: 25))
    }
}
