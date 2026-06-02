import SwiftUI
import PrayerKit

/// The compact menu bar label. Honors the configurable style (spec §7.1):
/// next prayer + countdown (default), next prayer + clock time, or icon only.
struct MenuBarLabel: View {
    let clock: PrayerClock
    let settings: SettingsStore

    var body: some View {
        switch settings.settings.menuBarStyle {
        case .iconOnly:
            Image(systemName: "moon.stars.fill")
        case .nextPrayerClock:
            if let next = clock.nextEvent {
                Text("\(PrayerFormatting.name(next.prayer)) \(PrayerFormatting.clock(next.time, in: clock.timeZone))")
            } else {
                Image(systemName: "moon.stars.fill")
            }
        case .nextPrayerCountdown:
            if let next = clock.nextEvent {
                Text("\(PrayerFormatting.name(next.prayer)) \(PrayerFormatting.countdownLabel(clock.secondsUntilNext))")
            } else {
                Image(systemName: "moon.stars.fill")
            }
        }
    }
}
