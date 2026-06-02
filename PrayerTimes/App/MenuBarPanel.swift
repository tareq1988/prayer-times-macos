import SwiftUI
import AppKit
import PrayerKit

/// The `.window`-style panel shown when the menu bar item is clicked (spec §7.1):
/// a next-prayer hero, today's six times with the next highlighted and past ones
/// dimmed, the active method/location summary, and the footer actions.
struct MenuBarPanel: View {
    let clock: PrayerClock
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            hero.padding(.horizontal, 8)
            timesList
            Divider().opacity(0.5)
            summary.padding(.horizontal, 8)
            Divider().opacity(0.5)
            footer
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .frame(width: 300)
        .glassBackground()
    }

    // MARK: Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(PrayerFormatting.longDate(clock.now, in: clock.timeZone).uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)

            if let next = clock.nextEvent {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: PrayerFormatting.icon(next.prayer))
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                        .imageScale(.large)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(PrayerFormatting.name(next.prayer))
                            .font(.title2.weight(.bold))
                        Text("in \(PrayerFormatting.countdownLong(clock.secondsUntilNext))")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Spacer()
                    Text(PrayerFormatting.clock(next.time, in: clock.timeZone))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .monospacedDigit()
                }
            }
        }
    }

    // MARK: Times list

    private var timesList: some View {
        VStack(spacing: 1) {
            ForEach(clock.orderedToday, id: \.prayer) { entry in
                row(for: entry.prayer, time: entry.time)
            }
        }
    }

    private func row(for prayer: Prayer, time: Date) -> some View {
        let isNext = clock.nextEvent.map { $0.prayer == prayer && $0.time == time } ?? false
        let isPast = !isNext && time < clock.now

        return HStack(spacing: 10) {
            Image(systemName: PrayerFormatting.icon(prayer))
                .font(.system(size: 13))
                .frame(width: 18)
                .foregroundStyle(isNext ? Color.accentColor : .secondary)

            Text(PrayerFormatting.name(prayer))
                .fontWeight(isNext ? .semibold : .regular)

            Spacer()

            if isNext {
                Text(PrayerFormatting.shortCountdown(clock.secondsUntilNext))
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.accentColor.opacity(0.18)))
                    .foregroundStyle(Color.accentColor)
            }

            Text(PrayerFormatting.clock(time, in: clock.timeZone))
                .monospacedDigit()
                .fontWeight(isNext ? .semibold : .regular)
        }
        .foregroundStyle(isNext ? Color.accentColor : .primary)
        .opacity(isPast ? 0.45 : 1)
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isNext ? Color.accentColor.opacity(0.14) : .clear)
        )
    }

    // MARK: Summary

    private var summary: some View {
        VStack(alignment: .leading, spacing: 3) {
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

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 1) {
            Button { openSettings() } label: {
                footerLabel("Settings…", systemImage: "gearshape")
            }
            .buttonStyle(.plain)
            .menuRowHighlight()

            // Wired to Sparkle in M8 (spec §7.8); placeholder keeps the layout.
            Button { } label: {
                footerLabel("Check for Updates…", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.plain)
            .disabled(true)
            .foregroundStyle(.secondary)

            Button { NSApplication.shared.terminate(nil) } label: {
                footerLabel("Quit", systemImage: "power")
            }
            .buttonStyle(.plain)
            .menuRowHighlight()
        }
        .font(.callout)
    }

    /// Full-width, left-aligned label so each footer item reads as its own menu row.
    private func footerLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
    }
}

/// Native-menu-style hover highlight for the full-width footer rows.
private struct MenuRowHighlight: ViewModifier {
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(hovering ? Color.primary.opacity(0.1) : .clear)
            )
            .onHover { hovering = $0 }
    }
}

private extension View {
    func menuRowHighlight() -> some View { modifier(MenuRowHighlight()) }
}
