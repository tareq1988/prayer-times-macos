import SwiftUI
import AppKit
import PrayerKit

/// The `.window`-style panel shown when the menu bar item is clicked (spec §7.1):
/// a next-prayer hero, today's six times with the next highlighted and past ones
/// dimmed, the active method/location summary, and the footer actions.
struct MenuBarPanel: View {
    let clock: PrayerClock
    let openSettings: () -> Void
    let checkForUpdates: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            hero.padding(.horizontal, 8)
            timesList
            if clock.isAdhanPlaying {
                stopAdhanBar
            }
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

            if clock.showsHijriDate {
                Text(PrayerFormatting.hijriDate(clock.now, in: clock.timeZone, adjustment: clock.hijriDayAdjustment))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if let next = clock.nextEvent {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: PrayerFormatting.icon(next.prayer))
                        .font(.title3)
                        .foregroundStyle(Color.brand)
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
                        .foregroundStyle(Color.brand)
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
                // Ishraq (voluntary) sits right after Sunrise, which bounds it.
                if entry.prayer == .sunrise,
                   clock.showsIshraqTime,
                   let ishraq = clock.ishraqTime {
                    ishraqRow(ishraq)
                }
            }
        }
    }

    private func row(for prayer: Prayer, time: Date) -> some View {
        let isNext = clock.nextEvent.map { $0.prayer == prayer && $0.time == time } ?? false
        let isPast = !isNext && time < clock.now
        let iqamah = clock.iqamahTime(for: prayer, prayerTime: time)

        return HStack(spacing: 10) {
            Image(systemName: PrayerFormatting.icon(prayer))
                .font(.system(size: 13))
                .frame(width: 18)
                .foregroundStyle(isNext ? Color.brand : .secondary)

            Text(PrayerFormatting.name(prayer))
                .fontWeight(isNext ? .semibold : .regular)

            if let iqamah {
                Text("· Iqamah \(PrayerFormatting.clock(iqamah, in: clock.timeZone))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer()

            if isNext {
                Text(PrayerFormatting.shortCountdown(clock.secondsUntilNext))
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.brand.opacity(0.18)))
                    .foregroundStyle(Color.brand)
            }

            Text(PrayerFormatting.clock(time, in: clock.timeZone))
                .monospacedDigit()
                .fontWeight(isNext ? .semibold : .regular)
        }
        .foregroundStyle(isNext ? Color.brand : .primary)
        .opacity(isPast ? 0.45 : 1)
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isNext ? Color.brand.opacity(0.14) : .clear)
        )
    }

    /// Voluntary Ishraq (forenoon Duha) prayer, shown in-list right after Sunrise
    /// when enabled. Mirrors a regular row's layout but never highlights — it is
    /// not one of the six obligatory times.
    private func ishraqRow(_ time: Date) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "sun.and.horizon.fill")
                .font(.system(size: 13))
                .frame(width: 18)
                .foregroundStyle(.secondary)

            Text("Ishraq")

            Spacer()

            Text(PrayerFormatting.clock(time, in: clock.timeZone))
                .monospacedDigit()
        }
        .opacity(time < clock.now ? 0.45 : 1)   // dim once past, like the other rows
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
    }

    // MARK: Stop Adhan

    private var stopAdhanBar: some View {
        Button { clock.stopAdhan() } label: {
            Label("Stop Adhan", systemImage: "stop.circle.fill")
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 7)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.brand)
        .background(
            RoundedRectangle(cornerRadius: 8).fill(Color.brand.opacity(0.14))
        )
    }

    // MARK: Summary

    private var summary: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(clock.methodName, systemImage: "moon.circle")

            // Coordinates, timezone and (automatic mode) the age of the fix.
            // Opens the spot in Google Maps.
            Button { clock.openLocationInMaps() } label: {
                HStack(spacing: 4) {
                    Label(locationLine, systemImage: "location")
                    Image(systemName: "arrow.up.right.square")
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Open in Google Maps")

            if clock.usesAutomaticLocation {
                Button { clock.refreshLocation() } label: {
                    Label(recheckLine, systemImage: "clock.arrow.circlepath")
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(clock.isDetectingLocation)
                .help("Recheck the location now")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .labelStyle(.titleAndIcon)
    }

    /// "51.5074, -0.1278 (Europe/London) · 12 min. ago". The age re-renders
    /// with `clock.now`, so it stays current while the panel is open.
    private var locationLine: String {
        var line = String(format: "%.4f, %.4f (%@)",
                          clock.coordinates.latitude, clock.coordinates.longitude,
                          clock.timeZone.identifier)
        if clock.usesAutomaticLocation, let at = clock.locationDetectedAt {
            line += " · " + PrayerFormatting.relative(at, to: clock.now)
        }
        return line
    }

    /// When the automatic location is next re-detected, or why there is no fix.
    private var recheckLine: String {
        if clock.isDetectingLocation { return String(localized: "Locating…") }
        let wait = clock.locationNextCheckAt.timeIntervalSince(clock.now)
        let countdown = PrayerFormatting.shortCountdown(wait)
        if clock.locationError != nil {
            return wait > 0
                ? String(localized: "Location unavailable. Recheck in \(countdown)")
                : String(localized: "Location unavailable. Click to retry.")
        }
        if clock.locationDetectedAt == nil { return String(localized: "Location not detected yet") }
        return wait > 0
            ? String(localized: "Location recheck in \(countdown)")
            : String(localized: "Location recheck due")
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 1) {
            Button { openSettings() } label: {
                footerLabel("Settings…", systemImage: "gearshape")
            }
            .buttonStyle(.plain)
            .menuRowHighlight()

            Button { checkForUpdates() } label: {
                footerLabel("Check for Updates…", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.plain)
            .menuRowHighlight()

            Button { NSApplication.shared.terminate(nil) } label: {
                footerLabel("Quit", systemImage: "power")
            }
            .buttonStyle(.plain)
            .menuRowHighlight()
        }
        .font(.callout)
    }

    /// Full-width, left-aligned label so each footer item reads as its own menu row.
    private func footerLabel(_ title: LocalizedStringKey, systemImage: String) -> some View {
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
