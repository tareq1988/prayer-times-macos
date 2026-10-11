import Foundation
import Testing
import PrayerKit
@testable import Prayer_Times

/// The detection cache (`lastDetectedLocation.v1`) is what lets a cold start
/// open on the real location instead of the Istanbul default. `city` was added
/// *after* the first release of that cache, so the JSON already sitting on
/// users' disks has no city key: decoding must tolerate that (city stays nil)
/// instead of failing wholesale and dropping the whole cached location.
@MainActor
struct SettingsStoreDetectionCacheTests {
    /// A cache blob exactly as the pre-city build wrote it: no `city` key.
    private let legacyJSON = Data("""
    {
      "latitude": 51.4864,
      "longitude": 7.4946,
      "elevation": 32.0,
      "countryCode": "DE",
      "timeZoneID": "Europe/Berlin",
      "detectedAt": 800000000
    }
    """.utf8)

    /// Fresh, isolated defaults per test — never `.standard`, which the app uses.
    private func withSuite(_ body: (UserDefaults) throws -> Void) rethrows {
        let name = "SettingsStoreDetectionCacheTests.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: name)!
        defer { suite.removePersistentDomain(forName: name) }
        try body(suite)
    }

    @Test("Legacy cache blob without a city key still decodes")
    func legacyCacheDecodesWithoutCity() throws {
        let cached = try JSONDecoder().decode(SettingsStore.CachedDetection.self, from: legacyJSON)
        #expect(cached.city == nil)
        #expect(cached.latitude == 51.4864)
        #expect(cached.countryCode == "DE")
        #expect(cached.timeZoneID == "Europe/Berlin")
    }

    @Test("A cache with a city round-trips through encode/decode")
    func cityRoundTrips() throws {
        let original = SettingsStore.CachedDetection(
            latitude: 51.4864, longitude: 7.4946, elevation: 32,
            city: "Duisburg", countryCode: "DE",
            timeZoneID: "Europe/Berlin", detectedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let data = try JSONEncoder().encode(original)
        // nil cities are omitted by Codable, keyed cities must be present.
        #expect(String(data: data, encoding: .utf8)?.contains("\"city\"") == true)
        let decoded = try JSONDecoder().decode(SettingsStore.CachedDetection.self, from: data)
        #expect(decoded.city == "Duisburg")
        #expect(decoded.latitude == original.latitude)
        #expect(decoded.detectedAt == original.detectedAt)
    }

    @Test("Init seeds detection state from the cached location")
    func initSeedsDetectionFromCache() throws {
        try withSuite { suite in
            suite.set(legacyJSON, forKey: "lastDetectedLocation.v1")
            let store = SettingsStore(location: LocationService(), defaults: suite)
            #expect(store.detectedCoordinates?.latitude == 51.4864)
            #expect(store.detectedCoordinates?.longitude == 7.4946)
            #expect(store.detectedCountryCode == "DE")
            #expect(store.detectedTimeZoneID == "Europe/Berlin")
            // Legacy blob has no city: seeded as nil, not as garbage.
            #expect(store.detectedCity == nil)
        }
    }

    @Test("A current-format cache seeds the city too")
    func initSeedsCity() throws {
        let current = SettingsStore.CachedDetection(
            latitude: 51.4864, longitude: 7.4946, elevation: 32,
            city: "Duisburg", countryCode: "DE",
            timeZoneID: "Europe/Berlin", detectedAt: Date()
        )
        try withSuite { suite in
            suite.set(try JSONEncoder().encode(current), forKey: "lastDetectedLocation.v1")
            let store = SettingsStore(location: LocationService(), defaults: suite)
            #expect(store.detectedCity == "Duisburg")
            #expect(store.detectedCountryCode == "DE")
        }
    }

    @Test("A missing or corrupt cache leaves detection empty, not broken")
    func corruptCacheIsIgnored() throws {
        try withSuite { suite in
            suite.set(Data("not json".utf8), forKey: "lastDetectedLocation.v1")
            let store = SettingsStore(location: LocationService(), defaults: suite)
            #expect(store.detectedCoordinates == nil)
            #expect(store.detectedCity == nil)
        }
    }
}
