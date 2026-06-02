import SwiftUI
import PrayerKit

/// Calculation settings (spec §7.6): method, madhab (Asr), high-latitude rule,
/// the auto-detect toggle, and the manual-method editor.
struct CalculationTab: View {
    @Bindable var settings: SettingsStore

    private static let manualID = "manual"

    var body: some View {
        Form {
            Section("Method") {
                Picker("Calculation method", selection: methodBinding) {
                    ForEach(MethodRegistry.builtIn, id: \.id) { adapter in
                        Text(adapter.displayName).tag(adapter.id)
                    }
                    Divider()
                    Text("Manual").tag(Self.manualID)
                }

                Picker("Asr (madhab)", selection: $settings.settings.hanafiAsr) {
                    Text("Standard").tag(false)
                    Text("Hanafi").tag(true)
                }

                Picker("High-latitude rule", selection: $settings.settings.highLatitudeRule) {
                    ForEach(HighLatitudeRule.allCases, id: \.self) { rule in
                        Text(PrayerFormatting.highLatitudeRuleName(rule)).tag(rule)
                    }
                }
            }

            Section {
                Toggle("Auto-detect method from location", isOn: autoDetectBinding)
                if let label = settings.autoMethodLabel {
                    Text(label).font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Resolves your country to a method; you can still override it below.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            if settings.settings.methodID == Self.manualID {
                ManualMethodEditor(parameters: manualParametersBinding)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: Bindings

    /// User-driven method selection. Seeds manual parameters when switching to
    /// "Manual", and overrides auto-detect (spec §7.7: a manual choice disables
    /// auto until re-enabled).
    private var methodBinding: Binding<String> {
        Binding(
            get: { settings.settings.methodID },
            set: { newID in
                settings.settings.autoDetectMethod = false
                settings.settings.methodID = newID
                if newID == Self.manualID, settings.settings.manualParameters == nil {
                    settings.settings.manualParameters = Self.defaultManualParameters
                }
            }
        )
    }

    /// Enabling auto-detect kicks off a one-shot detection.
    private var autoDetectBinding: Binding<Bool> {
        Binding(
            get: { settings.settings.autoDetectMethod },
            set: { enabled in
                settings.settings.autoDetectMethod = enabled
                if enabled { Task { await settings.detectLocation() } }
            }
        )
    }

    private var manualParametersBinding: Binding<CalculationParameters> {
        Binding(
            get: { settings.settings.manualParameters ?? Self.defaultManualParameters },
            set: { settings.settings.manualParameters = $0 }
        )
    }

    private static var defaultManualParameters: CalculationParameters {
        CalculationParameters(fajrAngle: 18, ishaAngle: 17)
    }
}

/// Editor for fully user-supplied parameters (spec §7.6): Fajr angle, Isha
/// angle or fixed minutes, Asr shadow factor, sunrise horizon angle, and the
/// five per-prayer offsets.
struct ManualMethodEditor: View {
    @Binding var parameters: CalculationParameters

    var body: some View {
        Section("Manual parameters") {
            angleRow("Fajr angle", value: $parameters.fajrAngle)

            Toggle("Isha as fixed minutes after Maghrib", isOn: ishaFixedToggle)
            if parameters.ishaFixedMinutes != nil {
                stepperRow("Isha (min after Maghrib)", value: ishaFixedBinding, range: 0...150)
            } else {
                angleRow("Isha angle", value: ishaAngleBinding)
            }

            angleRow("Sunrise/Maghrib horizon", value: $parameters.sunriseAngle, range: -5...0)

            Picker("Asr shadow factor", selection: $parameters.asrShadowFactor) {
                Text("Standard (1×)").tag(1.0)
                Text("Hanafi (2×)").tag(2.0)
            }
        }

        Section("Per-prayer offsets (minutes)") {
            ForEach(Prayer.obligatory, id: \.self) { prayer in
                stepperRow("\(PrayerFormatting.name(prayer))", value: offsetBinding(for: prayer), range: -60...60)
            }
        }
    }

    // MARK: Rows

    private func angleRow(_ title: LocalizedStringKey, value: Binding<Double>, range: ClosedRange<Double> = 0...30) -> some View {
        LabeledContent(title) {
            TextField(title, value: value, format: .number.precision(.fractionLength(0...2)))
                .labelsHidden().frame(width: 80).multilineTextAlignment(.trailing)
        }
    }

    private func stepperRow(_ title: LocalizedStringKey, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        Stepper(value: value, in: range) {
            HStack {
                Text(title)
                Spacer(minLength: 12)
                Text("\(value.wrappedValue)").monospacedDigit().foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Bindings

    private var ishaAngleBinding: Binding<Double> {
        Binding(get: { parameters.ishaAngle ?? 17 }, set: { parameters.ishaAngle = $0 })
    }

    private var ishaFixedBinding: Binding<Int> {
        Binding(get: { parameters.ishaFixedMinutes ?? 90 }, set: { parameters.ishaFixedMinutes = $0 })
    }

    private var ishaFixedToggle: Binding<Bool> {
        Binding(
            get: { parameters.ishaFixedMinutes != nil },
            set: { useFixed in
                if useFixed {
                    parameters.ishaFixedMinutes = parameters.ishaFixedMinutes ?? 90
                    parameters.ishaAngle = nil
                } else {
                    parameters.ishaFixedMinutes = nil
                    parameters.ishaAngle = parameters.ishaAngle ?? 17
                }
            }
        )
    }

    private func offsetBinding(for prayer: Prayer) -> Binding<Int> {
        Binding(
            get: { parameters.manualOffsets[prayer] ?? 0 },
            set: { parameters.manualOffsets[prayer] = $0 }
        )
    }
}
