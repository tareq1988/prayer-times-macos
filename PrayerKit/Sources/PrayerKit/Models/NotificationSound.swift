import Foundation

/// Selectable sound for a notification slot. The `.adhan*` cases play a full-length
/// Adhan file in-process via `AVAudioPlayer` at the prayer instant (see §9); the
/// clip cases play a short bundled sound. `.custom(_:)` references a user-imported
/// file by id (`CustomSound.id`); the app target resolves the actual file URL —
/// the pure core deliberately knows nothing about where the file lives.
///
/// Note the enum carries an associated value, so it cannot use a `String` raw type;
/// `Codable` and `CaseIterable` are hand-written below. The `Codable` implementation
/// preserves the pre-custom string wire format so persisted settings stay compatible
/// (see `init(from:)`).
public enum NotificationSound: Codable, Sendable, CaseIterable, Hashable {
    case none
    case systemDefault
    case softChime
    case takbir
    case adhanMakkah
    case adhanMadinah
    /// A user-imported custom Adhan, identified by its `CustomSound.id`.
    case custom(UUID)

    /// The selectable built-in sounds, in picker order. `.custom` values are
    /// intentionally excluded — pickers append them from `AppSettings.customSounds`.
    public static let allCases: [NotificationSound] =
        [.none, .systemDefault, .softChime, .takbir, .adhanMakkah, .adhanMadinah]

    /// The imported-file id, if this is a custom selection.
    public var customID: UUID? {
        if case let .custom(id) = self { return id }
        return nil
    }

    /// Whether this selection plays a full-length Adhan on the in-process path. A
    /// custom sound is always treated as a full Adhan (it has a single file, played
    /// in full when the prayer's "Adhan" toggle is on).
    public var hasFullAdhan: Bool {
        switch self {
        case .adhanMakkah, .adhanMadinah, .custom: return true
        default: return false
        }
    }

    /// Bundled short clip filename used for the `UNNotificationSound`, or `nil` for
    /// selections without a bundled clip (`.none`/`.systemDefault`, and `.custom` —
    /// a custom file has no short variant, so it stays silent when "Adhan" is off).
    public var notificationClipFileName: String? {
        switch self {
        case .none, .systemDefault, .custom: return nil
        case .softChime: return "soft-chime.caf"
        case .takbir: return "takbir.caf"
        case .adhanMakkah, .adhanMadinah: return "takbir.caf"
        }
    }

    /// Bundled full-length Adhan filename for the in-process player, if any. `.custom`
    /// returns `nil` here — its file is not bundled; the app resolves it by `customID`.
    public var fullAdhanFileName: String? {
        switch self {
        case .adhanMakkah: return "adhan-makkah.m4a"
        case .adhanMadinah: return "adhan-madinah.m4a"
        default: return nil
        }
    }

    // MARK: Codable

    private static let customPrefix = "custom:"

    /// Stable string form. Built-ins use their historical raw values so blobs
    /// written before `.custom` existed decode byte-for-byte unchanged; `.custom`
    /// encodes as `"custom:<uuid>"`.
    private var wireValue: String {
        switch self {
        case .none: return "none"
        case .systemDefault: return "systemDefault"
        case .softChime: return "softChime"
        case .takbir: return "takbir"
        case .adhanMakkah: return "adhanMakkah"
        case .adhanMadinah: return "adhanMadinah"
        case .custom(let id): return Self.customPrefix + id.uuidString
        }
    }

    private init(wireValue: String) {
        switch wireValue {
        case "none": self = .none
        case "systemDefault": self = .systemDefault
        case "softChime": self = .softChime
        case "takbir": self = .takbir
        case "adhanMakkah": self = .adhanMakkah
        case "adhanMadinah": self = .adhanMadinah
        default:
            if wireValue.hasPrefix(Self.customPrefix),
               let id = UUID(uuidString: String(wireValue.dropFirst(Self.customPrefix.count))) {
                self = .custom(id)
            } else {
                // Unknown or malformed value (e.g. a sound added by a newer build).
                // Fall back rather than throw: a throw here would propagate through
                // AppSettings' resilient decode and reset the entire settings blob.
                self = .systemDefault
            }
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // Tolerate a non-string value too (defensive against a future wire change),
        // so decoding a sound selection can never fail the surrounding blob.
        let raw = (try? container.decode(String.self)) ?? "systemDefault"
        self = NotificationSound(wireValue: raw)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wireValue)
    }
}
