import XCTest
@testable import PrayerKit

/// Hard gate for the Kemenag adapter: it must reproduce Kemenag's official
/// published prayer times for KOTA JAKARTA to within ±1 minute for Subuh,
/// Dzuhur, Ashar, Maghrib, and Isya.
///
/// The reference rows are taken from Kemenag's tables (via the myquran v2 API,
/// city 1301) and span both solstices and both equinoxes. The reference
/// coordinates below were back-solved from the angle-free anchors (terbit =
/// sunrise − 2, maghrib = sunset + 2) that Kemenag's ihtiyati implies; with them
/// the calibrated parameters in `KemenagAdapter` (Fajr 20°, Isha 18°, ihtiyati
/// Subuh +2/Dzuhur +3/Ashar +2/Maghrib +3/Isya +2) match Kemenag to ±1 min.
///
/// Terbit (sunrise) is not gated: Kemenag shaves ihtiyati off it and it is
/// informational rather than a prayer.
final class KemenagGoldenTableTests: XCTestCase {

    private struct Row {
        let date: DateComponents
        let subuh, dzuhur, ashar, maghrib, isya: Int   // minutes since local midnight
    }

    // Kemenag reference point for KOTA JAKARTA (back-solved from the tables).
    private let jakarta = Coordinates(latitude: -6.21, longitude: 106.72)
    private let tz = TZ.make("Asia/Jakarta")

    private func hm(_ s: String) -> Int {
        let p = s.split(separator: ":"); return Int(p[0])! * 60 + Int(p[1])!
    }
    private func minutes(_ date: Date) -> Int {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        let c = cal.dateComponents([.hour, .minute], from: date)
        return c.hour! * 60 + c.minute!
    }
    private func row(_ y: Int, _ m: Int, _ d: Int, _ subuh: String, _ dzuhur: String,
                     _ ashar: String, _ maghrib: String, _ isya: String) -> Row {
        Row(date: DateComponents(year: y, month: m, day: d),
            subuh: hm(subuh), dzuhur: hm(dzuhur), ashar: hm(ashar), maghrib: hm(maghrib), isya: hm(isya))
    }

    func testKemenagMatchesOfficialTablesWithinOneMinute() {
        // Official Kemenag rows (KOTA JAKARTA), full seasonal range.
        let golden = [
            row(2026, 3, 21, "04:42", "12:04", "15:14", "18:07", "19:15"),  // March equinox
            row(2026, 6, 6,  "04:37", "11:55", "15:16", "17:48", "19:02"),  // near June solstice
            row(2026, 9, 23, "04:27", "11:49", "14:58", "17:52", "19:00"),  // September equinox
            row(2026, 12, 21, "04:13", "11:54", "15:20", "18:08", "19:24"), // December solstice
        ]

        let params = KemenagAdapter().resolve(for: jakarta)
        for g in golden {
            let t = PrayerTimeEngine.calculate(date: g.date, coordinates: jakarta, params: params, timeZone: tz)
            let label = "\(g.date.year!)-\(g.date.month!)-\(g.date.day!)"
            func check(_ prayer: Prayer, _ expected: Int, _ name: String) {
                guard let actual = t.times[prayer].map(minutes) else {
                    return XCTFail("\(label): missing \(name)")
                }
                XCTAssertLessThanOrEqual(abs(actual - expected), 1,
                    "\(label) \(name): ours \(actual) vs Kemenag \(expected) (Δ\(actual - expected) min)")
            }
            check(.fajr, g.subuh, "Subuh")
            check(.dhuhr, g.dzuhur, "Dzuhur")
            check(.asr, g.ashar, "Ashar")
            check(.maghrib, g.maghrib, "Maghrib")
            check(.isha, g.isya, "Isya")
        }
    }
}
