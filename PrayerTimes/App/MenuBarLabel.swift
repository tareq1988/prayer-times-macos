import SwiftUI
import PrayerKit

/// The compact menu bar label. Renders any combination of the contextual prayer
/// icon, the prayer name, and a trailing value (countdown or clock time) per the
/// configured `MenuBarStyle` (spec §7.1).
struct MenuBarLabel: View {
    let clock: PrayerClock
    let settings: SettingsStore

    var body: some View {
        let style = settings.settings.menuBarStyle
        let next = clock.nextEvent

        HStack(spacing: 4) {
            if style.showsIcon {
                // Sizing/centering is baked into the asset: the Mosque.imageset
                // viewBox carries ~15% vertical padding so the glyph fills ~70% of
                // its square box, centered. The menu bar scales template images to
                // its own icon height (ignoring SwiftUI `.frame`), so the padding —
                // not a view modifier — is what keeps the glyph from looming above
                // the text caps and aligns it with the neighbouring menu-bar icons.
                Image("Mosque")
                    .renderingMode(.template)
            }
            if let text = textPart(style: style, next: next) {
                Text(text)
            }
        }
    }

    // MARK: Composition

    /// The text portion: name and/or value, or nil for icon-only (or when there
    /// is no upcoming prayer, leaving just the icon). A countdown reads as
    /// "Asr in 4h 21m" (or "in 21m" with no name) — unit-bearing so "in" isn't
    /// ambiguous (a bare "1:24" could be 1h24m or 1m24s), matching the panel chip;
    /// the "in" is a localized format so RTL ordering stays correct. A clock value
    /// stays bare ("Asr 16:42").
    private func textPart(style: MenuBarStyle, next: (prayer: Prayer, time: Date)?) -> String? {
        guard let next else { return nil }

        switch style.value {
        case .none:
            return style.showsName ? PrayerFormatting.name(next.prayer).nilIfEmpty : nil

        case .countdown:
            // "Time left in current waqt" mode counts down to the active prayer's
            // cut-off under the window rules (e.g. Asr 20 min before sunset), the
            // same instant the time-running-out reminder uses. In the sunrise→
            // Dhuhr gap, or once the cut-off has passed, it falls back to the
            // next-prayer countdown so the label stays meaningful.
            if settings.settings.menuBarCountdownMode == .currentWaqt,
               let window = clock.currentWindow {
                let cd = PrayerFormatting.shortCountdown(max(0, window.deadline.timeIntervalSince(clock.now)))
                if style.showsName {
                    let name = PrayerFormatting.name(window.prayer)
                    return String(localized: "\(name) \(cd) left", comment: "Menu bar: current prayer + time left in its window, e.g. 'Asr 40m left'")
                }
                return String(localized: "\(cd) left", comment: "Menu bar: time left in the current prayer window, e.g. '40m left'")
            }

            let cd = PrayerFormatting.shortCountdown(clock.secondsUntilNext)
            if style.showsName {
                let name = PrayerFormatting.name(next.prayer)
                return String(localized: "\(name) in \(cd)", comment: "Menu bar: prayer name + countdown, e.g. 'Asr in 1:24'")
            }
            return String(localized: "in \(cd)", comment: "Menu bar: countdown to next prayer, e.g. 'in 1:24'")

        case .clock:
            let clk = PrayerFormatting.clock(next.time, in: clock.timeZone)
            if style.showsName {
                let name = PrayerFormatting.name(next.prayer)
                return "\(name) \(clk)"
            }
            return clk
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
