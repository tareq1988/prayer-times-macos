import SwiftUI
import AppKit
import PrayerKit

/// The `.window`-style panel shown when the menu bar item is clicked (spec §7.1):
/// today's six times with the next highlighted and a live countdown, the date,
/// the active method/location summary, and the footer actions.
struct MenuBarPanel: View {
    let clock: PrayerClock

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            timesList
            Divider()
            summary
            footer
        }
        .padding(14)
        .frame(width: 280)
        .glassBackground()
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(PrayerFormatting.longDate(clock.now, in: clock.timeZone))
                .font(.headline)
            if let next = clock.nextEvent {
                Text("\(PrayerFormatting.name(next.prayer)) in \(PrayerFormatting.countdownLong(clock.secondsUntilNext))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private var timesList: some View {
        VStack(spacing: 0) {
            ForEach(clock.orderedToday, id: \.prayer) { entry in
                row(for: entry.prayer, time: entry.time)
            }
        }
    }

    private func row(for prayer: Prayer, time: Date) -> some View {
        let isNext = clock.nextEvent.map { $0.prayer == prayer && $0.time == time } ?? false
        return HStack {
            Text(PrayerFormatting.name(prayer))
                .fontWeight(isNext ? .semibold : .regular)
            Spacer()
            Text(PrayerFormatting.clock(time, in: clock.timeZone))
                .monospacedDigit()
                .fontWeight(isNext ? .semibold : .regular)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isNext ? Color.accentColor.opacity(0.18) : .clear)
        )
        .foregroundStyle(isNext ? Color.accentColor : .primary)
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(clock.methodName, systemImage: "moon.circle")
            Label(
                String(format: "%.4f, %.4f · %@",
                       clock.coordinates.latitude, clock.coordinates.longitude,
                       clock.timeZone.identifier),
                systemImage: "location"
            )
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .labelStyle(.titleAndIcon)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            SettingsLink {
                Text("Settings…")
            }
            // Wired to Sparkle in M8 (spec §7.8); placeholder keeps the layout.
            Button("Check for Updates…") {}
                .disabled(true)
                .help("Available in a later build")
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .buttonStyle(.borderless)
        .font(.callout)
    }
}
