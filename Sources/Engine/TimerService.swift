import Foundation
import AVFoundation
import Combine

/// Background-capable 1-second timer using DispatchSourceTimer + AVAudioSession keep-alive.
///
/// Strategy:
/// 1. Configure AVAudioSession with `.playback` category (allows background audio).
/// 2. Play a silent audio loop to prevent iOS from suspending the app in background.
/// 3. Use DispatchSourceTimer for accurate 1s ticks.
/// 4. On foreground, AVAudioSession is enough; the silent audio only kicks in during background.
public final class TimerService: ObservableObject {

    public static let shared = TimerService()

    @Published public private(set) var tick: Int = 0

    private var timer: DispatchSourceTimer?
    private var silentPlayer: AVAudioPlayer?
    private var isKeepAliveActive = false

    private init() {}

    // MARK: - Timer lifecycle

    public func start() {
        stop()
        configureAudioSession()
        activateKeepAlive()

        let t = DispatchSource.makeTimerSource(queue: .global(qos: .userInitiated))
        t.schedule(deadline: .now() + 1.0, repeating: 1.0, leeway: .milliseconds(50))
        t.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                self?.tick &+= 1
            }
        }
        t.resume()
        timer = t
    }

    public func stop() {
        timer?.cancel()
        timer = nil
    }

    public func deactivateBackground() {
        stop()
        deactivateKeepAlive()
    }

    // MARK: - AVAudioSession keep-alive

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default,
                                     options: [.mixWithOthers, .duckOthers])
            try session.setActive(true, options: [])
        } catch {
            NSLog("[FocusFlip] AVAudioSession config error: \(error.localizedDescription)")
        }
    }

    /// Play a silent audio loop to keep the app alive in background.
    /// We generate a 1-second silent WAV in memory at runtime.
    private func activateKeepAlive() {
        guard !isKeepAliveActive else { return }

        // Generate 1 second of silence as raw PCM -> WAV Data
        let sampleRate = 44100
        let numSamples = sampleRate * 1
        let silentData = Data(count: Int(numSamples) * 2) // 16-bit = 2 bytes/sample

        let wavData = Self.makeWAVHeader(sampleRate: sampleRate,
                                          numChannels: 1,
                                          bitsPerSample: 16,
                                          dataLength: silentData.count) + silentData

        do {
            silentPlayer = try AVAudioPlayer(data: wavData)
            silentPlayer?.numberOfLoops = -1   // infinite
            silentPlayer?.volume = 0.01         // nearly silent but keeps audio session active
            silentPlayer?.play()
            isKeepAliveActive = true
        } catch {
            NSLog("[FocusFlip] Silent player error: \(error.localizedDescription)")
        }
    }

    private func deactivateKeepAlive() {
        silentPlayer?.stop()
        silentPlayer = nil
        isKeepAliveActive = false
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    // MARK: - WAV header builder (for silent audio)

    private static func makeWAVHeader(sampleRate: Int, numChannels: Int,
                                       bitsPerSample: Int, dataLength: Int) -> Data {
        let byteRate = sampleRate * numChannels * bitsPerSample / 8
        let blockAlign = numChannels * bitsPerSample / 8
        let chunkSize = 36 + dataLength
        let subchunk1Size = 16
        let audioFormat: UInt16 = 1 // PCM

        var header = Data()
        header.append("RIFF".data(using: .ascii)!)
        header.append(UInt32(chunkSize).littleEndianBytes)
        header.append("WAVE".data(using: .ascii)!)
        header.append("fmt ".data(using: .ascii)!)
        header.append(UInt32(subchunk1Size).littleEndianBytes)
        header.append(audioFormat.littleEndianBytes)
        header.append(UInt16(numChannels).littleEndianBytes)
        header.append(UInt32(sampleRate).littleEndianBytes)
        header.append(UInt32(byteRate).littleEndianBytes)
        header.append(UInt16(blockAlign).littleEndianBytes)
        header.append(UInt16(bitsPerSample).littleEndianBytes)
        header.append("data".data(using: .ascii)!)
        header.append(UInt32(dataLength).littleEndianBytes)
        return header
    }
}

// MARK: - FixedWidthInteger to little-endian bytes

private extension FixedWidthInteger {
    var littleEndianBytes: Data {
        var v = self.littleEndian
        return withUnsafeBytes(of: &v) { Data($0) }
    }
}
