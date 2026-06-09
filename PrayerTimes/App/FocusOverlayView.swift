import SwiftUI
import PrayerKit

/// The full-screen Focus Mode overlay shown over the desktop during prayer time.
/// Designed to feel like a calm, devotional pause — layered night-sky gradients,
/// a soft glowing centre, and a subtle tessellated eight-pointed-star pattern
/// (classic Islamic geometry) — rather than a harsh system lockout.
///
/// All text follows the app language (the prayer name, the calming line, and the
/// hadith are localized), so English users see English and Bengali users see
/// Bengali throughout.
struct FocusOverlayView: View {
    let prayer: Prayer
    /// The verse/hadith to show — picked once when the block begins (not per
    /// render, which ticks every second) so it stays put for the whole block.
    let scripture: FocusScripture
    /// When the block auto-releases; drives the countdown.
    let endsAt: Date
    let emergencyExitEnabled: Bool
    let intensity: FocusBlurIntensity

    // Warm gold used for accents and the geometric tracery.
    private let gold = Color(red: 0.86, green: 0.73, blue: 0.45)

    var body: some View {
        ZStack {
            backdrop
            IslamicStarPattern(color: gold)
                .opacity(0.07)
                .blendMode(.plusLighter)
            content
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }

    // MARK: Backdrop — layered gradients

    private var backdrop: some View {
        ZStack {
            // Deep multi-stop night gradient: indigo → teal → brand-green → black.
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.05, green: 0.08, blue: 0.16), location: 0.00),
                    .init(color: Color(red: 0.04, green: 0.12, blue: 0.15), location: 0.42),
                    .init(color: Color(red: 0.03, green: 0.10, blue: 0.08), location: 0.74),
                    .init(color: Color(red: 0.02, green: 0.05, blue: 0.05), location: 1.00),
                ],
                startPoint: .top, endPoint: .bottom
            )
            // Cool dawn glow from the top.
            RadialGradient(colors: [Color(red: 0.16, green: 0.38, blue: 0.46).opacity(0.40), .clear],
                           center: .top, startRadius: 0, endRadius: 760)
                .blendMode(.plusLighter)
            // Warm lamp glow rising from the bottom.
            RadialGradient(colors: [gold.opacity(0.20), .clear],
                           center: .bottom, startRadius: 0, endRadius: 620)
                .blendMode(.plusLighter)
            // A faint angular sheen for depth.
            AngularGradient(colors: [.clear, gold.opacity(0.06), .clear, Color(red: 0.16, green: 0.38, blue: 0.46).opacity(0.08), .clear],
                            center: .center)
                .blendMode(.plusLighter)
        }
        .opacity(backdropOpacity)
    }

    private var backdropOpacity: Double {
        switch intensity {
        case .low: return 0.82
        case .medium: return 0.93
        case .high: return 0.99
        case .opaque: return 1.0
        }
    }

    // MARK: Content

    private var content: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                // Soft halo behind the glyph.
                Circle()
                    .fill(RadialGradient(colors: [gold.opacity(0.22), .clear], center: .center, startRadius: 0, endRadius: 110))
                    .frame(width: 220, height: 220)
                Image("Mosque")
                    .renderingMode(.template)
                    .resizable().scaledToFit()
                    .frame(width: 76, height: 76)
                    .foregroundStyle(gold)
                    .shadow(color: gold.opacity(0.5), radius: 18)
            }

            Text(String(localized: "It's time for \(PrayerFormatting.name(prayer))",
                        comment: "Focus overlay headline, e.g. \"It's time for Maghrib\""))
                .font(.system(size: 72, weight: .bold, design: .serif))
                .foregroundStyle(.white)

            scriptureBlock
                .padding(.top, 22)
                .frame(maxWidth: 760)

            countdown
                .padding(.top, 16)

            Spacer()

            if emergencyExitEnabled {
                Text(String(localized: "Press ⌘ Esc to exit", comment: "Focus overlay: emergency exit hint"))
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.bottom, 44)
            }
        }
        .padding(48)
        .multilineTextAlignment(.center)
    }

    /// The soothing Qur'an verse or hadith block.
    private var scriptureBlock: some View {
        VStack(spacing: 16) {
            Text("\u{201C}\(scripture.text)\u{201D}")
                .font(.system(.title, design: .serif).italic())
                .foregroundStyle(.white.opacity(0.9))
                .lineSpacing(6)
            Text(scripture.source)
                .font(.title3)
                .foregroundStyle(gold.opacity(0.92))
        }
    }

    private var countdown: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let remaining = max(0, endsAt.timeIntervalSince(ctx.date))
            Text(Self.clock(remaining))
                .font(.system(size: 40, weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.68))
                .contentTransition(.numericText())
        }
    }

    private static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

}

