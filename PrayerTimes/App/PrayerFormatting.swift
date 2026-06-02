import Foundation
import PrayerKit

/// Presentation helpers for the app layer. Prayer display names are English-only
/// for M2; M6 moves all of these into the String Catalog with localized,
/// locale-aware formatting. The timezone-aware formatters already honor the
/// master timezone so M3 can wire settings in without reworking the views.
enum PrayerFormatting {

    /// Localized display name for a prayer.
    static func name(_ prayer: Prayer) -> String {
        switch prayer {
        case .fajr: return String(localized: "Fajr")
        case .sunrise: return String(localized: "Sunrise")
        case .dhuhr: return String(localized: "Dhuhr")
        case .asr: return String(localized: "Asr")
        case .maghrib: return String(localized: "Maghrib")
        case .isha: return String(localized: "Isha")
        }
    }

    /// SF Symbol representing each prayer's time of day.
    static func icon(_ prayer: Prayer) -> String {
        switch prayer {
        case .fajr: return "sunrise"
        case .sunrise: return "sun.horizon.fill"
        case .dhuhr: return "sun.max.fill"
        case .asr: return "cloud.sun.fill"
        case .maghrib: return "sunset.fill"
        case .isha: return "moon.stars.fill"
        }
    }

    /// Short clock time (e.g. "13:08" / "1:08 PM") in the given timezone.
    static func clock(_ date: Date, in timeZone: TimeZone) -> String {
        var fmt = Date.FormatStyle(date: .omitted, time: .shortened)
        fmt.timeZone = timeZone
        return date.formatted(fmt)
    }

    /// Long date (e.g. "Monday, 2 June 2026") in the given timezone.
    static func longDate(_ date: Date, in timeZone: TimeZone) -> String {
        var fmt = Date.FormatStyle(date: .complete, time: .omitted)
        fmt.timeZone = timeZone
        return date.formatted(fmt)
    }

    /// Compact countdown for the menu bar label: "1:24:30", "24:30", or "0:42".
    /// Shows seconds only under a minute so the menu bar isn't visually noisy.
    static func countdownLabel(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.down))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        if h > 0 { return String(format: "%d:%02d", h, m) }
        if m > 0 { return String(format: "%d:%02d", m, s) }
        return String(format: "0:%02d", s)
    }

    /// Full H:MM:SS countdown for the panel's highlighted next prayer.
    static func countdownLong(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.down))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return String(format: "%d:%02d:%02d", h, m, s)
    }

    /// Compact relative countdown for chips: "3h 25m", "25m", or "45s".
    static func shortCountdown(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.down))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m" }
        return "\(s)s"
    }

    // MARK: Settings enum names (placeholders until M6 localization)

    static func menuBarStyleName(_ style: MenuBarStyle) -> String {
        switch style {
        case .iconOnly: return String(localized: "Icon only")
        case .countdownOnly: return String(localized: "Countdown only")
        case .iconCountdown: return String(localized: "Icon + countdown")
        case .nextPrayerCountdown: return String(localized: "Name + countdown")
        case .iconNameCountdown: return String(localized: "Icon + name + countdown")
        case .nextPrayerClock: return String(localized: "Name + time")
        case .iconNameClock: return String(localized: "Icon + name + time")
        }
    }

    static func highLatitudeRuleName(_ rule: HighLatitudeRule) -> String {
        switch rule {
        case .none: return String(localized: "None")
        case .middleOfNight: return String(localized: "Middle of the night")
        case .seventhOfNight: return String(localized: "One-seventh of the night")
        case .angleBased: return String(localized: "Angle-based")
        }
    }

    static func soundName(_ sound: NotificationSound) -> String {
        switch sound {
        case .none: return String(localized: "None")
        case .systemDefault: return String(localized: "Default")
        case .softChime: return String(localized: "Soft chime")
        case .takbir: return String(localized: "Takbir")
        case .adhanMakkah: return String(localized: "Adhan (Makkah)")
        case .adhanMadinah: return String(localized: "Adhan (Madinah)")
        }
    }
}
