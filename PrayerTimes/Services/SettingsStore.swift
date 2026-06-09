import Foundation
import AppKit
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
    @ObservationIgnored private let location: LocationService

    /// True when no settings were persisted yet (a genuine first launch). Lets the
    /// launch path prompt for location permission in automatic mode exactly once,
    /// without re-prompting on every subsequent launch.
    @ObservationIgnored private let isFirstRun: Bool

    // Runtime auto-detect state (not persisted).
    private(set) var detectedCoordinates: Coordinates?
    private(set) var detectedCountryCode: String?
    private(set) var detectedTimeZoneID: String?
    private(set) var isDetectingLocation = false
    private(set) var locationError: String?

    /// App Group suite to adopt in M9 for widget sharing. nil → standard defaults.
    static let appGroupSuite: String? = nil   // "group.co.tareq.prayertimes"

    init(location: LocationService, defaults: UserDefaults? = nil) {
        self.location = location
        let resolved = defaults
            ?? Self.appGroupSuite.flatMap { UserDefaults(suiteName: $0) }
            ?? .standard
        self.defaults = resolved
        let loaded = Self.load(from: resolved, key: key)
        self.isFirstRun = (loaded == nil)
        self.settings = loaded ?? Self.firstRunDefaults
        migrateHighLatitudeRuleIfNeeded()
        migrateMenuBarStyleIfNeeded()
    }

    /// One-time migration (v0.3.0 → next): before `.automatic` existed, the
    /// high-latitude rule defaulted to `.none`, which silently discarded each
    /// method's own recommendation and left Fajr undefined / Isha pinned to solar
    /// midnight at high latitudes (e.g. Kraków in June). Existing users carry a
    /// persisted `.none` that the new `.automatic` default can't reach, so flip a
    /// legacy `.none` to `.automatic` exactly once. The flag means a user who
    /// *deliberately* picks `.none` afterwards keeps it.
    private func migrateHighLatitudeRuleIfNeeded() {
        let flag = "didMigrateHighLatAutomatic.v1"
        guard !defaults.bool(forKey: flag) else { return }
        defaults.set(true, forKey: flag)
        if settings.highLatitudeRule == .none {
            settings.highLatitudeRule = .automatic   // didSet re-persists
        }
    }

    /// One-time migration: the default menu bar style changed from the bare
    /// `.nextPrayerCountdown` ("Asr in 1:24") to `.iconNameCountdown`
    /// ("🌙 Asr in 1:24"). Flip a value still sitting on the *old* default so the
    /// new default reaches existing installs once; a deliberate later choice
    /// (including re-selecting the old style) then sticks.
    private func migrateMenuBarStyleIfNeeded() {
        let flag = "didMigrateMenuBarStyleIcon.v1"
        guard !defaults.bool(forKey: flag) else { return }
        defaults.set(true, forKey: flag)
        if settings.menuBarStyle == .nextPrayerCountdown {
            settings.menuBarStyle = .iconNameCountdown   // didSet re-persists
        }
    }

    // MARK: Resolved inputs (consumed by PrayerClock / NotificationService)

    /// The coordinates to calculate for. Automatic mode uses the detected
    /// location when available, falling back to the manual coordinates.
    var resolvedCoordinates: Coordinates {
        if settings.locationMode == .automatic, let detected = detectedCoordinates {
            return detected
        }
        return settings.manualCoordinates ?? Self.defaultCoordinates
    }

    /// Transparent label for the auto-detected method (spec §7.7), e.g.
    /// "Auto: Diyanet İşleri (Türkiye)". nil when auto-detect is off.
    var autoMethodLabel: String? {
        guard settings.autoDetectMethod else { return nil }
        guard let code = detectedCountryCode else { return String(localized: "Auto-detect on — locating…") }
        let country = Locale.current.localizedString(forRegionCode: code) ?? code
        return String(localized: "Auto: \(resolvedMethodName) (\(country))")
    }

    // MARK: Auto-detect (CoreLocation)

    /// On launch, detect the location when the user is in automatic mode. On a
    /// genuine first launch we *do* prompt for permission (the new default is
    /// automatic, so the app should work out of the box). On every later launch we
    /// only refresh silently when permission was already granted — never re-prompt
    /// (a user who declined or switched to Manual is left alone).
    func detectLocationIfNeeded() async {
        let wantsAuto = settings.locationMode == .automatic || settings.autoDetectMethod
        guard wantsAuto else { return }
        let authorized = location.authorization == .authorized || location.authorization == .authorizedAlways
        guard authorized || isFirstRun else { return }
        await detectLocation()
    }

    /// Switch the location mode. Crucially, going Automatic → Manual seeds the
    /// editable coordinates from the *currently resolved* location (the detected
    /// position while still in automatic mode), so the manual fields continue from
    /// where automatic left off instead of snapping back to the stale stored value
    /// (which, on a fresh install, is the Istanbul default — a user in Dhaka would
    /// otherwise flip to Manual and get Istanbul). Capture before changing the mode:
    /// `resolvedCoordinates` only returns the detected value while still automatic.
    func setLocationMode(_ mode: LocationMode) {
        if mode == .manual {
            settings.manualCoordinates = resolvedCoordinates
        }
        settings.locationMode = mode
        if mode == .automatic {
            Task { await detectLocation() }
        }
    }

    /// Detect location once and (if auto-detect-method is on) pick the method
    /// from the resolved country (spec §7.7).
    func detectLocation() async {
        // Coalesce overlapping requests (e.g. launch auto-detect racing a manual
        // toggle): a second call while one is in flight is a no-op.
        guard !isDetectingLocation else { return }
        isDetectingLocation = true
        locationError = nil
        defer { isDetectingLocation = false }
        do {
            let loc = try await location.fetchCurrent()
            detectedCoordinates = Coordinates(
                latitude: loc.coordinate.latitude,
                longitude: loc.coordinate.longitude,
                elevation: loc.altitude
            )
            let place = await location.place(for: loc)
            detectedCountryCode = place.countryCode
            detectedTimeZoneID = place.timeZone?.identifier
            if settings.autoDetectMethod, let code = place.countryCode {
                settings.methodID = MethodRegistry.methodID(forCountryCode: code)
            }
            // Lock the master timezone to the detected location so the coordinates
            // and the clock always describe the same place. Only override when they
            // actually differ, to avoid needlessly flipping "Follow system".
            if let tz = place.timeZone, tz.identifier != resolvedTimeZone.identifier {
                settings.timeZoneMode = .explicit(identifier: tz.identifier)
            }
        } catch {
            locationError = error.localizedDescription
        }
    }

    /// Warn when the detected location's timezone and the active master timezone
    /// describe different places (e.g. the user manually picked a conflicting
    /// zone after auto-detect) — prayer times would then be computed for one
    /// place but shown on another's clock. nil when coherent or nothing detected.
    var timeZoneMismatchWarning: String? {
        guard settings.locationMode == .automatic,
              let detected = detectedTimeZoneID,
              detected != resolvedTimeZone.identifier
        else { return nil }
        return String(localized:
            "Your timezone (\(resolvedTimeZone.identifier)) doesn't match your detected location (\(detected)). Prayer times may be wrong — switch the timezone to “Follow system” or the matching zone.")
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

    /// Final calculation parameters: the method's parameters, with the user's
    /// explicit high-latitude rule applied on top. `.automatic` (the default)
    /// keeps the method's own recommended rule — e.g. MWL ships `.angleBased`,
    /// which is what supplies a sane Fajr/Isha in northern Europe where the sun
    /// never reaches the twilight depression angle in summer. Only a deliberate
    /// non-automatic choice overrides that.
    func resolvedParameters() -> CalculationParameters {
        var p = resolvedAdapter().resolve(for: resolvedCoordinates)
        if settings.highLatitudeRule != .automatic {
            p.highLatitudeRule = settings.highLatitudeRule
        }
        return p
    }

    /// Everything that affects the computed times, bundled for change detection.
    var resolvedInputs: ResolvedInputs {
        ResolvedInputs(
            coordinates: resolvedCoordinates,
            timeZoneID: resolvedTimeZone.identifier,
            parameters: resolvedParameters(),
            manual: resolvedManualSchedule
        )
    }

    /// The fixed jamaat schedule, present only when the time source is Manual.
    /// Folded into `resolvedInputs` so the clock recomputes when the user edits a
    /// jamaat time, toggles the mode, or changes the global azan offset.
    var resolvedManualSchedule: ManualSchedule? {
        guard settings.calculationMode == .manual else { return nil }
        return ManualSchedule(
            jamaatMinutes: settings.jamaatTimes,
            azanBeforeJamaat: settings.azanBeforeJamaat,
            keepWaqt: settings.manualKeepWaqt
        )
    }

    // MARK: Language override (§7.9)

    /// Set the UI language and relaunch. Writing `AppleLanguages` makes the
    /// String Catalog, `String(localized:)`, locale-aware formatting, and RTL all
    /// switch consistently on the next launch — which is why a relaunch is needed
    /// (the string table can't be swapped reliably mid-run).
    func applyLanguageOverride(_ code: String?) {
        settings.languageOverride = code
        if let code {
            defaults.set([code], forKey: "AppleLanguages")
        } else {
            defaults.removeObject(forKey: "AppleLanguages")
        }
        relaunch()
    }

    private func relaunch() {
        let url = Bundle.main.bundleURL
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in
            Task { @MainActor in NSApp.terminate(nil) }
        }
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

    /// First-run configuration: location-aware out of the box. Automatic mode
    /// (prompts + detects on first launch — see `detectLocationIfNeeded`), the
    /// system timezone so the clock is the user's *own* zone even before/​without
    /// a location fix, and the global MWL method with auto-detect on so it tracks
    /// the detected country. The Istanbul `defaultCoordinates` survive only as the
    /// fallback when location permission is denied. (Previously this shipped a
    /// hardcoded manual Istanbul/Diyanet, so a first-time user in Dhaka got
    /// Istanbul times.)
    static var firstRunDefaults: AppSettings {
        AppSettings(
            methodID: "mwl",
            locationMode: .automatic,
            manualCoordinates: defaultCoordinates,
            timeZoneMode: .system,
            autoDetectMethod: true
        )
    }
}

