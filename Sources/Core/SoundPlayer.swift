import Foundation
import AVFoundation

/// 声音服务：环境音循环（专注时播放）+ 完成提示音
final class SoundPlayer: ObservableObject {

    static let shared = SoundPlayer()

    /// 环境音清单（文件名与 Resources/Sounds 对应）
    static let ambientTypes: [(id: String, name: String)] = [
        ("none", "无"),
        ("rain", "雨声"),
        ("forest", "森林"),
        ("ocean", "海浪"),
        ("fan", "风扇"),
        ("white", "白噪音"),
        ("pink", "粉噪音"),
        ("brown", "棕噪音"),
    ]

    static let tones: [(id: String, name: String)] = [
        ("none", "无"),
        ("gentle", "轻柔"),
        ("chime", "风铃"),
        ("bell", "钟声"),
        ("digital", "电子"),
    ]

    @Published private(set) var isPlaying = false

    private var player: AVAudioPlayer?
    private var tonePlayer: AVAudioPlayer?

    // MARK: 环境音

    func startAmbient(type: String, volume: Double) {
        stopAmbient()
        guard type != "none",
              let url = Self.url(for: type) else { return }
        do {
            try Self.activateSession()
            let p = try AVAudioPlayer(contentsOf: url)
            p.numberOfLoops = -1
            p.volume = Float(volume)
            p.prepareToPlay()
            p.play()
            player = p
            isPlaying = true
        } catch {
            NSLog("[FlowSim] ambient error: \(error.localizedDescription)")
        }
    }

    /// 音量实时变化
    func applyVolume(_ v: Double) {
        player?.volume = Float(v)
    }

    func stopAmbient() {
        player?.stop()
        player = nil
        isPlaying = false
    }

    // MARK: 提示音（单次）

    func playTone(_ id: String, volume: Double = 0.8) {
        guard id != "none", let url = Self.url(for: id) else { return }
        do {
            try Self.activateSession()
            let p = try AVAudioPlayer(contentsOf: url)
            p.volume = Float(volume)
            p.play()
            tonePlayer = p
        } catch {
            NSLog("[FlowSim] tone error: \(error.localizedDescription)")
        }
    }

    // MARK: 工具

    static func name(of id: String) -> String {
        ambientTypes.first { $0.id == id }?.name ?? id
    }

    private static func url(for id: String) -> URL? {
        for ext in ["m4a", "wav"] {
            if let u = Bundle.main.url(forResource: id, withExtension: ext) { return u }
        }
        return nil
    }

    private static func activateSession() throws {
        let session = AVAudioSession.sharedInstance()
        if session.category != .playback {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        }
        if !session.isOtherAudioPlaying {
            try session.setActive(true)
        }
    }
}
