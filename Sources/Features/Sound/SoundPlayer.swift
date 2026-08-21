import Foundation
import AVFoundation
import Combine

/// White noise + completion sound player.
///
/// Plays bundled high-quality WAV files (generated offline, loop-seamless)
/// via AVAudioPlayer. Fallback lookup covers both flat and "Sounds"
/// subdirectory resource layouts.
public final class SoundPlayer: ObservableObject {

    public static let shared = SoundPlayer()

    @Published public private(set) var isPlaying: Bool = false

    private var noisePlayer: AVAudioPlayer?
    private var layerPlayer: AVAudioPlayer?

    private var settings = AppSettings.shared

    private init() {}

    // MARK: - White noise control

    public func playWhiteNoise() {
        guard settings.whiteNoiseEnabled else { return }
        stopWhiteNoise()

        do {
            // 主音效
            if let url = soundURL(for: settings.whiteNoiseType) {
                let player = try AVAudioPlayer(contentsOf: url)
                player.numberOfLoops = -1
                player.volume = settings.whiteNoiseVolume
                player.prepareToPlay()
                player.play()
                noisePlayer = player
            } else {
                NSLog("[FocusFlip] White noise file not found: \(settings.whiteNoiseType)")
            }

            // 叠加音效（可选，音量为主音效的 60%）
            let layer = settings.whiteNoiseLayerType
            if layer != "none", layer != settings.whiteNoiseType,
               let url = soundURL(for: layer) {
                let player = try AVAudioPlayer(contentsOf: url)
                player.numberOfLoops = -1
                player.volume = settings.whiteNoiseVolume * 0.6
                player.prepareToPlay()
                player.play()
                layerPlayer = player
            }

            isPlaying = noisePlayer != nil || layerPlayer != nil
        } catch {
            NSLog("[FocusFlip] White noise play error: \(error.localizedDescription)")
        }
    }

    public func pauseWhiteNoise() {
        noisePlayer?.pause()
        layerPlayer?.pause()
        isPlaying = false
    }

    public func resumeWhiteNoise() {
        noisePlayer?.play()
        layerPlayer?.play()
        isPlaying = true
    }

    public func stopWhiteNoise() {
        noisePlayer?.stop()
        noisePlayer = nil
        layerPlayer?.stop()
        layerPlayer = nil
        isPlaying = false
    }

    public func toggleWhiteNoise() {
        if isPlaying {
            stopWhiteNoise()
        } else {
            playWhiteNoise()
        }
    }

    // MARK: - Completion sound

    public func playCompletionSound() {
        guard settings.completionSoundEnabled else { return }

        let type = settings.completionSoundType
        guard let url = soundURL(for: type) else {
            NSLog("[FocusFlip] Completion sound file not found: \(type)")
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = 1.0
            player.prepareToPlay()
            player.play()
            // Release after playback (completion sounds are short)
            let duration = player.duration + 0.2
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                player.stop()
            }
        } catch {
            NSLog("[FocusFlip] Completion sound play error: \(error.localizedDescription)")
        }
    }

    // MARK: - File lookup

    /// Resolves a bundled WAV by base name, checking both the "Sounds"
    /// subdirectory and the bundle root (resource layout depends on how
    /// xcodegen folds folders into the build).
    private func soundURL(for name: String) -> URL? {
        if let url = Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "Sounds") {
            return url
        }
        return Bundle.main.url(forResource: name, withExtension: "wav")
    }
}
