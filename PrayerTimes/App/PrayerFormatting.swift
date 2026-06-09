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

    static func blurIntensityName(_ intensity: FocusBlurIntensity) -> String {
        switch intensity {
        case .low: return String(localized: "Low")
        case .medium: return String(localized: "Medium")
        case .high: return String(localized: "High")
        case .opaque: return String(localized: "Opaque")
        }
    }

    static func focusTriggerName(_ trigger: FocusTrigger) -> String {
        switch trigger {
        case .obligatory: return String(localized: "Obligatory prayers")
        case .all: return String(localized: "All prayer times")
        case .fajrIsha: return String(localized: "Fajr & Isha only")
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

    /// Localized Hijri date (e.g. "22 Dhuʻl-Hijjah 1447 AH") from the Umm al-Qura
    /// calendar, with a whole-day `adjustment` applied so the user can align it to
    /// their country's moon-sighting. Month names follow the current locale.
    ///
    /// Composed from components rather than a `Date.FormatStyle` so the era is a
    /// term we control: Foundation force-appends an era for Islamic calendars and
    /// mislocalizes it in some languages (e.g. Bengali renders "AH" as "যুগ").
    static func hijriDate(_ date: Date, in timeZone: TimeZone, adjustment: Int) -> String {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = timeZone
        let adjusted = gregorian.date(byAdding: .day, value: adjustment, to: date) ?? date

        var hijri = Calendar(identifier: .islamicUmmAlQura)
        hijri.timeZone = timeZone
        let parts = hijri.dateComponents([.day, .month, .year], from: adjusted)
        guard let day = parts.day, let month = parts.month, let year = parts.year else { return "" }

        let monthName = hijriMonthFormatter.monthSymbols[month - 1]
        let dayString = plainNumberFormatter.string(from: day as NSNumber) ?? String(day)
        let yearString = plainNumberFormatter.string(from: year as NSNumber) ?? String(year)

        let era = String(localized: "AH", comment: "Hijri era suffix shown after the year, e.g. '22 Sha'ban 1447 AH'")
        return "\(dayString) \(monthName) \(yearString) \(era)"
    }

    /// Localized Hijri month names (calendar + current locale fixed; timezone is
    /// irrelevant to `monthSymbols`). Cached to avoid re-allocating per render.
    private static let hijriMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .islamicUmmAlQura)
        return f
    }()

    /// Plain integer formatting (no grouping separators) for the day and year.
    private static let plainNumberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.usesGroupingSeparator = false
        return f
    }()

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

    static func countdownModeName(_ mode: MenuBarCountdownMode) -> String {
        switch mode {
        case .nextPrayer: return String(localized: "Next prayer")
        case .currentWaqt: return String(localized: "Time left in current prayer")
        }
    }

    static func highLatitudeRuleName(_ rule: HighLatitudeRule) -> String {
        switch rule {
        case .automatic: return String(localized: "Automatic (recommended)")
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
