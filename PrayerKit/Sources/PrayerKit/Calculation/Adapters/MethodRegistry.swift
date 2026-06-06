import Foundation

/// Central catalog of calculation methods. Resolves persisted ids back to
/// adapters, applies the Hanafi Asr modifier, and maps ISO country codes to a
/// default method for the optional auto-detect feature (§7.7).
public enum MethodRegistry {

    /// All selectable built-in methods, in display order. `ManualAdapter` is
    /// excluded here because it requires user-supplied parameters; construct it
    /// directly when the "Manual" method is chosen.
    public static var builtIn: [any CalculationMethodAdapter] {
        [
            DiyanetAdapter(),
            MWLAdapter(),
            ISNAAdapter(),
            UmmAlQuraAdapter(),
            EgyptianAdapter(),
            KarachiAdapter(),
            JAKIMAdapter(),
            KemenagAdapter(),
            MoonsightingCommitteeAdapter()
        ]
    }

    /// Look up a base method by its stable id (without the `.hanafi` suffix).
    public static func adapter(forID id: String) -> (any CalculationMethodAdapter)? {
        builtIn.first { $0.id == id }
    }

    /// Resolve a persisted selection into a ready-to-use adapter.
    ///
    /// - Parameters:
    ///   - methodID: A built-in id, or `"manual"`.
    ///   - hanafiAsr: Wraps the result in `HanafiAsrModifier` when `true`.
    ///   - manualParameters: Required when `methodID == "manual"`.
    /// - Returns: The adapter, or `nil` if the id is unknown / manual params missing.
    public static func resolve(
        methodID: String,
        hanafiAsr: Bool,
        manualParameters: CalculationParameters? = nil
    ) -> (any CalculationMethodAdapter)? {
        let base: (any CalculationMethodAdapter)?
        if methodID == ManualAdapter(parameters: .init(fajrAngle: 0)).id {
            base = manualParameters.map { ManualAdapter(parameters: $0) }
        } else {
            base = adapter(forID: methodID)
        }
        guard let base else { return nil }
        return hanafiAsr ? HanafiAsrModifier(base: base) : base
    }

    // MARK: - Country → method (auto-detect)

    /// ISO 3166-1 alpha-2 country code → default method id. Falls back to MWL.
    /// Extend as coverage grows (§7.7).
    public static let countryMethod: [String: String] = [
        "TR": "diyanet",
        "US": "isna", "CA": "isna",
        "SA": "ummalqura",
        "EG": "egyptian",
        "PK": "karachi", "IN": "karachi", "BD": "karachi", "AF": "karachi",
        // Malaysia → JAKIM, calibrated to e-Solat. Neighbours (Singapore/MUIS,
        // Brunei) run their own authorities and aren't mapped here.
        "MY": "jakim",
        // Indonesia → Kemenag (Kementerian Agama RI).
        "ID": "kemenag",
        // GB + Northern Europe lean MWL with angle-based high-lat (MWL's default).
        "GB": "mwl", "IE": "mwl", "NO": "mwl", "SE": "mwl", "FI": "mwl",
        "DK": "mwl", "IS": "mwl"
    ]

    /// Default method id for a country code; `"mwl"` when unmapped or `nil`.
    public static func methodID(forCountryCode code: String?) -> String {
        guard let code = code?.uppercased() else { return "mwl" }
        return countryMethod[code] ?? "mwl"
    }
}
