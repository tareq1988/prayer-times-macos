import SwiftUI
import PrayerKit

/// The compact menu bar label: next prayer name + countdown (spec §7.1, default
/// style). The configurable label styles (clock / icon-only) arrive with
/// settings in M3.
struct MenuBarLabel: View {
    let clock: PrayerClock

    var body: some View {
        if let next = clock.nextEvent {
            Text("\(PrayerFormatting.name(next.prayer)) \(PrayerFormatting.countdownLabel(clock.secondsUntilNext))")
        } else {
            Image(systemName: "moon.stars.fill")
        }
    }
}
