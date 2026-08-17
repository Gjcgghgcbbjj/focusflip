import Foundation
import AVFoundation
import Combine

/// White noise + completion sound player.
///
/// White noise is synthesized at runtime using AVAudioEngine to avoid bundling
/// large audio files. Each noise type uses a different synthesis approach:
///   - rain:   filtered white noise (bandpass ~ 1-8kHz)
///   - ocean:  low-frequency noise with slow amplitude LFO
///   - forest: filtered noise + random bird chirps (sine bursts)
///   - fan:    brown noise (low-pass)
///   - silence: no audio (keep-alive only)
public final class SoundPlayer: ObservableObject {

    public static let shared = SoundPlayer()

    @Published public private(set) var isPlaying: Bool = false

    private let engine = AVAudioEngine()
    private var noiseNode: AVAudioPlayerNode?
    private var buffer: AVAudioPCMBuffer?

    private var settings = AppSettings.shared

    private init() {}

    // MARK: - White noise control

    public func playWhiteNoise() {
        guard settings.whiteNoiseEnabled else { return }
        stopWhiteNoise()

        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        buffer = generateNoiseBuffer(format: format, type: settings.whiteNoiseType)

        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)

        // Set volume
        player.volume = settings.whiteNoiseVolume
        engine.mainMixerNode.outputVolume = 1.0

        do {
            try engine.start()
            player.scheduleBuffer(buffer!, at: nil, options: .loops, completionHandler: nil)
            player.play()
            noiseNode = player
            isPlaying = true
        } catch {
            NSLog("[FocusFlip] Audio engine start error: \(error.localizedDescription)")
        }
    }

    public func pauseWhiteNoise() {
        noiseNode?.pause()
        isPlaying = false
    }

    public func resumeWhiteNoise() {
        noiseNode?.play()
        isPlaying = true
    }

    public func stopWhiteNoise() {
        noiseNode?.stop()
        if engine.isRunning { engine.stop() }
        noiseNode = nil
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

        let soundType = settings.completionSoundType
        switch soundType {
        case "bell":     playTone(frequencies: [880, 1100, 1320], duration: 0.3)
        case "chime":    playTone(frequencies: [660, 880], duration: 0.4)
        case "digital":  playTone(frequencies: [1000, 800, 1000], duration: 0.15)
        case "gentle":   playTone(frequencies: [523, 659, 784], duration: 0.5)
        default:        playTone(frequencies: [880], duration: 0.3)
        }
    }

    // MARK: - Noise generation

    private func generateNoiseBuffer(format: AVAudioFormat, type: String) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(format.sampleRate * 2)  // 2 seconds, looped
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        let channels = Int(format.channelCount)
        let sampleRate = format.sampleRate

        guard let data = buffer.floatChannelData else { return buffer }

        for channel in 0..<channels {
            let channelData = data[channel]
            var lastOut: Float = 0.0

            for i in 0..<Int(frameCount) {
                let white = Float.random(in: -1...1)
                let sample: Float

                switch type {
                case "rain":
                    // Bandpass-ish: simple high-pass filter
                    lastOut = lastOut * 0.95 + white * 0.05
                    sample = white * 0.3 - lastOut

                case "ocean":
                    // Brown noise + slow LFO for wave effect
                    lastOut = (lastOut + 0.02 * white) / 1.02
                    let lfo = sin(Double(i) / sampleRate * 0.15)
                    sample = lastOut * 3.0 * Float(lfo)

                case "forest":
                    // Filtered noise + occasional bird chirp
                    lastOut = lastOut * 0.9 + white * 0.1
                    let chirp = sin(Double(i) / sampleRate * 2000) * 0.1
                    let isChirpTime = (i % 44100) < 5000 && (i / 44100) % 3 == 0
                    sample = lastOut * 2.0 + (isChirpTime ? Float(chirp) : 0)

                case "fan":
                    // Brown noise (low-pass)
                    lastOut = (lastOut + 0.02 * white) / 1.02
                    sample = lastOut * 3.5

                default:
                    sample = white * 0.3
                }

                channelData[i] = max(-1.0, min(1.0, sample))
            }
        }
        return buffer
    }

    // MARK: - Tone synthesis (for completion sounds)

    private func playTone(frequencies: [Double], duration: Double) {
        let sampleRate = 44100.0
        let totalFrames = AVAudioFrameCount(sampleRate * duration)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames)!
        buffer.frameLength = totalFrames

        guard let data = buffer.floatChannelData else { return }
        let channelData = data[0]

        let segmentLength = totalFrames / AVAudioFrameCount(frequencies.count)

        for (index, freq) in frequencies.enumerated() {
            let start = AVAudioFrameCount(index) * segmentLength
            let end = start + segmentLength

            for i in start..<end {
                let t = Double(i - start) / sampleRate
                // Simple envelope: attack + decay
                let envelope = min(1.0, Double(i - start) / (sampleRate * 0.01)) *
                               max(0.0, 1.0 - Double(i - start) / Double(segmentLength))
                let value = sin(2.0 * .pi * freq * t) * envelope * 0.5
                channelData[Int(i)] = Float(value)
            }
        }

        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)

        if !engine.isRunning {
            try? engine.start()
        }

        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        player.play()

        // Clean up after playback
        let delay = duration + 0.1
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak player] in
            player?.stop()
        }
    }
}
