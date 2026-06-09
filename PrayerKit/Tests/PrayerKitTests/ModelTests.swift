import XCTest
@testable import PrayerKit

/// Covers the value-type model logic that the app/widget rely on: next/current
/// prayer selection, ordering, settings codability, and sound metadata.
final class ModelTests: XCTestCase {

    private func sampleTimes() -> PrayerTimes {
        let base = Date(timeIntervalSince1970: 1_700_000_000)   // fixed anchor
        func at(_ h: Double) -> Date { base.addingTimeInterval(h * 3600) }
        return PrayerTimes(date: base, times: [
            .fajr: at(5), .sunrise: at(6.5), .dhuhr: at(12),
            .asr: at(15), .maghrib: at(18), .isha: at(19.5)
        ])
    }

    func testNextAfterPicksEarliestFuturePrayer() {
        let t = sampleTimes()
        let now = t.date.addingTimeInterval(13 * 3600)   // 13:00, between Dhuhr and Asr
        let next = t.next(after: now)
        XCTAssertEqual(next?.prayer, .asr)
    }

    func testNextAfterReturnsNilWhenAllPast() {
        let t = sampleTimes()
        let now = t.date.addingTimeInterval(23 * 3600)
        XCTAssertNil(t.next(after: now))
    }

    func testCurrentAtPicksMostRecentPast() {
        let t = sampleTimes()
        let now = t.date.addingTimeInterval(18.5 * 3600)   // just after Maghrib
        XCTAssertEqual(t.current(at: now)?.prayer, .maghrib)
    }

    func testCurrentAtReturnsNilBeforeFajr() {
        let t = sampleTimes()
        let now = t.date.addingTimeInterval(3 * 3600)
        XCTAssertNil(t.current(at: now))
    }

    func testOrderedIsChronological() {
        let order = sampleTimes().ordered.map(\.prayer)
        XCTAssertEqual(order, [.fajr, .sunrise, .dhuhr, .asr, .maghrib, .isha])
    }

    func testObligatoryExcludesSunrise() {
        XCTAssertEqual(Prayer.obligatory, [.fajr, .dhuhr, .asr, .maghrib, .isha])
        XCTAssertFalse(Prayer.sunrise.isObligatory)
        XCTAssertTrue(Prayer.dhuhr.isObligatory)
    }

    func testAppSettingsRoundTripsThroughJSON() throws {
        let settings = AppSettings(
            methodID: "diyanet",
            hanafiAsr: true,
            highLatitudeRule: .angleBased,
            manualCoordinates: Coordinates(latitude: 41, longitude: 29, elevation: 100),
            timeZoneMode: .explicit(identifier: "Europe/Istanbul"),
            languageOverride: "tr"
        )
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(decoded, settings)
        XCTAssertEqual(decoded.timeZoneMode.timeZone.identifier, "Europe/Istanbul")
    }

    func testDefaultNotificationsMatchProductExamples() {
        let n = AppSettings.defaultNotifications
        XCTAssertEqual(n[.dhuhr]?.earlyLeadMinutesOverride, 20)
        XCTAssertTrue(n[.dhuhr]?.earlyReminderEnabled ?? false)
        XCTAssertEqual(n[.maghrib]?.earlyLeadMinutesOverride, 10)
        XCTAssertEqual(n[.sunrise]?.notify, false)
        XCTAssertEqual(n.count, 6)
    }

    func testResolvedNotificationInheritsDefaults() {
        var s = AppSettings()
        s.notificationDefaults = NotificationDefaults(
            sound: .adhanMakkah, earlyReminderMinutes: 10, iqamahOffsetMinutes: 5)
        // Asr inherits everything (no per-prayer overrides).
        s.notifications[.asr] = PrayerNotificationConfig(earlyReminderEnabled: true)
        let asr = s.resolvedNotification(for: .asr)
        XCTAssertEqual(asr.sound, .adhanMakkah)
        XCTAssertEqual(asr.earlyLeadMinutes, 10)
        XCTAssertEqual(asr.iqamahOffsetMinutes, 5)
        XCTAssertTrue(asr.earlyReminderEnabled)

        // Fajr overrides the sound and lead; iqamah still inherits.
        s.notifications[.fajr] = PrayerNotificationConfig(
            earlyReminderEnabled: true, soundOverride: .takbir, earlyLeadMinutesOverride: 30)
        let fajr = s.resolvedNotification(for: .fajr)
        XCTAssertEqual(fajr.sound, .takbir)
        XCTAssertEqual(fajr.earlyLeadMinutes, 30)
        XCTAssertEqual(fajr.iqamahOffsetMinutes, 5)

        // Sunrise never carries Adhan or iqamah even if asked.
        s.notifications[.sunrise] = PrayerNotificationConfig(playFullAdhan: true)
        let sunrise = s.resolvedNotification(for: .sunrise)
        XCTAssertFalse(sunrise.playFullAdhan)
        XCTAssertEqual(sunrise.iqamahOffsetMinutes, 0)
    }

    func testNotificationSoundMetadata() {
        XCTAssertTrue(NotificationSound.adhanMakkah.hasFullAdhan)
        XCTAssertFalse(NotificationSound.softChime.hasFullAdhan)
        XCTAssertEqual(NotificationSound.adhanMakkah.fullAdhanFileName, "adhan-makkah.m4a")
        // Adhan selections still use a short clip for the notification itself.
        XCTAssertEqual(NotificationSound.adhanMakkah.notificationClipFileName, "takbir.caf")
        XCTAssertNil(NotificationSound.none.notificationClipFileName)
    }
}
