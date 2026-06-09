import Foundation

/// Menu bar label content (§7.1). Raw values are stable for persistence.
public enum MenuBarStyle: String, Codable, Sendable, CaseIterable, Hashable {
    case iconOnly                       // 🌙
    case countdownOnly                  // "in 1:24"
    case iconCountdown                  // 🌙 in 1:24
    case nextPrayerCountdown            // "Asr in 1:24"
    case iconNameCountdown              // 🌙 Asr in 1:24  (default)
    case nextPrayerClock                // "Asr 16:42"
    case iconNameClock                  // 🌙 Asr 16:42

    /// Whether the label shows the (contextual) prayer icon.
    public var showsIcon: Bool {
        switch self {
        case .iconOnly, .iconCountdown, .iconNameCountdown, .iconNameClock: return true
        default: return false
        }
    }

    /// Whether the label shows the prayer name.
    public var showsName: Bool {
        switch self {
        case .nextPrayerCountdown, .iconNameCountdown, .nextPrayerClock, .iconNameClock: return true
        default: return false
        }
    }

    /// What the trailing value (if any) represents.
    public enum Value { case none, countdown, clock }
    public var value: Value {
        switch self {
        case .iconOnly: return .none
        case .nextPrayerClock, .iconNameClock: return .clock
        default: return .countdown
        }
    }
}

/// What the menu bar countdown counts toward (§7.1). The label layout (icon /
/// name / value) is chosen by `MenuBarStyle`; this picks what a countdown value
/// *means*, independent of that layout.
public enum MenuBarCountdownMode: String, Codable, Sendable, CaseIterable, Hashable {
    case nextPrayer   // time until the next prayer begins — "Asr in 40m" (default)
    case currentWaqt  // time left in the current prayer's window — "Asr 40m left"
}

/// Strength of the Focus Mode backdrop blur over the desktop. Maps to a visual
/// material/opacity in the app layer.
public enum FocusBlurIntensity: String, Codable, Sendable, CaseIterable, Hashable {
    case low
    case medium
    case high
    case opaque   // near-solid dark cover
}

/// Which prayers engage Focus Mode (design: Focus tab "Trigger on").
public enum FocusTrigger: String, Codable, Sendable, CaseIterable, Hashable {
    case obligatory   // the five obligatory prayers (default)
    case all          // every tracked time, including Sunrise
    case fajrIsha     // only the two night-bounding prayers

    /// Whether `prayer` should trigger a block under this rule.
    public func includes(_ prayer: Prayer) -> Bool {
        switch self {
        case .obligatory: return prayer.isObligatory
        case .all: return true
        case .fajrIsha: return prayer == .fajr || prayer == .isha
        }
    }
}

/// How the daily prayer times are sourced (design: Calculation tab "Time source").
public enum CalculationMode: String, Codable, Sendable, CaseIterable, Hashable {
    case calculated   // astronomical, from the location + method (default)
    case manual       // the five obligatory times come from a fixed jamaat schedule
}

/// How the observer location is determined (§7.6).
public enum LocationMode: String, Codable, Sendable, CaseIterable, Hashable {
    case automatic   // one-shot CoreLocation
    case manual      // user-entered city / lat-lon
}

/// How the display timezone ("master time") is chosen (§7.6).
public enum TimeZoneMode: Codable, Sendable, Equatable, Hashable {
    case system
    case explicit(identifier: String)

    /// Resolve to a concrete `TimeZone`, falling back to the current zone.
    public var timeZone: TimeZone {
        switch self {
        case .system: return .current
        case .explicit(let id): return TimeZone(identifier: id) ?? .current
        }
    }
}

/// App-wide notification defaults (design: Notifications tab "Defaults"). Applied
/// to every prayer unless a per-prayer override is set. The sound, early-reminder
/// lead, and iqamah offset are inheritable; a `PrayerNotificationConfig` leaves the
/// matching override `nil` to fall through to these.
public struct NotificationDefaults: Codable, Sendable, Equatable, Hashable {
    public var sound: NotificationSound
    public var playFullAdhan: Bool
    /// Minutes before the prayer for the early reminder; 0 = off.
    public var earlyReminderMinutes: Int
    /// Minutes after the prayer for the iqamah alert; 0 = off.
    public var iqamahOffsetMinutes: Int

