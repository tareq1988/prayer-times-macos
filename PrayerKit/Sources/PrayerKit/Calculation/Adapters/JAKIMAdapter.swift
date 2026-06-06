import Foundation

/// Jabatan Kemajuan Islam Malaysia (Department of Islamic Development Malaysia) —
/// the official Malaysian method, as published by the JAKIM e-Solat service.
///
/// The parameters here are calibrated to reproduce e-Solat's own output, not the
/// "Fajr 20°/Isha 18°" preset other apps label "JAKIM" — that preset runs Fajr
/// ~11 minutes early against the real tables. Empirically (KL/WLY01, validated
/// across the solstices and equinoxes) e-Solat's Subuh behaves as a **17.5°**
/// depression, Isyak as **18°**, plus JAKIM's *ihtiyati* (safety) minutes added
/// to the post-noon prayers: Zohor +3, Asar +2, Maghrib +2, Isyak +2. With these
/// it matches e-Solat to ±1 minute every day of the year.
public struct JAKIMAdapter: CalculationMethodAdapter {
    public let id = "jakim"
    public let displayName = "JAKIM (Malaysia)"
    public let summary = "Fajr 17.5°, Isha 18°, JAKIM ihtiyati. Matches e-Solat."

    public init() {}

    public func resolve(for coordinates: Coordinates) -> CalculationParameters {
        CalculationParameters(
            fajrAngle: 17.5,
            ishaAngle: 18.0,
            asrShadowFactor: 1.0,
            dhuhrOffsetMinutes: 3,
            asrOffsetMinutes: 2,
            // No dedicated Maghrib/Isha offset field, so JAKIM's ihtiyati for the
            // evening prayers rides on manualOffsets. Safe: the per-prayer offset
            // editor is only exposed for the Manual method, never for built-ins.
            manualOffsets: [.maghrib: 2, .isha: 2],
            highLatitudeRule: .angleBased
        )
    }
}
