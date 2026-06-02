import Foundation
import Observation
import PrayerKit

/// The single source of truth for user configuration. Holds an `AppSettings`
/// blob, persisted as JSON in `UserDefaults`, and exposes the *resolved* inputs
/// the rest of the app needs (coordinates, timezone, calculation parameters).
///
/// Persistence note (spec §8): settings will move to an App Group suite in M8/M9
/// so the widget can read them. That is a one-line change to `suite` once signing
/// + the entitlement land; everything else already round-trips through Codable.
@MainActor
@Observable
final class SettingsStore {

    /// Editing this struct anywhere (incl. via SwiftUI bindings) re-persists it.
    var settings: AppSettings {
        didSet { persist() }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let key = "appSettings.v1"

    /// App Group suite to adopt in M9 for widget sharing. nil → standard defaults.
    static let appGroupSuite: String? = nil   // "group.com.wedevs.prayertimes"

    init(defaults: UserDefaults? = nil) {
        let resolved = defaults
            ?? Self.appGroupSuite.flatMap { UserDefaults(suiteName: $0) }
            ?? .standard
        self.defaults = resolved
        self.settings = Self.load(from: resolved, key: key) ?? Self.firstRunDefaults
    }

    // MARK: Resolved inputs (consumed by PrayerClock / NotificationService)

    /// The coordinates to calculate for. Automatic mode falls back to the manual
    /// coordinates until CoreLocation lands in M5.
    var resolvedCoordinates: Coordinates {
        settings.manualCoordinates ?? Self.defaultCoordinates
    }

    /// The master timezone (system or explicit).
    var resolvedTimeZone: TimeZone {
        settings.timeZoneMode.timeZone
    }

    /// The active adapter (method + optional Hanafi modifier / manual params).
    func resolvedAdapter() -> any CalculationMethodAdapter {
        MethodRegistry.resolve(
            methodID: settings.methodID,
            hanafiAsr: settings.hanafiAsr,
            manualParameters: settings.manualParameters
        ) ?? MWLAdapter()
    }

    /// Display name for the active method, e.g. "Diyanet İşleri (Türkiye)".
    var resolvedMethodName: String {
        resolvedAdapter().displayName
    }

    /// Final calculation parameters: the method's parameters with the user's
    /// high-latitude rule applied on top (the Calculation tab owns that choice).
    func resolvedParameters() -> CalculationParameters {
        var p = resolvedAdapter().resolve(for: resolvedCoordinates)
        p.highLatitudeRule = settings.highLatitudeRule
        return p
    }

    /// Everything that affects the computed times, bundled for change detection.
    var resolvedInputs: ResolvedInputs {
        ResolvedInputs(
            coordinates: resolvedCoordinates,
            timeZoneID: resolvedTimeZone.identifier,
            parameters: resolvedParameters()
        )
    }

    // MARK: Persistence

    private func persist() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }

    private static func load(from defaults: UserDefaults, key: String) -> AppSettings? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(AppSettings.self, from: data)
    }

    // MARK: Defaults

    static let defaultCoordinates = Coordinates(latitude: 41.0082, longitude: 28.9784)

    /// First-run configuration: matches the M2 hardcoded behavior (Istanbul /
    /// Diyanet) so the app looks identical until the user changes anything.
    static var firstRunDefaults: AppSettings {
        AppSettings(
            methodID: "diyanet",
            manualCoordinates: defaultCoordinates,
            timeZoneMode: .explicit(identifier: "Europe/Istanbul")
        )
    }
}

/// The minimal, `Equatable` set of inputs that determine the prayer times. Used
/// by `PrayerClock` to decide whether a recompute is needed.
struct ResolvedInputs: Equatable {
    var coordinates: Coordinates
    var timeZoneID: String
    var parameters: CalculationParameters
}
