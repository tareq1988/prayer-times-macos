import Foundation
import CoreLocation
import Observation
import OSLog

enum LocationError: LocalizedError {
    case denied
    case noResult
    case busy
    /// The transient retry budget ran out: CoreLocation still has no fix
    /// (typically a cold start — right after login/restart or wake).
    case notReady
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .denied: return String(localized: "Location access was denied. Enable it in System Settings → Privacy & Security → Location Services.")
        case .noResult: return String(localized: "No location was returned.")
        case .busy: return String(localized: "A location request is already in progress.")
        case .notReady: return String(localized: "Location isn't available yet — it may still be starting up. Try again in a moment.")
        case .failed(let message): return message
        }
    }
}

/// Pure decision policy for one-shot `requestLocation()` failures —
/// deliberately free of any CoreLocation object so it can be unit-tested.
///
/// `kCLErrorLocationUnknown` (CLErrorDomain raw 0, "the location manager was
/// unable to obtain a location yet") is *transient*: it is what CoreLocation
/// reports on a cold start, before `locationd` and Wi-Fi positioning are warm.
/// Failing on it immediately would leak the raw "(CLErrorDomain error 0.)"
/// string to the user and abandon the fetch, so the policy re-issues the
/// request with a short backoff instead until the budget is spent.
enum LocationRetryPolicy {
    /// Backoff before each re-issue. Three retries ≈ 18 s total — long enough
    /// to ride out a cold start, short enough to not hold the spinner forever.
    static let delays: [TimeInterval] = [3, 5, 10]

    enum Action: Equatable {
        case retry(after: TimeInterval)
        case fail
    }

    /// - Parameters:
    ///   - code: The `CLError.Code`, or nil when the error didn't come from CoreLocation.
    ///   - attempt: How many retries the in-flight fetch already consumed (0-based).
    static func action(for code: CLError.Code?, attempt: Int) -> Action {
        guard code == .locationUnknown, attempt < delays.count else { return .fail }
        return .retry(after: delays[attempt])
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
    /// Pending backoff re-issue for a transient `.locationUnknown` failure
    /// (see `LocationRetryPolicy`). Lives only as long as the in-flight fetch —
    /// `resume(_:)` cancels it, so a completed fetch can't be followed by a
    /// stray request.
    @ObservationIgnored private var retryTask: Task<Void, Never>?
    /// How many retries the in-flight fetch has already consumed.
    @ObservationIgnored private var retryAttempt = 0

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
        cancelRetry()
        retryAttempt = 0
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

    /// Reverse-geocoded facts about a location. All come from a single placemark
    /// so coordinates, city, country (→ method) and timezone always describe one
    /// place.
    struct PlaceInfo: Sendable {
        var city: String?
        var countryCode: String?
        var timeZone: TimeZone?
    }

    /// Reverse-geocode a location into its city, country code and timezone.
    /// CLGeocoder is rate-limited, so we resolve everything from one request.
    func place(for location: CLLocation) async -> PlaceInfo {
        let placemark = try? await geocoder.reverseGeocodeLocation(location).first
        return PlaceInfo(
            city: placemark?.locality,
            countryCode: placemark?.isoCountryCode,
            timeZone: placemark?.timeZone
        )
    }

    // MARK: Continuation plumbing

    private func resume(_ result: Result<CLLocation, Error>) {
        cancelRetry()
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }

    /// Drop any scheduled backoff re-issue. Called whenever a fetch completes
    /// (one way or the other) so a late retry can't fire after the fact.
    private func cancelRetry() {
        retryTask?.cancel()
        retryTask = nil
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
        let code = (error as? CLError)?.code              // Sendable; avoid capturing `error`
        let message = error.localizedDescription
        MainActor.assumeIsolated {
            // A late failure after the fetch already finished: nothing to
            // resume, and nothing worth re-issuing.
            guard continuation != nil else { return }
            switch LocationRetryPolicy.action(for: code, attempt: retryAttempt) {
            case .retry(let delay):
                scheduleRetry(after: delay)
            case .fail:
                if code == .locationUnknown {
                    // Budget spent without a fix — say so in human terms rather
                    // than leaking "(CLErrorDomain error 0.)" into the UI.
                    log.warning("No location fix after \(self.retryAttempt) retries")
                    resume(.failure(LocationError.notReady))
                } else if code == .denied {
                    resume(.failure(LocationError.denied))
                } else {
                    resume(.failure(LocationError.failed(message)))
                }
            }
        }
    }

    /// Re-issue the one-shot request after a transient failure. The task only
    /// ever outlives the request it belongs to: `resume(_:)` cancels it, and the
    /// `isCancelled` check plus MainActor serialization guarantee a retry can't
    /// fire once a fix (or a terminal failure) has already been delivered.
    private func scheduleRetry(after delay: TimeInterval) {
        let attempt = retryAttempt
        retryAttempt += 1
        log.warning("Transient location failure; retry \(attempt + 1)/\(LocationRetryPolicy.delays.count) in \(delay)s")
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.manager.requestLocation()
        }
    }
}
