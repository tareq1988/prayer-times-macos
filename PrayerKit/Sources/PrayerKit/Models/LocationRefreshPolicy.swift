import Foundation

/// Decides when the observer location should be re-detected in automatic mode.
/// Pure timing state, kept apart from CoreLocation so the schedule is testable.
///
/// A new fix is requested every `interval` after the last successful one. An
/// attempt that does not succeed (no network yet after wake, a CoreLocation
/// error) retries after the shorter `retry`, so one bad attempt does not leave
/// a stale location in place for a whole interval. `markStale()` (system wake,
/// the moment a laptop is most likely to have moved) makes the next check due
/// immediately.
public struct LocationRefreshPolicy: Sendable, Equatable {
    /// Seconds between successful fixes.
    public var interval: TimeInterval
    /// Seconds to wait before retrying after an attempt that did not succeed.
    public var retry: TimeInterval
    /// When the location was last detected successfully; nil until the first fix.
    public private(set) var lastSuccess: Date?
    /// When the next attempt becomes due (`.distantPast` = due now).
    public private(set) var nextAttempt: Date = .distantPast

    /// `lastSuccess` seeds a remembered fix from a previous run; the first
    /// check is still due immediately, since the machine may have moved since.
    public init(interval: TimeInterval = 30 * 60, retry: TimeInterval = 2 * 60, lastSuccess: Date? = nil) {
        self.interval = interval
        self.retry = retry
        self.lastSuccess = lastSuccess
    }

    /// Whether a detection attempt should be started now.
    public func isDue(at now: Date) -> Bool { now >= nextAttempt }

    /// Record that an attempt was started. Holds off further attempts for
    /// `retry`; `didSucceed` extends that to the full interval.
    public mutating func didAttempt(at now: Date) {
        nextAttempt = now.addingTimeInterval(retry)
    }

    /// Record a successful fix; the next attempt is due after `interval`.
    public mutating func didSucceed(at now: Date) {
        lastSuccess = now
        nextAttempt = now.addingTimeInterval(interval)
    }

    /// Make the next check due immediately (e.g. after system wake).
    public mutating func markStale() { nextAttempt = .distantPast }
}
