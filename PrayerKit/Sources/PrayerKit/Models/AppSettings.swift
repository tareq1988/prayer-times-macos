import Foundation

/// Menu bar label content (§7.1). Raw values are stable for persistence.
public enum MenuBarStyle: String, Codable, Sendable, CaseIterable, Hashable {
    case iconOnly                       // 🌙
    case countdownOnly                  // "1:24"
    case iconCountdown                  // 🌙 1:24
    case nextPrayerCountdown            // "Asr 1:24"  (default)
    case iconNameCountdown              // 🌙 Asr 1:24
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

/// Per-prayer notification configuration: the prayer-entry notification, the
/// "early" reminder (own lead time + sound), and the iqamah offset/notification
/// (§7.3, §7.4). Each of the six prayers carries its own copy.
public struct PrayerNotificationConfig: Codable, Sendable, Equatable, Hashable {
    public var prayerNotificationEnabled: Bool
    public var prayerSound: NotificationSound
    public var playFullAdhan: Bool

    public var earlyReminderEnabled: Bool
    public var earlyLeadMinutes: Int
    public var earlySound: NotificationSound

    public var iqamahOffsetMinutes: Int          // 0 = disabled (never set for Sunrise)
    public var iqamahNotificationEnabled: Bool
    public var iqamahSound: NotificationSound

    public init(
        prayerNotificationEnabled: Bool = true,
        prayerSound: NotificationSound = .takbir,
        playFullAdhan: Bool = false,
        earlyReminderEnabled: Bool = false,
        earlyLeadMinutes: Int = 15,
        earlySound: NotificationSound = .softChime,
        iqamahOffsetMinutes: Int = 0,
        iqamahNotificationEnabled: Bool = false,
        iqamahSound: NotificationSound = .softChime
    ) {
        self.prayerNotificationEnabled = prayerNotificationEnabled
        self.prayerSound = prayerSound
        self.playFullAdhan = playFullAdhan
        self.earlyReminderEnabled = earlyReminderEnabled
        self.earlyLeadMinutes = earlyLeadMinutes
        self.earlySound = earlySound
        self.iqamahOffsetMinutes = iqamahOffsetMinutes
        self.iqamahNotificationEnabled = iqamahNotificationEnabled
        self.iqamahSound = iqamahSound
    }
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
    public var menuBarStyle: MenuBarStyle
    public var launchAtLogin: Bool
    public var languageOverride: String?            // BCP-47, nil = follow system
    public var masterNotificationsEnabled: Bool     // global on/off (spec §7.6)
    public var notifications: [Prayer: PrayerNotificationConfig]
    public var autoUpdateEnabled: Bool

    public init(
        methodID: String = "mwl",
        manualParameters: CalculationParameters? = nil,
        hanafiAsr: Bool = false,
        highLatitudeRule: HighLatitudeRule = .none,
        locationMode: LocationMode = .automatic,
        manualCoordinates: Coordinates? = nil,
        timeZoneMode: TimeZoneMode = .system,
        autoDetectMethod: Bool = false,
        menuBarStyle: MenuBarStyle = .nextPrayerCountdown,
        launchAtLogin: Bool = false,
        languageOverride: String? = nil,
        masterNotificationsEnabled: Bool = true,
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
        self.menuBarStyle = menuBarStyle
        self.launchAtLogin = launchAtLogin
        self.languageOverride = languageOverride
        self.masterNotificationsEnabled = masterNotificationsEnabled
        self.notifications = notifications
        self.autoUpdateEnabled = autoUpdateEnabled
    }

    /// Sensible per-prayer defaults, including the product-owner examples:
    /// Dhuhr early reminder 20 min, Maghrib 10 min (§7.3). Sunrise gets a quiet
    /// config (no Adhan, no iqamah).
    public static var defaultNotifications: [Prayer: PrayerNotificationConfig] {
        var configs: [Prayer: PrayerNotificationConfig] = [:]
        for prayer in Prayer.allCases {
            switch prayer {
            case .sunrise:
                configs[prayer] = PrayerNotificationConfig(
                    prayerNotificationEnabled: false,
                    prayerSound: .none,
                    earlyReminderEnabled: false
                )
            case .dhuhr:
                configs[prayer] = PrayerNotificationConfig(
                    earlyReminderEnabled: true, earlyLeadMinutes: 20
                )
            case .maghrib:
                configs[prayer] = PrayerNotificationConfig(
                    earlyReminderEnabled: true, earlyLeadMinutes: 10
                )
            default:
                configs[prayer] = PrayerNotificationConfig()
            }
        }
        return configs
    }
}
