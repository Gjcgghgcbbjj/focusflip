import Foundation
import Combine

/// 用户偏好（UserDefaults 持久化）
final class Prefs: ObservableObject {

    static let shared = Prefs()
    private let d = UserDefaults.standard

    @Published var autoStartBreaks: Bool  { didSet { d.set(autoStartBreaks, forKey: "autoStartBreaks") } }
    @Published var autoStartFocus: Bool   { didSet { d.set(autoStartFocus, forKey: "autoStartFocus") } }
    @Published var keepAwake: Bool        { didSet { d.set(keepAwake, forKey: "keepAwake") } }

    @Published var focusMinutes: Int      { didSet { d.set(focusMinutes, forKey: "focusMinutes") } }
    @Published var shortMinutes: Int      { didSet { d.set(shortMinutes, forKey: "shortMinutes") } }
    @Published var longMinutes: Int       { didSet { d.set(longMinutes, forKey: "longMinutes") } }
    @Published var longEvery: Int         { didSet { d.set(longEvery, forKey: "longEvery") } }

    @Published var soundType: String      { didSet { d.set(soundType, forKey: "soundType") } }
    @Published var soundVolume: Double    { didSet { d.set(soundVolume, forKey: "soundVolume") } }
    @Published var soundAutoPlay: Bool    { didSet { d.set(soundAutoPlay, forKey: "soundAutoPlay") } }
    @Published var toneType: String       { didSet { d.set(toneType, forKey: "toneType") } }

    private init() {
        autoStartBreaks = d.object(forKey: "autoStartBreaks") as? Bool ?? true
        autoStartFocus  = d.object(forKey: "autoStartFocus") as? Bool ?? false
        keepAwake       = d.object(forKey: "keepAwake") as? Bool ?? true
        focusMinutes    = d.object(forKey: "focusMinutes") as? Int ?? 25
        shortMinutes    = d.object(forKey: "shortMinutes") as? Int ?? 5
        longMinutes     = d.object(forKey: "longMinutes") as? Int ?? 15
        longEvery       = d.object(forKey: "longEvery") as? Int ?? 4
        soundType       = d.string(forKey: "soundType") ?? "none"
        soundVolume     = d.object(forKey: "soundVolume") as? Double ?? 0.6
        soundAutoPlay   = d.object(forKey: "soundAutoPlay") as? Bool ?? true
        toneType        = d.string(forKey: "toneType") ?? "gentle"
    }
}