    public init(
        sound: NotificationSound = .takbir,
        playFullAdhan: Bool = false,
        earlyReminderMinutes: Int = 0,
        iqamahOffsetMinutes: Int = 0
    ) {
        self.sound = sound
        self.playFullAdhan = playFullAdhan
        self.earlyReminderMinutes = earlyReminderMinutes
        self.iqamahOffsetMinutes = iqamahOffsetMinutes
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = NotificationDefaults()
        sound = try c.decodeIfPresent(NotificationSound.self, forKey: .sound) ?? d.sound
        playFullAdhan = try c.decodeIfPresent(Bool.self, forKey: .playFullAdhan) ?? d.playFullAdhan
        earlyReminderMinutes = try c.decodeIfPresent(Int.self, forKey: .earlyReminderMinutes) ?? d.earlyReminderMinutes
        iqamahOffsetMinutes = try c.decodeIfPresent(Int.self, forKey: .iqamahOffsetMinutes) ?? d.iqamahOffsetMinutes
    }
}

/// Per-prayer notification configuration with default inheritance (§7.3, §7.4,
/// design: Notifications matrix + override drawer). The three booleans map to the
/// matrix columns (Notify / Adhan / Remind); the three optionals are overrides
/// that fall back to `NotificationDefaults` when `nil`.
public struct PrayerNotificationConfig: Codable, Sendable, Equatable, Hashable {
    /// Matrix "Notify" — the prayer-entry notification.
    public var notify: Bool
    /// Matrix "Adhan" — play the full Adhan in-process (obligatory prayers only).
    public var playFullAdhan: Bool
    /// Matrix "Remind" — fire the early reminder.
    public var earlyReminderEnabled: Bool

    /// Drawer "Sound" — `nil` inherits `NotificationDefaults.sound`.
    public var soundOverride: NotificationSound?
    /// Drawer "Early reminder" lead minutes — `nil` inherits the default lead.
    public var earlyLeadMinutesOverride: Int?
    /// Drawer "Iqamah / jamaat offset" — `nil` inherits the default offset.
    public var iqamahOffsetMinutesOverride: Int?

    public init(
        notify: Bool = true,
        playFullAdhan: Bool = false,
        earlyReminderEnabled: Bool = false,
        soundOverride: NotificationSound? = nil,
        earlyLeadMinutesOverride: Int? = nil,
        iqamahOffsetMinutesOverride: Int? = nil
    ) {
        self.notify = notify
        self.playFullAdhan = playFullAdhan
        self.earlyReminderEnabled = earlyReminderEnabled
        self.soundOverride = soundOverride
        self.earlyLeadMinutesOverride = earlyLeadMinutesOverride
        self.iqamahOffsetMinutesOverride = iqamahOffsetMinutesOverride
    }

    /// Resilient decode so an older persisted blob (whose per-prayer keys differ)
    /// simply falls back to the inheriting defaults rather than failing the whole
    /// settings decode.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = PrayerNotificationConfig()
        notify = try c.decodeIfPresent(Bool.self, forKey: .notify) ?? d.notify
        playFullAdhan = try c.decodeIfPresent(Bool.self, forKey: .playFullAdhan) ?? d.playFullAdhan
        earlyReminderEnabled = try c.decodeIfPresent(Bool.self, forKey: .earlyReminderEnabled) ?? d.earlyReminderEnabled
        soundOverride = try c.decodeIfPresent(NotificationSound.self, forKey: .soundOverride)
        earlyLeadMinutesOverride = try c.decodeIfPresent(Int.self, forKey: .earlyLeadMinutesOverride)
        iqamahOffsetMinutesOverride = try c.decodeIfPresent(Int.self, forKey: .iqamahOffsetMinutesOverride)
    }
}

