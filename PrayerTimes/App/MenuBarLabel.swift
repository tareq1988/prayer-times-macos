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
    /// is no upcoming prayer, leaving just the icon).
    private func textPart(style: MenuBarStyle, next: (prayer: Prayer, time: Date)?) -> String? {
        guard let next else { return nil }

        let value: String?
        switch style.value {
        case .none: value = nil
        case .countdown: value = PrayerFormatting.countdownLabel(clock.secondsUntilNext)
        case .clock: value = PrayerFormatting.clock(next.time, in: clock.timeZone)
        }

        let name = style.showsName ? PrayerFormatting.name(next.prayer) : nil
        return [name, value].compactMap { $0 }.joined(separator: " ").nilIfEmpty
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
