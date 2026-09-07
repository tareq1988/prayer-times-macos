import XCTest
@testable import PrayerKit

/// The periodic re-detect schedule: due before the first fix, a short retry
/// after a failed attempt, the full interval after a success, and wake forcing
/// the next check while keeping the last-success timestamp.
final class LocationRefreshPolicyTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_750_000_000)
    private func after(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    func testDueImmediatelyBeforeFirstFix() {
        let policy = LocationRefreshPolicy()
        XCTAssertTrue(policy.isDue(at: t0))
        XCTAssertNil(policy.lastSuccess)
    }

    func testFailedAttemptRetriesAfterRetryInterval() {
        var policy = LocationRefreshPolicy(interval: 1800, retry: 120)
        policy.didAttempt(at: t0)
        XCTAssertFalse(policy.isDue(at: after(119)))
        XCTAssertTrue(policy.isDue(at: after(120)))
        XCTAssertNil(policy.lastSuccess, "a failed attempt is not a fix")
    }

    func testSuccessWaitsTheFullInterval() {
        var policy = LocationRefreshPolicy(interval: 1800, retry: 120)
        policy.didAttempt(at: t0)
        policy.didSucceed(at: after(3))
        XCTAssertEqual(policy.lastSuccess, after(3))
        XCTAssertFalse(policy.isDue(at: after(1802)))
        XCTAssertTrue(policy.isDue(at: after(1803)))
    }

    func testWakeMakesRefreshDueAndKeepsLastSuccess() {
        var policy = LocationRefreshPolicy(interval: 1800, retry: 120)
        policy.didSucceed(at: t0)
        XCTAssertFalse(policy.isDue(at: after(1)))
        policy.markStale()
        XCTAssertTrue(policy.isDue(at: after(1)))
        XCTAssertEqual(policy.lastSuccess, t0)
    }
}