/// The fully-resolved notification behaviour for one prayer, after merging the
/// per-prayer config over the app defaults. This is what the scheduler and the
/// in-process Adhan path consume — they never read inheritance directly.
public struct ResolvedNotification: Sendable, Equatable, Hashable {
    public var notify: Bool
    public var sound: NotificationSound
    public var playFullAdhan: Bool
    public var earlyReminderEnabled: Bool
    public var earlyLeadMinutes: Int
    public var iqamahOffsetMinutes: Int
}

/// The full persisted configuration blob (§8). Stored in UserDefaults / the App
/// Group so the widget reads the same state.
public struct AppSettings: Codable, Sendable, Equatable {
    public var methodID: String
    public var manualParameters: CalculationParameters?
    public var hanafiAsr: Bool
    public var highLatitudeRule: HighLatitudeRule
    public var locationMode: LocationMode
    public var manualCoordinates: Coordinates?
    public var timeZoneMode: TimeZoneMode
    public var autoDetectMethod: Bool

    // Time source (design: Calculation tab). `.manual` sources the five obligatory
    // times from `jamaatTimes` and fires the azan `azanBeforeJamaat` minutes early.
    public var calculationMode: CalculationMode
    /// Minutes before each jamaat time that the azan reminder fires (0 = at jamaat).
    public var azanBeforeJamaat: Int
    /// Keep astronomical Sunrise & non-jamaat windows while in manual mode.
    public var manualKeepWaqt: Bool
    /// Fixed jamaat times for the five obligatory prayers, as minutes since
    /// local midnight (0…1439). Used only when `calculationMode == .manual`.
    public var jamaatTimes: [Prayer: Int]

    public var menuBarStyle: MenuBarStyle
    public var menuBarCountdownMode: MenuBarCountdownMode
    public var showIshraqTime: Bool
    /// Whether the dropdown panel shows the Hijri date line (design: General tab).
    public var showHijriDate: Bool
    /// Whole-day correction applied to the displayed Umm al-Qura Hijri date so it
    /// can match the user's country, whose moon-sighting may differ from the
    /// calculated calendar (e.g. Bangladesh vs Saudi Arabia). Typically −2…+2.
    public var hijriDayAdjustment: Int

    // Focus Mode (§ issue #2): cover the screen at prayer time as a discipline aid.
    public var focusModeEnabled: Bool
    public var focusDurationMinutes: Int
    public var focusBlurIntensity: FocusBlurIntensity
    public var focusTrigger: FocusTrigger
    public var focusEmergencyExitEnabled: Bool

    public var launchAtLogin: Bool
    public var languageOverride: String?            // BCP-47, nil = follow system
    public var masterNotificationsEnabled: Bool     // global on/off (spec §7.6)
    public var notificationDefaults: NotificationDefaults
    public var notifications: [Prayer: PrayerNotificationConfig]
    public var autoUpdateEnabled: Bool