/// A localized Qur'an verse or hadith about prayer, plus its reference. The pool
/// is resolved in the current language; `random()` picks one per block.
struct FocusScripture: Equatable {
    let text: String
    let source: String

    static func random() -> FocusScripture { pool.randomElement() ?? pool[0] }

    static var pool: [FocusScripture] {
        let muslim = String(localized: "— Prophet Muhammad ﷺ (Muslim)", comment: "Hadith attribution")
        let nasai = String(localized: "— Prophet Muhammad ﷺ (an-Nasāʾī)", comment: "Hadith attribution")
        let tirmidhi = String(localized: "— Prophet Muhammad ﷺ (Tirmidhī)", comment: "Hadith attribution")
        func verse(_ text: String.LocalizationValue, _ ref: String.LocalizationValue) -> FocusScripture {
            FocusScripture(text: String(localized: text, comment: "Qur'an verse shown in the Focus overlay"),
                           source: String(localized: ref, comment: "Qur'an verse reference"))
        }
        func hadith(_ text: String.LocalizationValue, _ source: String) -> FocusScripture {
            FocusScripture(text: String(localized: text, comment: "Hadith shown in the Focus overlay"), source: source)
        }
        return [
            // Qur'an
            verse("Indeed, prayer has been decreed upon the believers a decree of specified times.", "— Qur'an · An-Nisā 4:103"),
            verse("And seek help through patience and prayer.", "— Qur'an · Al-Baqarah 2:45"),
            verse("Establish prayer for My remembrance.", "— Qur'an · Ṭā Hā 20:14"),
            verse("Indeed, prayer restrains from immorality and wrongdoing.", "— Qur'an · Al-ʿAnkabūt 29:45"),
            verse("Successful indeed are the believers — those who are humble in their prayer.", "— Qur'an · Al-Muʾminūn 23:1–2"),
            verse("And establish prayer at the two ends of the day. Indeed, good deeds drive away evil deeds.", "— Qur'an · Hūd 11:114"),
            verse("Guard strictly the prayers, especially the middle prayer, and stand before Allah devoutly obedient.", "— Qur'an · Al-Baqarah 2:238"),
            // Hadith
            hadith("The coolness of my eyes is in prayer.", nasai),
            hadith("The closest a servant is to his Lord is while prostrating.", muslim),
            hadith("Prayer is light.", muslim),
            hadith("The first deed for which a servant will be held accountable on the Day of Judgment is the prayer.", tirmidhi),
        ]
    }
}

/// A tessellated eight-pointed-star (khatim / rub-el-hizb) lattice — two
/// overlapping squares per cell, the canonical Islamic star — drawn as fine
/// tracery to sit quietly behind the overlay content.
private struct IslamicStarPattern: View {
    let color: Color

    var body: some View {
        Canvas { ctx, size in
            let tile: CGFloat = 132
            let r = tile * 0.5
            let cols = Int(size.width / tile) + 2
            let rows = Int(size.height / tile) + 2
            for row in -1...rows {
                for col in -1...cols {
                    let centre = CGPoint(x: CGFloat(col) * tile, y: CGFloat(row) * tile)
                    ctx.stroke(Self.star(at: centre, radius: r),
                               with: .color(color), lineWidth: 1)
                }
            }
        }
    }

    /// Two concentric squares, one rotated 45°, forming an eight-pointed star.
    private static func star(at c: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        for rotation in [0.0, Double.pi / 4] {
            var square = Path()
            for i in 0..<4 {
                let a = rotation + Double(i) * .pi / 2 + .pi / 4
                let p = CGPoint(x: c.x + radius * CGFloat(cos(a)),
                                y: c.y + radius * CGFloat(sin(a)))
                if i == 0 { square.move(to: p) } else { square.addLine(to: p) }
            }
            square.closeSubpath()
            path.addPath(square)
        }
        return path
    }
}
