import XCTest
@testable import PrayerKit

/// Verifies each adapter emits the parameters the spec (§6.3, §6.6) prescribes,
/// and that the registry resolves ids, the Hanafi modifier, and country mappings.
final class AdapterTests: XCTestCase {

    private let anywhere = Coordinates(latitude: 41, longitude: 29)

    func testDiyanetParameters() {
        let p = DiyanetAdapter().resolve(for: anywhere)
        XCTAssertEqual(p.fajrAngle, 18.0)
        XCTAssertEqual(p.ishaAngle, 17.0)
        XCTAssertEqual(p.sunriseAngle, -1.9)
        XCTAssertEqual(p.asrShadowFactor, 1.0)
        XCTAssertEqual(p.dhuhrOffsetMinutes, 5)
        XCTAssertEqual(p.asrOffsetMinutes, 4)
    }

    func testAngleBasedMethods() {
        XCTAssertEqual(MWLAdapter().resolve(for: anywhere).fajrAngle, 18.0)
        XCTAssertEqual(MWLAdapter().resolve(for: anywhere).ishaAngle, 17.0)
        XCTAssertEqual(ISNAAdapter().resolve(for: anywhere).fajrAngle, 15.0)
        XCTAssertEqual(EgyptianAdapter().resolve(for: anywhere).fajrAngle, 19.5)
        XCTAssertEqual(EgyptianAdapter().resolve(for: anywhere).ishaAngle, 17.5)
        XCTAssertEqual(KarachiAdapter().resolve(for: anywhere).ishaAngle, 18.0)
    }

    func testJAKIMCalibratedParameters() {
        // Calibrated to JAKIM e-Solat output, not the 20°/18° preset (see
        // JAKIMGoldenTableTests). Includes JAKIM's ihtiyati safety minutes.
        let p = JAKIMAdapter().resolve(for: anywhere)
        XCTAssertEqual(p.fajrAngle, 17.5)
        XCTAssertEqual(p.ishaAngle, 18.0)
        XCTAssertEqual(p.asrShadowFactor, 1.0)
        XCTAssertEqual(p.dhuhrOffsetMinutes, 3)
        XCTAssertEqual(p.asrOffsetMinutes, 2)
        XCTAssertEqual(p.manualOffsets[.maghrib], 2)
        XCTAssertEqual(p.manualOffsets[.isha], 2)
    }

    func testKemenagCalibratedParameters() {
        // Kemenag (Indonesia): Fajr 20°, Isha 18° + ihtiyati (see
        // KemenagGoldenTableTests).
        let p = KemenagAdapter().resolve(for: anywhere)
        XCTAssertEqual(p.fajrAngle, 20.0)
        XCTAssertEqual(p.ishaAngle, 18.0)
        XCTAssertEqual(p.asrShadowFactor, 1.0)
        XCTAssertEqual(p.dhuhrOffsetMinutes, 3)
        XCTAssertEqual(p.asrOffsetMinutes, 2)
        XCTAssertEqual(p.manualOffsets[.fajr], 2)
        XCTAssertEqual(p.manualOffsets[.maghrib], 3)
        XCTAssertEqual(p.manualOffsets[.isha], 2)
    }

    func testUmmAlQuraUsesFixedIsha() {
        let p = UmmAlQuraAdapter().resolve(for: anywhere)
        XCTAssertEqual(p.fajrAngle, 18.5)
        XCTAssertNil(p.ishaAngle)
        XCTAssertEqual(p.ishaFixedMinutes, 90)
    }

    func testHanafiModifierOnlyChangesAsr() {
        let base = MWLAdapter()
        let modified = HanafiAsrModifier(base: base)
        let bp = base.resolve(for: anywhere)
        let mp = modified.resolve(for: anywhere)

        XCTAssertEqual(mp.asrShadowFactor, 2.0)
        XCTAssertEqual(modified.id, "mwl.hanafi")
        // Everything except the shadow factor is identical.
        XCTAssertEqual(mp.fajrAngle, bp.fajrAngle)
        XCTAssertEqual(mp.ishaAngle, bp.ishaAngle)
        XCTAssertEqual(mp.sunriseAngle, bp.sunriseAngle)
    }

    func testManualAdapterPassesParametersThrough() {
        let custom = CalculationParameters(
            fajrAngle: 12, ishaAngle: 12, asrShadowFactor: 2, dhuhrOffsetMinutes: 3
        )
        let adapter = ManualAdapter(parameters: custom)
        XCTAssertEqual(adapter.resolve(for: anywhere), custom)
    }

    // MARK: - Registry

    func testRegistryResolvesBuiltInByID() {
        let adapter = MethodRegistry.resolve(methodID: "diyanet", hanafiAsr: false)
        XCTAssertEqual(adapter?.id, "diyanet")
    }

    func testRegistryAppliesHanafi() {
        let adapter = MethodRegistry.resolve(methodID: "isna", hanafiAsr: true)
        XCTAssertEqual(adapter?.id, "isna.hanafi")
        XCTAssertEqual(adapter?.resolve(for: anywhere).asrShadowFactor, 2.0)
    }

    func testRegistryResolvesManualWithParameters() {
        let custom = CalculationParameters(fajrAngle: 16, ishaAngle: 16)
        let adapter = MethodRegistry.resolve(methodID: "manual", hanafiAsr: false, manualParameters: custom)
        XCTAssertEqual(adapter?.id, "manual")
        XCTAssertEqual(adapter?.resolve(for: anywhere).fajrAngle, 16)
    }

    func testRegistryReturnsNilForUnknownID() {
        XCTAssertNil(MethodRegistry.resolve(methodID: "does-not-exist", hanafiAsr: false))
    }

    func testCountryMethodMapping() {
        XCTAssertEqual(MethodRegistry.methodID(forCountryCode: "TR"), "diyanet")
        XCTAssertEqual(MethodRegistry.methodID(forCountryCode: "us"), "isna")  // case-insensitive
        XCTAssertEqual(MethodRegistry.methodID(forCountryCode: "SA"), "ummalqura")
        XCTAssertEqual(MethodRegistry.methodID(forCountryCode: "PK"), "karachi")
        XCTAssertEqual(MethodRegistry.methodID(forCountryCode: "MY"), "jakim")
        XCTAssertEqual(MethodRegistry.methodID(forCountryCode: "ID"), "kemenag")
        XCTAssertEqual(MethodRegistry.methodID(forCountryCode: "ZZ"), "mwl")    // unknown → MWL
        XCTAssertEqual(MethodRegistry.methodID(forCountryCode: nil), "mwl")
    }

    func testBuiltInExcludesManual() {
        XCTAssertFalse(MethodRegistry.builtIn.contains { $0.id == "manual" })
        XCTAssertEqual(MethodRegistry.builtIn.count, 9)
    }
}