    public init(
        methodID: String = "mwl",
        manualParameters: CalculationParameters? = nil,
        hanafiAsr: Bool = false,
        highLatitudeRule: HighLatitudeRule = .automatic,
        locationMode: LocationMode = .automatic,
        manualCoordinates: Coordinates? = nil,
        timeZoneMode: TimeZoneMode = .system,
        autoDetectMethod: Bool = false,
        calculationMode: CalculationMode = .calculated,
        azanBeforeJamaat: Int = 15,
        manualKeepWaqt: Bool = true,
        jamaatTimes: [Prayer: Int] = AppSettings.defaultJamaatTimes,
        menuBarStyle: MenuBarStyle = .iconNameCountdown,
        menuBarCountdownMode: MenuBarCountdownMode = .nextPrayer,
        showIshraqTime: Bool = false,
        showHijriDate: Bool = true,
        hijriDayAdjustment: Int = 0,
        focusModeEnabled: Bool = false,
        focusDurationMinutes: Int = 15,
        focusBlurIntensity: FocusBlurIntensity = .medium,
        focusTrigger: FocusTrigger = .obligatory,
        focusEmergencyExitEnabled: Bool = true,
        launchAtLogin: Bool = false,
        languageOverride: String? = nil,
        masterNotificationsEnabled: Bool = true,
        notificationDefaults: NotificationDefaults = NotificationDefaults(),
        notifications: [Prayer: PrayerNotificationConfig] = AppSettings.defaultNotifications,
        autoUpdateEnabled: Bool = true
    ) {
        self.methodID = methodID
        self.manualParameters = manualParameters
        self.hanafiAsr = hanafiAsr
        self.highLatitudeRule = highLatitudeRule
        self.locationMode = locationMode
        self.manualCoordinates = manualCoordinates
        self.timeZoneMode = timeZoneMode
        self.autoDetectMethod = autoDetectMethod
        self.calculationMode = calculationMode
        self.azanBeforeJamaat = azanBeforeJamaat
        self.manualKeepWaqt = manualKeepWaqt
        self.jamaatTimes = jamaatTimes
        self.menuBarStyle = menuBarStyle
        self.menuBarCountdownMode = menuBarCountdownMode
        self.showIshraqTime = showIshraqTime
        self.showHijriDate = showHijriDate
        self.hijriDayAdjustment = hijriDayAdjustment
        self.focusModeEnabled = focusModeEnabled
        self.focusDurationMinutes = focusDurationMinutes
        self.focusBlurIntensity = focusBlurIntensity
        self.focusTrigger = focusTrigger
        self.focusEmergencyExitEnabled = focusEmergencyExitEnabled
        self.launchAtLogin = launchAtLogin
        self.languageOverride = languageOverride
        self.masterNotificationsEnabled = masterNotificationsEnabled
        self.notificationDefaults = notificationDefaults
        self.notifications = notifications
        self.autoUpdateEnabled = autoUpdateEnabled
    }

