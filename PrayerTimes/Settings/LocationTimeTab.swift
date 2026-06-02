import SwiftUI
import PrayerKit

/// Location & time settings (spec §7.6): location mode, manual coordinates, the
/// master timezone, and a read-only resolved summary.
///
/// M3 implements manual coordinates and the timezone fully; Automatic mode
/// (CoreLocation) and city-name geocoding land in M5 and fall back to the manual
/// coordinates meanwhile.
struct LocationTimeTab: View {
    @Bindable var settings: SettingsStore

    private static let timeZoneIDs = TimeZone.knownTimeZoneIdentifiers.sorted()

    var body: some View {
        Form {
            Section("Location") {
                Picker("Mode", selection: locationModeBinding) {
                    Text("Automatic").tag(LocationMode.automatic)
                    Text("Manual").tag(LocationMode.manual)
                }
                .pickerStyle(.segmented)

                if settings.settings.locationMode == .automatic {
                    HStack {
                        Button {
                            Task { await settings.detectLocation() }
                        } label: {
                            Label("Detect my location", systemImage: "location.fill")
                        }
                        .disabled(settings.isDetectingLocation)
                        if settings.isDetectingLocation {
                            ProgressView().controlSize(.small)
                        }
                    }
                    if let error = settings.locationError {
                        Text(error).font(.caption).foregroundStyle(.red)
                    } else if settings.detectedCoordinates == nil {
                        Text("Falls back to the manual coordinates below until detected.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                LabeledContent("Latitude") {
                    TextField("Latitude", value: latBinding, format: .number.precision(.fractionLength(0...6)))
                        .frame(width: 120).multilineTextAlignment(.trailing)
                }
                LabeledContent("Longitude") {
                    TextField("Longitude", value: lonBinding, format: .number.precision(.fractionLength(0...6)))
                        .frame(width: 120).multilineTextAlignment(.trailing)
                }
                LabeledContent("Elevation (m)") {
                    TextField("Elevation", value: elevationBinding, format: .number.precision(.fractionLength(0...1)))
                        .frame(width: 120).multilineTextAlignment(.trailing)
                }
            }

            Section("Master timezone") {
                Picker("Timezone", selection: timeZoneModeBinding) {
                    Text("Follow system").tag(0)
                    Text("Pick explicitly").tag(1)
                }
                .pickerStyle(.segmented)

                if timeZoneModeBinding.wrappedValue == 1 {
                    Picker("Zone", selection: explicitTimeZoneBinding) {
                        ForEach(Self.timeZoneIDs, id: \.self) { Text($0).tag($0) }
                    }
                }
            }

            Section("Resolved") {
                LabeledContent("Coordinates",
                    value: String(format: "%.4f, %.4f", settings.resolvedCoordinates.latitude, settings.resolvedCoordinates.longitude))
                LabeledContent("Timezone", value: settings.resolvedTimeZone.identifier)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: Bindings

    private var locationModeBinding: Binding<LocationMode> {
        Binding(
            get: { settings.settings.locationMode },
            set: { mode in
                settings.settings.locationMode = mode
                if mode == .automatic { Task { await settings.detectLocation() } }
            }
        )
    }

    // MARK: Coordinate bindings

    private var latBinding: Binding<Double> { coordinateBinding(\.latitude) }
    private var lonBinding: Binding<Double> { coordinateBinding(\.longitude) }
    private var elevationBinding: Binding<Double> { coordinateBinding(\.elevation) }

    private func coordinateBinding(_ keyPath: WritableKeyPath<Coordinates, Double>) -> Binding<Double> {
        Binding(
            get: { (settings.settings.manualCoordinates ?? SettingsStore.defaultCoordinates)[keyPath: keyPath] },
            set: { newValue in
                var c = settings.settings.manualCoordinates ?? SettingsStore.defaultCoordinates
                c[keyPath: keyPath] = newValue
                settings.settings.manualCoordinates = c
            }
        )
    }

    // MARK: Timezone bindings

    private var timeZoneModeBinding: Binding<Int> {
        Binding(
            get: {
                if case .explicit = settings.settings.timeZoneMode { return 1 }
                return 0
            },
            set: { tag in
                if tag == 0 {
                    settings.settings.timeZoneMode = .system
                } else {
                    settings.settings.timeZoneMode = .explicit(identifier: settings.resolvedTimeZone.identifier)
                }
            }
        )
    }

    private var explicitTimeZoneBinding: Binding<String> {
        Binding(
            get: {
                if case .explicit(let id) = settings.settings.timeZoneMode { return id }
                return TimeZone.current.identifier
            },
            set: { settings.settings.timeZoneMode = .explicit(identifier: $0) }
        )
    }
}
