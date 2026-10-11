import CoreLocation
import Testing
@testable import Prayer_Times

/// `LocationRetryPolicy` is the decision core behind the cold-start behaviour:
/// right after a restart, CoreLocation often reports `CLErrorDomain error 0`
/// (`kCLErrorLocationUnknown`) because `locationd`/Wi-Fi positioning aren't warm
/// yet. That failure must be retried with backoff; terminal failures must not.
struct LocationRetryPolicyTests {
    @Test("Transient locationUnknown is retried on every budgeted attempt")
    func locationUnknownRetriesWithinBudget() {
        for attempt in LocationRetryPolicy.delays.indices {
            #expect(
                LocationRetryPolicy.action(for: .locationUnknown, attempt: attempt)
                    == .retry(after: LocationRetryPolicy.delays[attempt])
            )
        }
    }

    @Test("Retries stop once the backoff budget is exhausted")
    func budgetExhaustionFails() {
        let pastBudget = LocationRetryPolicy.delays.count
        #expect(LocationRetryPolicy.action(for: .locationUnknown, attempt: pastBudget) == .fail)
        #expect(LocationRetryPolicy.action(for: .locationUnknown, attempt: pastBudget + 5) == .fail)
    }

    @Test("Denied is terminal and never retried")
    func deniedIsTerminal() {
        #expect(LocationRetryPolicy.action(for: .denied, attempt: 0) == .fail)
    }

    @Test("Network errors are terminal for the one-shot request")
    func networkIsTerminal() {
        #expect(LocationRetryPolicy.action(for: .network, attempt: 0) == .fail)
    }

    @Test("Errors that didn't come from CoreLocation are terminal")
    func nonCLFailureIsTerminal() {
        #expect(LocationRetryPolicy.action(for: nil, attempt: 0) == .fail)
    }

    @Test("Backoff grows, giving locationd more time after each miss")
    func backoffIsIncreasing() {
        let delays = LocationRetryPolicy.delays
        #expect(delays.count >= 2)
        for index in delays.indices.dropFirst() {
            #expect(delays[index] > delays[index - 1])
        }
    }

    /// The bug this guards: the raw CLError string reached the UI verbatim as
    /// "The operation couldn't be completed. (CLErrorDomain error 0.)".
    @Test("Exhausted transient failure explains itself, not CLErrorDomain error 0")
    func notReadyHidesRawErrorCode() {
        let description = LocationError.notReady.errorDescription ?? ""
        #expect(!description.isEmpty)
        #expect(!description.contains("CLErrorDomain"))
        #expect(!description.contains("error 0"))
    }
}