    /// Resilient decoding: every field is optional-with-default so that adding a
    /// new property in a later release does not fail to decode an older persisted
    /// blob (which would silently reset the user to first-run defaults). Each
    /// missing key falls back to the memberwise-init default.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        func get<T: Decodable>(_ key: CodingKeys, _ fallback: T) throws -> T {
            try c.decodeIfPresent(T.self, forKey: key) ?? fallback
        }
        methodID = try get(.methodID, d.methodID)
        manualParameters = try c.decodeIfPresent(CalculationParameters.self, forKey: .manualParameters)
        hanafiAsr = try get(.hanafiAsr, d.hanafiAsr)
        highLatitudeRule = try get(.highLatitudeRule, d.highLatitudeRule)
        locationMode = try get(.locationMode, d.locationMode)
        manualCoordinates = try c.decodeIfPresent(Coordinates.self, forKey: .manualCoordinates)
        timeZoneMode = try get(.timeZoneMode, d.timeZoneMode)
        autoDetectMethod = try get(.autoDetectMethod, d.autoDetectMethod)
        calculationMode = try get(.calculationMode, d.calculationMode)
        azanBeforeJamaat = try get(.azanBeforeJamaat, d.azanBeforeJamaat)
        manualKeepWaqt = try get(.manualKeepWaqt, d.manualKeepWaqt)
        jamaatTimes = try get(.jamaatTimes, d.jamaatTimes)
        menuBarStyle = try get(.menuBarStyle, d.menuBarStyle)
        menuBarCountdownMode = try get(.menuBarCountdownMode, d.menuBarCountdownMode)
        showIshraqTime = try get(.showIshraqTime, d.showIshraqTime)
        showHijriDate = try get(.showHijriDate, d.showHijriDate)
        hijriDayAdjustment = try get(.hijriDayAdjustment, d.hijriDayAdjustment)
        focusModeEnabled = try get(.focusModeEnabled, d.focusModeEnabled)
        focusDurationMinutes = try get(.focusDurationMinutes, d.focusDurationMinutes)
        focusBlurIntensity = try get(.focusBlurIntensity, d.focusBlurIntensity)
        focusTrigger = try get(.focusTrigger, d.focusTrigger)
        focusEmergencyExitEnabled = try get(.focusEmergencyExitEnabled, d.focusEmergencyExitEnabled)
        launchAtLogin = try get(.launchAtLogin, d.launchAtLogin)
        languageOverride = try c.decodeIfPresent(String.self, forKey: .languageOverride)
        masterNotificationsEnabled = try get(.masterNotificationsEnabled, d.masterNotificationsEnabled)
        notificationDefaults = try get(.notificationDefaults, d.notificationDefaults)
        notifications = try get(.notifications, d.notifications)
        autoUpdateEnabled = try get(.autoUpdateEnabled, d.autoUpdateEnabled)
    }

    // MARK: Resolved notification behaviour

    /// Sensible fallback lead used when a prayer's reminder is switched on but
    /// neither it nor the global default supplies a concrete lead. The UI seeds
    /// this as an explicit per-prayer value on toggle, so resolution stays
    /// transparent (no hidden minutes) and the matrix toggle always does something.
    public static let fallbackEarlyLeadMinutes = 15

    /// Effective early-reminder lead for `prayer`: the per-prayer override, else
    /// the global default. May be 0 (meaning "no lead set").
    public func earlyLeadMinutes(for prayer: Prayer) -> Int {
        notifications[prayer]?.earlyLeadMinutesOverride ?? notificationDefaults.earlyReminderMinutes
    }

    /// Merge a prayer's per-prayer config over the app defaults into the concrete
    /// values the scheduler uses. A reminder fires only when it is enabled *and*
    /// resolves to a positive lead. Sunrise never carries Adhan or iqamah.
    public func resolvedNotification(for prayer: Prayer) -> ResolvedNotification {
        let cfg = notifications[prayer] ?? PrayerNotificationConfig()
        let lead = earlyLeadMinutes(for: prayer)
        let iqamah = prayer.isObligatory
            ? (cfg.iqamahOffsetMinutesOverride ?? notificationDefaults.iqamahOffsetMinutes)
            : 0
        return ResolvedNotification(
            notify: cfg.notify,
            sound: cfg.soundOverride ?? notificationDefaults.sound,
            playFullAdhan: prayer.isObligatory && cfg.playFullAdhan,
            earlyReminderEnabled: cfg.earlyReminderEnabled && lead > 0,
            earlyLeadMinutes: max(1, lead),
            iqamahOffsetMinutes: max(0, iqamah)
        )
    }

    // MARK: Defaults

    /// Placeholder jamaat schedule (minutes since midnight) seeded for Manual mode.
    /// The user replaces these with their mosque's announced times.
    public static var defaultJamaatTimes: [Prayer: Int] {
        [
            .fajr: 5 * 60,        // 05:00
            .dhuhr: 13 * 60 + 30, // 13:30
            .asr: 17 * 60,        // 17:00
            .maghrib: 18 * 60 + 30, // 18:30 (overwritten by the user; mosques track sunset)
            .isha: 20 * 60,       // 20:00
        ]
    }

    /// Sensible per-prayer defaults, including the product-owner examples:
    /// Dhuhr early reminder 20 min, Maghrib 10 min (§7.3). Sunrise gets a quiet
    /// config (no notification). Reminders are expressed as per-prayer lead
    /// overrides on top of the (off-by-default) global early-reminder default.
    public static var defaultNotifications: [Prayer: PrayerNotificationConfig] {
        var configs: [Prayer: PrayerNotificationConfig] = [:]
        for prayer in Prayer.allCases {
            switch prayer {
            case .sunrise:
                configs[prayer] = PrayerNotificationConfig(notify: false)
            case .dhuhr:
                configs[prayer] = PrayerNotificationConfig(
                    earlyReminderEnabled: true, earlyLeadMinutesOverride: 20)
            case .maghrib:
                configs[prayer] = PrayerNotificationConfig(
                    earlyReminderEnabled: true, earlyLeadMinutesOverride: 10)
            default:
                configs[prayer] = PrayerNotificationConfig()
            }
        }
        return configs
    }
}
