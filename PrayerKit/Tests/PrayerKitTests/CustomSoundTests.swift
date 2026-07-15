import XCTest
@testable import PrayerKit

/// Covers user-imported custom Adhan support at the pure-model layer: the
/// `CustomSound` value type, the `NotificationSound.custom` wire format (which
/// must stay compatible with pre-custom persisted blobs), and the resilient
/// decode of the new `AppSettings.customSounds` field.
final class CustomSoundTests: XCTestCase {

    func testCustomSoundRoundTripsThroughJSON() throws {
        let id = UUID()
        let sound = CustomSound(
            id: id,
            fileName: "\(id.uuidString).mp3",
            displayName: "My Fajr Adhan",
            durationSeconds: 182.5
        )
        let data = try JSONEncoder().encode(sound)
        let decoded = try JSONDecoder().decode(CustomSound.self, from: data)
        XCTAssertEqual(decoded, sound)
    }

    // MARK: NotificationSound.custom wire format

    func testCustomNotificationSoundRoundTripsAsPrefixedUUIDString() throws {
        let id = UUID()
        let sound = NotificationSound.custom(id)
        // Encoded as a single JSON string "custom:<uuid>" so it slots into the
        // same String-shaped slot the built-in sounds already use.
        let data = try JSONEncoder().encode(sound)
        XCTAssertEqual(String(decoding: data, as: UTF8.self), "\"custom:\(id.uuidString)\"")
        let decoded = try JSONDecoder().decode(NotificationSound.self, from: data)
        XCTAssertEqual(decoded, .custom(id))
        XCTAssertEqual(decoded.customID, id)
    }

    /// The whole compat story rests on built-ins keeping their historical string
    /// form, so a pre-custom blob (and an older build reading a new blob) still
    /// decodes them. Pin every built-in's exact wire string.
    func testBuiltInSoundsKeepTheirLegacyStringWireFormat() throws {
        let expected: [NotificationSound: String] = [
            .none: "none",
            .systemDefault: "systemDefault",
            .softChime: "softChime",
            .takbir: "takbir",
            .adhanMakkah: "adhanMakkah",
            .adhanMadinah: "adhanMadinah",
        ]
        for (sound, wire) in expected {
            let data = try JSONEncoder().encode(sound)
            XCTAssertEqual(String(decoding: data, as: UTF8.self), "\"\(wire)\"", "encode \(sound)")
            let decoded = try JSONDecoder().decode(NotificationSound.self, from: Data("\"\(wire)\"".utf8))
            XCTAssertEqual(decoded, sound, "decode \(wire)")
        }
    }

    /// An unrecognized or malformed sound value (a sound added by a newer build, a
    /// non-UUID custom payload, or a non-string) must decode to a safe fallback
    /// rather than throw — a throw would reset the entire settings blob.
    func testUnknownSoundValuesDecodeToSystemDefaultWithoutThrowing() throws {
        let cases = ["\"totallyUnknown\"", "\"custom:not-a-uuid\"", "\"custom:\"", "\"\"", "42"]
        for json in cases {
            let decoded = try JSONDecoder().decode(NotificationSound.self, from: Data(json.utf8))
            XCTAssertEqual(decoded, .systemDefault, "input \(json)")
        }
    }

    func testCustomSoundMetadataTreatsItAsAFullAdhanWithNoBundledClip() {
        let sound = NotificationSound.custom(UUID())
        XCTAssertTrue(sound.hasFullAdhan)
        XCTAssertNil(sound.notificationClipFileName)
        XCTAssertNil(sound.fullAdhanFileName)
    }

    func testAllCasesListsOnlyBuiltInSounds() {
        XCTAssertEqual(
            NotificationSound.allCases,
            [.none, .systemDefault, .softChime, .takbir, .adhanMakkah, .adhanMadinah])
    }

    // MARK: AppSettings.customSounds

    /// A settings blob written before custom sounds existed has no `customSounds`
    /// key and stores sounds as plain strings. It must decode with an empty library
    /// and the built-in sound intact — never a first-run reset.
    func testDecodesPreCustomSettingsBlobWithEmptyLibrary() throws {
        let json = """
        { "methodID": "diyanet",
          "notificationDefaults": { "sound": "adhanMadinah", "playFullAdhan": true } }
        """
        let decoded = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.customSounds, [])
        XCTAssertEqual(decoded.methodID, "diyanet")
        XCTAssertEqual(decoded.notificationDefaults.sound, .adhanMadinah)
    }

    /// The library round-trips and a `.custom` selection flows through the existing
    /// per-prayer resolution unchanged.
    func testCustomSoundsRoundTripAndResolvePerPrayer() throws {
        let id = UUID()
        var s = AppSettings()
        s.customSounds = [CustomSound(id: id, fileName: "\(id.uuidString).mp3", displayName: "Fajr Adhan")]
        s.notifications[.fajr] = PrayerNotificationConfig(playFullAdhanOverride: true, soundOverride: .custom(id))

        let data = try JSONEncoder().encode(s)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertEqual(decoded, s)
        XCTAssertEqual(decoded.customSounds.first?.id, id)
        XCTAssertEqual(decoded.resolvedNotification(for: .fajr).sound, .custom(id))
    }
}
