import Foundation

/// A user-imported custom Adhan audio file (§8, custom-Adhan feature). This is a
/// pure value description of an imported file — the app target owns the actual
/// file I/O (import, validation, copy, playback) and resolves `fileName` against
/// its Application Support directory. Keeping it in PrayerKit lets it persist with
/// `AppSettings` and be shared with a future widget without pulling any I/O into
/// the core.
///
/// `id` is the stable identity referenced by `NotificationSound.custom(_:)`;
/// `fileName` is stored **relative** to the custom-Adhan directory (never an
/// absolute path) so the storage root can move (e.g. into an App Group container)
/// without rewriting persisted state.
public struct CustomSound: Codable, Sendable, Hashable, Identifiable {
    /// Stable identity; matches the UUID carried by `NotificationSound.custom(_:)`.
    public let id: UUID
    /// File name relative to the app's custom-Adhan directory, e.g. `"<uuid>.mp3"`.
    public let fileName: String
    /// User-facing, renamable label shown in the sound pickers.
    public var displayName: String
    /// Duration in seconds, captured at import for display; `nil` if unknown.
    public var durationSeconds: Double?

    public init(id: UUID, fileName: String, displayName: String, durationSeconds: Double? = nil) {
        self.id = id
        self.fileName = fileName
        self.displayName = displayName
        self.durationSeconds = durationSeconds
    }
}
