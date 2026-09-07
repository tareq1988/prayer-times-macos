import Foundation
import CoreLocation
import Observation
import OSLog

enum LocationError: LocalizedError {
    case denied
    case noResult
    case busy
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .denied: return "Location access was denied. Enable it in System Settings → Privacy & Security → Location Services."
        case .noResult: return "No location was returned."
        case .busy: return "A location request is already in progress."
        case .failed(let message): return message
        }
    }
}

/// One-shot location + reverse geocoding for the optional auto-detect feature
/// (spec §7.7). Never tracks continuously: a single `requestLocation` per call.
/// CoreLocation requires a usage string (Info.plist) and a runtime prompt; the
/// app is unsandboxed so no location entitlement is needed (spec §12).
@MainActor
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private let log = Logger(subsystem: "co.tareq.prayertimes", category: "location")

    private(set) var authorization: CLAuthorizationStatus
    @ObservationIgnored private var continuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// Fetch the current location once, prompting for authorization if needed.
    /// Only one request may be in flight at a time: a concurrent call fails fast
    /// with `.busy` rather than overwriting (and leaking) the pending continuation.
    func fetchCurrent() async throws -> CLLocation {
        guard continuation == nil else { throw LocationError.busy }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            switch manager.authorizationStatus {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()   // resumes via delegate
            case .authorized, .authorizedAlways:
                manager.requestLocation()
            case .denied, .restricted:
                resume(.failure(LocationError.denied))
            @unknown default:
                resume(.failure(LocationError.denied))
            }
        }
    }

    /// Reverse-geocoded facts about a location. Both come from a single placemark
    /// so coordinates, country (→ method) and timezone always describe one place.
    struct PlaceInfo: Sendable {
        var countryCode: String?
        var timeZone: TimeZone?
        /// City / town, for display only.
        var locality: String?
    }

    /// Reverse-geocode a location into its country code and timezone. CLGeocoder
    /// is rate-limited, so we resolve both from one request.
    func place(for location: CLLocation) async -> PlaceInfo {
        let placemark = try? await geocoder.reverseGeocodeLocation(location).first
        return PlaceInfo(countryCode: placemark?.isoCountryCode, timeZone: placemark?.timeZone,
                         locality: placemark?.locality)
    }

    // MARK: Continuation plumbing

    private func resume(_ result: Result<CLLocation, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }

    // MARK: CLLocationManagerDelegate (delivered on the main thread)

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus   // Sendable; avoid capturing `manager`
        MainActor.assumeIsolated {
            authorization = status
            guard continuation != nil else { return }
            switch status {
            case .authorized, .authorizedAlways:
                self.manager.requestLocation()
            case .denied, .restricted:
                resume(.failure(LocationError.denied))
            default:
                break   // still .notDetermined; wait
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let first = locations.first
        MainActor.assumeIsolated {
            if let first {
                resume(.success(first))
            } else {
                resume(.failure(LocationError.noResult))
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let message = error.localizedDescription   // Sendable; avoid capturing `error`
        MainActor.assumeIsolated {
            resume(.failure(LocationError.failed(message)))
        }
    }
}
