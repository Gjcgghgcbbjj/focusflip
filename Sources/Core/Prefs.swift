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

    private init() {
        autoStartBreaks = d.object(forKey: "autoStartBreaks") as? Bool ?? true
        autoStartFocus  = d.object(forKey: "autoStartFocus") as? Bool ?? false
        keepAwake       = d.object(forKey: "keepAwake") as? Bool ?? true
        focusMinutes    = d.object(forKey: "focusMinutes") as? Int ?? 25
        shortMinutes    = d.object(forKey: "shortMinutes") as? Int ?? 5
        longMinutes     = d.object(forKey: "longMinutes") as? Int ?? 15
        longEvery       = d.object(forKey: "longEvery") as? Int ?? 4
    }
}
