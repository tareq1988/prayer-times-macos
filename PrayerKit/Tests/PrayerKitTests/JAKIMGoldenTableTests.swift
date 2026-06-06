import XCTest
@testable import PrayerKit

/// Hard gate for the JAKIM adapter: it must reproduce JAKIM's official e-Solat
/// output for Kuala Lumpur (zone WLY01) to within ±1 minute for Fajr, Dhuhr,
/// Asr, Maghrib, and Isha.
///
/// The reference rows below are taken verbatim from the JAKIM e-Solat API
/// (`e-solat.gov.my/.../takwimsolat?zone=WLY01`) and deliberately span both
/// solstices and both equinoxes — the worst cases for twilight-angle and
/// ihtiyati drift. This is what pins the calibrated parameters in
/// `JAKIMAdapter` (Fajr 17.5°, Isha 18°, ihtiyati Dhuhr +3/Asr +2/Maghrib +2/
/// Isha +2); the plain "Fajr 20°/Isha 18°" preset fails this gate by ~11 min.
///
/// Sunrise (syuruk) is intentionally not gated: e-Solat shaves ~1 min off it for
/// safety, which our standard −0.833° horizon does not, and it is informational
/// rather than a prayer.
final class JAKIMGoldenTableTests: XCTestCase {

    private struct Row {
        let date: DateComponents
        let fajr, dhuhr, asr, maghrib, isha: Int   // minutes since local midnight
    }

    // Kuala Lumpur, WLY01.
    private let kl = Coordinates(latitude: 3.1409, longitude: 101.6932)
    private let tz = TZ.make("Asia/Kuala_Lumpur")

    private func hm(_ s: String) -> Int {
        let p = s.split(separator: ":"); return Int(p[0])! * 60 + Int(p[1])!
    }
    private func minutes(_ date: Date) -> Int {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        let c = cal.dateComponents([.hour, .minute, .second], from: date)
        return c.hour! * 60 + c.minute! + (c.second! >= 30 ? 1 : 0)   // round to nearest minute
    }
    private func row(_ y: Int, _ m: Int, _ d: Int, _ fajr: String, _ dhuhr: String,
                     _ asr: String, _ maghrib: String, _ isha: String) -> Row {
        Row(date: DateComponents(year: y, month: m, day: d),
            fajr: hm(fajr), dhuhr: hm(dhuhr), asr: hm(asr), maghrib: hm(maghrib), isha: hm(isha))
    }

    func testJAKIMMatchesESolatWithinOneMinute() {
        // Official JAKIM e-Solat rows (WLY01), spanning the full seasonal range.
        let golden = [
            row(2026, 3, 21, "06:10", "13:23", "16:29", "19:26", "20:34"),  // March equinox
            row(2026, 6, 6,  "05:50", "13:15", "16:40", "19:23", "20:39"),  // near June solstice
            row(2026, 9, 23, "05:55", "13:09", "16:14", "19:11", "20:20"),  // September equinox
            row(2026, 12, 21, "06:01", "13:14", "16:37", "19:11", "20:26"), // December solstice
        ]

        let params = JAKIMAdapter().resolve(for: kl)
        for g in golden {
            let t = PrayerTimeEngine.calculate(date: g.date, coordinates: kl, params: params, timeZone: tz)
            let label = "\(g.date.year!)-\(g.date.month!)-\(g.date.day!)"
            func check(_ prayer: Prayer, _ expected: Int, _ name: String) {
                guard let actual = t.times[prayer].map(minutes) else {
                    return XCTFail("\(label): missing \(name)")
                }
                XCTAssertLessThanOrEqual(abs(actual - expected), 1,
                    "\(label) \(name): ours \(actual) vs JAKIM \(expected) (Δ\(actual - expected) min)")
            }
            check(.fajr, g.fajr, "Fajr")
            check(.dhuhr, g.dhuhr, "Dhuhr")
            check(.asr, g.asr, "Asr")
            check(.maghrib, g.maghrib, "Maghrib")
            check(.isha, g.isha, "Isha")
        }
    }
}