/// The minimal, `Equatable` set of inputs that determine the prayer times. Used
/// by `PrayerClock` to decide whether a recompute is needed.
struct ResolvedInputs: Equatable {
    var coordinates: Coordinates
    var timeZoneID: String
    var parameters: CalculationParameters
    /// Present only in Manual (fixed) time-source mode; overlays the five
    /// obligatory times onto the astronomical computation.
    var manual: ManualSchedule?
}

/// The fixed-schedule overlay for Manual time-source mode (design: Calculation
/// tab). Carries the announced jamaat times and the global azan-before offset.
struct ManualSchedule: Equatable {
    /// Jamaat times for the obligatory prayers, as minutes since local midnight.
    var jamaatMinutes: [Prayer: Int]
    /// Minutes before the jamaat time that the azan reminder fires.
    var azanBeforeJamaat: Int
    /// Keep astronomical Sunrise & windows (always true today — Sunrise has no
    /// jamaat — but plumbed for future per-event control).
    var keepWaqt: Bool

    /// Overlay the jamaat times onto an astronomically-computed day: replace each
    /// obligatory prayer's instant with its jamaat time on the same civil day,
    /// leaving Sunrise (and any undefined times) untouched.
    func applied(to base: PrayerTimes, day: Date, timeZone: TimeZone) -> PrayerTimes {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let midnight = cal.startOfDay(for: day)
        var times = base.times
        for prayer in Prayer.obligatory {
            guard let minutes = jamaatMinutes[prayer] else { continue }
            times[prayer] = midnight.addingTimeInterval(TimeInterval(minutes) * 60)
        }
        return PrayerTimes(date: base.date, times: times)
    }
}
