import Foundation
import Combine

/// 用户偏好（UserDefaults 持久化）
final class Prefs: ObservableObject {

    static let shared = Prefs()
    private let d = UserDefaults.standard

    @Published var autoStartBreaks: Bool  { didSet { d.set(autoStartBreaks, forKey: "autoStartBreaks") } }
    @Published var autoStartFocus: Bool   { didSet { d.set(autoStartFocus, forKey: "autoStartFocus") } }
    @Published var keepAwake: Bool        { didSet { d.set(keepAwake, forKey: "keepAwake") } }
    @Published var immersive: Bool        { didSet { d.set(immersive, forKey: "immersive") } }
    @Published var dailyGoal: Int         { didSet { d.set(dailyGoal, forKey: "dailyGoal") } }
    @Published var countdownCounts: Bool  { didSet { d.set(countdownCounts, forKey: "countdownCounts") } }

    /// 目标倒计时：id → 提前提醒天数（0=不提醒）。放 UserDefaults 避免动 CoreData 模型
    @Published var targetReminderDays: [String: Int] {
        didSet { d.set(targetReminderDays, forKey: "targetReminderDays") }
    }
    /// 目标倒计时：id → 关联任务 id 字符串
    @Published var targetLinkedTask: [String: String] {
        didSet { d.set(targetLinkedTask, forKey: "targetLinkedTask") }
    }

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
        immersive       = d.object(forKey: "immersive") as? Bool ?? false
        dailyGoal       = d.object(forKey: "dailyGoal") as? Int ?? 8
        countdownCounts = d.object(forKey: "countdownCounts") as? Bool ?? false
        targetReminderDays = (d.object(forKey: "targetReminderDays") as? [String: Int]) ?? [:]
        targetLinkedTask   = (d.object(forKey: "targetLinkedTask") as? [String: String]) ?? [:]
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
