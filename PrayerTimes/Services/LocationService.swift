import Foundation
import CoreLocation
import Observation
import OSLog

enum LocationError: LocalizedError {
    case denied
    case noResult
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .denied: return "Location access was denied. Enable it in System Settings → Privacy & Security → Location Services."
        case .noResult: return "No location was returned."
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
    private let log = Logger(subsystem: "com.wedevs.prayertimes", category: "location")

    private(set) var authorization: CLAuthorizationStatus
    @ObservationIgnored private var continuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// Fetch the current location once, prompting for authorization if needed.
    func fetchCurrent() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { continuation in
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

    /// ISO 3166-1 alpha-2 country code for a location, or nil.
    func countryCode(for location: CLLocation) async -> String? {
        try? await geocoder.reverseGeocodeLocation(location).first?.isoCountryCode
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
