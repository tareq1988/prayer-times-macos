import Foundation

/// Kementerian Agama Republik Indonesia (Kemenag / SIHAT) — the official
/// Indonesian method, as published by Kemenag's prayer-time tables.
///
/// Kemenag uses Fajr (Subuh) **20°** and Isha (Isya) **18°**, Shafiʿi Asr, plus
/// *ihtiyati* (safety) minutes added to each prayer. Calibrated against Kemenag's
/// published tables for KOTA JAKARTA across both solstices and equinoxes, the
/// integer offsets that reproduce them to ±1 minute (given the engine's
/// nearest-minute rounding) are Subuh +2, Dzuhur +3, Ashar +2, Maghrib +3,
/// Isya +2. Kemenag also defines Imsak = Subuh − 10, which this app does not
/// surface.
///
/// The angles and ihtiyati are national, but the gate only verifies Jakarta
/// (`KemenagGoldenTableTests`); other regions are expected to land within a
/// minute or two but aren't independently checked.
public struct KemenagAdapter: CalculationMethodAdapter {
    public let id = "kemenag"
    public let displayName = "Kemenag (Indonesia)"
    public let summary = "Fajr 20°, Isha 18°, Kemenag ihtiyati."

    public init() {}

    public func resolve(for coordinates: Coordinates) -> CalculationParameters {
        CalculationParameters(
            fajrAngle: 20.0,
            ishaAngle: 18.0,
            asrShadowFactor: 1.0,
            dhuhrOffsetMinutes: 3,
            asrOffsetMinutes: 2,
            // No dedicated Subuh/Maghrib/Isya offset field, so the remaining
            // ihtiyati rides on manualOffsets. Safe: the per-prayer offset editor
            // is only exposed for the Manual method, never for built-ins.
            manualOffsets: [.fajr: 2, .maghrib: 3, .isha: 2],
            highLatitudeRule: .angleBased
        )
    }
}
