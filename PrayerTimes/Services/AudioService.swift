import Foundation
import AVFoundation
import AppKit
import Observation
import OSLog
import PrayerKit

/// Plays the full Adhan in-process (spec §9). The notification framework caps
/// custom sounds at ~30 s, so a full Adhan can't ride on the notification; the
/// resident menu bar agent plays it directly via `AVAudioPlayer` at the prayer
/// instant instead. Also provides short sound previews for the settings UI.
///
/// Audio files are expected in the app bundle (Resources/Adhan + Resources/Sounds).
/// Until they're added, playback no-ops with a log instead of crashing.
@MainActor
@Observable
final class AudioService: NSObject, AVAudioPlayerDelegate {
    private(set) var isPlaying = false

    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private let log = Logger(subsystem: "co.tareq.prayertimes", category: "audio")
    @ObservationIgnored private let library: CustomAdhanLibrary

    init(library: CustomAdhanLibrary) {
        self.library = library
        super.init()
    }

    /// Play the full Adhan for `sound`. For a bundled Adhan (Makkah/Madinah) this
    /// plays the bundled file; for a `.custom` selection it resolves the user file
    /// via `customSounds`. If a custom file is missing/corrupt at the prayer instant
    /// it falls back to the bundled takbir clip — never silence, never a crash.
    func playFullAdhan(_ sound: NotificationSound, customSounds: [CustomSound] = []) {
        if let id = sound.customID {
            if let url = library.resolvedURL(for: id, in: customSounds) {
                play(url)
            } else {
                log.warning("Custom Adhan missing for \(id, privacy: .public); falling back to takbir")
                playFallbackClip()
            }
            return
        }
        guard let fileName = sound.fullAdhanFileName else { return }
        guard let url = Self.bundleURL(for: fileName) else {
            log.warning("Full Adhan file not bundled: \(fileName, privacy: .public)")
            return
        }
        play(url)
    }

    /// Play a preview for the settings sound pickers. Adhan selections preview
    /// the full Adhan (so the user actually hears what they chose); other sounds
    /// preview their short clip.
    func preview(_ sound: NotificationSound, customSounds: [CustomSound] = []) {
        switch sound {
        case .none:
            return
        case .systemDefault:
            NSSound.beep()   // no file — represent the OS notification sound
            return
        default:
            break
        }
        if let id = sound.customID {
            if let url = library.resolvedURL(for: id, in: customSounds) {
                play(url)
            } else {
                log.warning("Custom Adhan preview missing for \(id, privacy: .public)")
            }
            return
        }
        guard let fileName = sound.fullAdhanFileName ?? sound.notificationClipFileName else {
            return
        }
        guard let url = Self.bundleURL(for: fileName) else {
            log.warning("Preview file not bundled: \(fileName, privacy: .public)")
            return
        }
        play(url)
    }

    /// Play the short alert clip for `sound` in-process at prayer time. The
    /// resident agent plays the prayer sound itself because macOS custom
    /// *notification* sounds are unreliable (they often silently fail to play),
    /// while in-process `AVAudioPlayer` is dependable — it's the same path the
    /// settings preview uses, so what the user hears on time matches the preview.
    /// No-op for selections without a bundled clip (`.none` / `.systemDefault`,
    /// which ride on the notification's own sound instead).
    func playClip(_ sound: NotificationSound) {
        guard let fileName = sound.notificationClipFileName,
              let url = Self.bundleURL(for: fileName) else { return }
        play(url)
    }

    /// Stop any in-progress playback (Stop Adhan control, spec §7.5).
    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
    }

    // MARK: AVAudioPlayerDelegate

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.isPlaying = false }
    }

    // MARK: Helpers

    /// Last-resort audible fallback when a custom Adhan can't be resolved at the
    /// prayer instant — better a short takbir than silence at a crossed prayer.
    private func playFallbackClip() {
        guard let url = Self.bundleURL(for: "takbir.caf") else { return }
        play(url)
    }

    private func play(_ url: URL) {
        stop()
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.prepareToPlay()
            player.play()
            self.player = player
            isPlaying = true
        } catch {
            log.error("Failed to play \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
            isPlaying = false
        }
    }

    /// Locate a bundled audio file by name, checking the Adhan/Sounds subfolders
    /// and the bundle root (resource folder references may flatten or nest).
    private static func bundleURL(for fileName: String) -> URL? {
        let name = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        let subdirs: [String?] = ["Adhan", "Sounds", nil]
        for subdir in subdirs {
            if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: subdir) {
                return url
            }
        }
        return nil
    }
}
