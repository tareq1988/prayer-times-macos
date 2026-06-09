import SwiftUI
import PrayerKit

/// Shared helpers for the Manual (fixed) jamaat schedule, used by both the
/// Calculation settings tab and the onboarding wizard so the azan-chip math and
/// the minutes↔Date plumbing live in exactly one place.
enum JamaatSchedule {

    /// Effective jamaat time (minutes since midnight) for a prayer: the user's
    /// entry, falling back to the seeded default.
    static func minutes(for prayer: Prayer, in settings: AppSettings) -> Int {
        settings.jamaatTimes[prayer] ?? (AppSettings.defaultJamaatTimes[prayer] ?? 0)
    }

    /// "Adhan HH:mm" = jamaat − offset, wrapping past midnight.
    static func adhanChip(jamaatMinutes: Int, azanBefore: Int) -> String {
        let m = ((jamaatMinutes - azanBefore) % 1440 + 1440) % 1440
        let time = String(format: "%02d:%02d", m / 60, m % 60)
        return String(localized: "Adhan \(time)",
                      comment: "Computed call-to-prayer time chip in the jamaat schedule, e.g. 'Adhan 04:45'")
    }

    /// Bridge minutes-since-midnight ↔ a `Date` for an hour/minute `DatePicker`.
    /// A fixed reference day is fine — only the time components are read back.
    static func timeBinding(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding(
            get: { dateFromMinutes(minutes.wrappedValue) },
            set: { minutes.wrappedValue = minutesFromDate($0) }
        )
    }

    private static func dateFromMinutes(_ minutes: Int) -> Date {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = .current
        let base = cal.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))
        return base.addingTimeInterval(TimeInterval(minutes) * 60)
    }

    private static func minutesFromDate(_ date: Date) -> Int {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = .current
        let c = cal.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
}

/// One jamaat-schedule row: the prayer's icon + name, the computed Adhan chip
/// (`jamaat − offset`), and an editable hour/minute field bound to
/// minutes-since-midnight. Shared by the Calculation tab and the setup wizard.
struct JamaatRowView: View {
    let prayer: Prayer
    @Binding var minutes: Int
    let azanBefore: Int

    var body: some View {
        HStack(spacing: 10) {
            Label {
                Text(PrayerFormatting.name(prayer))
            } icon: {
                Image(systemName: PrayerFormatting.icon(prayer)).foregroundStyle(.secondary)
            }
            Spacer()
            Text(JamaatSchedule.adhanChip(jamaatMinutes: minutes, azanBefore: azanBefore))
                .font(.caption.weight(.medium)).monospacedDigit().foregroundStyle(.secondary)
                .padding(.horizontal, 8).padding(.vertical, 2)
                .background(Capsule().fill(.quaternary))
            DatePicker("", selection: JamaatSchedule.timeBinding($minutes), displayedComponents: .hourAndMinute)
                .labelsHidden()
        }
    }
}
