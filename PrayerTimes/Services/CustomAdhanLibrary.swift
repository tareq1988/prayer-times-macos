import Foundation
import AVFoundation
import Observation
import OSLog
import PrayerKit

/// Reasons an imported audio file is rejected. Messages are user-facing and
/// localized (the file itself is never localized — names on disk are UUID-based).
enum CustomAdhanError: LocalizedError {
    case notPlayable
    case noAudioTrack
    case unreadable
    case tooLong

    var errorDescription: String? {
        switch self {
        case .notPlayable, .noAudioTrack:
            return String(localized: "This isn't a supported audio format.")
        case .unreadable:
            return String(localized: "Couldn't read this audio file.")
        case .tooLong:
            return String(localized: "This audio is too long (max 10 minutes).")
        }
    }
}

/// Owns the on-disk store of user-imported custom Adhan files and the import
/// pipeline (validate → copy). Pure metadata lives in `AppSettings.customSounds`
/// (PrayerKit); this app-target service is the only place that touches the file
/// system, keeping the calculation core I/O-free.
///
/// Files live under `~/Library/Application Support/<bundleId>/CustomAdhans/`, named
/// `<uuid>.<ext>`. The app is unsandboxed (spec §12), so reads need no
/// security-scoped bookmarks; the import still brackets the source read in
/// `startAccessingSecurityScopedResource()` so nothing changes if a sandbox is
/// ever adopted. Only the **relative** file name is persisted, so the storage root
/// can later move into an App Group container without rewriting settings.
@MainActor
@Observable
final class CustomAdhanLibrary {
    /// Hard cap on imported duration. Real Adhans run 2–5 min; 10 gives headroom
    /// while preventing a long file from playing from one prayer into the next.
    /// `nonisolated` so the off-main `validateAndCopy` can read it.
    nonisolated static let maxDuration: TimeInterval = 10 * 60

    @ObservationIgnored private let log = Logger(subsystem: "co.tareq.prayertimes", category: "customadhan")
    @ObservationIgnored private let directory: URL

    init() {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        let bundleID = Bundle.main.bundleIdentifier ?? "co.tareq.prayertimes"
        directory = base
            .appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent("CustomAdhans", isDirectory: true)
    }

    /// Resolve a custom sound to its on-disk URL, or `nil` if unknown/missing.
    func resolvedURL(for id: UUID, in customSounds: [CustomSound]) -> URL? {
        guard let sound = customSounds.first(where: { $0.id == id }) else { return nil }
        let url = directory.appendingPathComponent(sound.fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Validate a user-picked file and copy it into the library. Returns the
    /// metadata to store in `AppSettings.customSounds`. Throws `CustomAdhanError`
    /// on a rejected file (nothing is copied on failure).
    func importFile(from source: URL) async throws -> CustomSound {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let id = UUID()
        let ext = source.pathExtension.isEmpty ? "audio" : source.pathExtension.lowercased()
        let fileName = "\(id.uuidString).\(ext)"
        let destination = directory.appendingPathComponent(fileName)
        let displayName = source.deletingPathExtension().lastPathComponent
        let duration = try await Self.validateAndCopy(source: source, destination: destination)
        log.notice("Imported custom Adhan \(fileName, privacy: .public) (\(Int(duration))s)")
        return CustomSound(id: id, fileName: fileName, displayName: displayName, durationSeconds: duration)
    }

    /// Delete the backing file (best effort). The caller must also drop the
    /// metadata from settings and sweep any selections that referenced it.
    func deleteFile(_ sound: CustomSound) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(sound.fileName))
    }

    /// Ids whose backing file is missing on disk (drives a "re-import" badge).
    func missingIDs(in customSounds: [CustomSound]) -> Set<UUID> {
        var missing: Set<UUID> = []
        for sound in customSounds
        where !FileManager.default.fileExists(atPath: directory.appendingPathComponent(sound.fileName).path) {
            missing.insert(sound.id)
        }
        return missing
    }

    // MARK: Validation + copy (runs off the main actor)

    /// Validate the source is decodable audio within the duration cap, then copy it
    /// to `destination`. `nonisolated` so the AVFoundation probing and file copy run
    /// off the main actor; only the `Sendable` duration crosses back.
    nonisolated static func validateAndCopy(source: URL, destination: URL) async throws -> Double {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }

        let asset = AVURLAsset(url: source)

        guard (try? await asset.load(.isPlayable)) == true else { throw CustomAdhanError.notPlayable }
        let audioTracks = (try? await asset.loadTracks(withMediaType: .audio)) ?? []
        guard !audioTracks.isEmpty else { throw CustomAdhanError.noAudioTrack }

        let duration = (try? await asset.load(.duration)).map(CMTimeGetSeconds) ?? 0
        guard duration.isFinite, duration > 0 else { throw CustomAdhanError.unreadable }
        guard duration <= CustomAdhanLibrary.maxDuration else { throw CustomAdhanError.tooLong }

        // Validate with the same engine that plays it at prayer time, so a file that
        // imports is guaranteed to actually play (AVURLAsset and AVAudioPlayer codec
        // support differ slightly).
        guard (try? AVAudioPlayer(contentsOf: source)) != nil else { throw CustomAdhanError.notPlayable }

        try? FileManager.default.removeItem(at: destination)   // UUID names shouldn't collide; be safe
        try FileManager.default.copyItem(at: source, to: destination)
        return duration
    }
}
