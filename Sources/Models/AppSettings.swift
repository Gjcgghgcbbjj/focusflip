import Foundation
import Combine
import SwiftUI

/// User-configurable settings, persisted via UserDefaults.
/// Observable so SwiftUI views react to changes.
public final class AppSettings: ObservableObject {

    public static let shared = AppSettings()

    /// Accent color resolved from themeColorHex (for DesignSystem3).
    public var accentColor: SwiftUI.Color {
        SwiftUI.Color(UIColor(hex: themeColorHex))
    }

    // MARK: - Pomodoro durations (seconds)
    @Published public var focusDuration: Int     { didSet { save() } }
    @Published public var shortBreakDuration: Int { didSet { save() } }
    @Published public var longBreakDuration: Int  { didSet { save() } }
    @Published public var pomodorosBeforeLongBreak: Int { didSet { save() } }

    // MARK: - Sound
    @Published public var whiteNoiseEnabled: Bool  { didSet { save() } }
    @Published public var whiteNoiseType: String   { didSet { save() } }
    @Published public var whiteNoiseLayerType: String { didSet { save() } }
    @Published public var breakSuggestionEnabled: Bool { didSet { save() } }
    @Published public var whiteNoiseVolume: Float  { didSet { save() } }
    @Published public var completionSoundEnabled: Bool { didSet { save() } }
    @Published public var completionSoundType: String  { didSet { save() } }

    // MARK: - Notifications
    @Published public var hapticsEnabled: Bool        { didSet { save() } }
    @Published public var notificationsEnabled: Bool  { didSet { save() } }

    // MARK: - Focus shield
    @Published public var appShieldEnabled: Bool      { didSet { save() } }
    @Published public var shieldedBundleIds: [String] { didSet { save() } }

    // MARK: - UI
    @Published public var autoStartBreaks: Bool       { didSet { save() } }
    @Published public var autoStartFocus: Bool        { didSet { save() } }
    @Published public var flipClockStyle: String      { didSet { save() } }
    @Published public var themeColorHex: String        { didSet { save() } }
    @Published public var keepScreenAwake: Bool        { didSet { save() } }
    @Published public var immersiveMode: Bool          { didSet { save() } }
    /// system | light | dark —— 默认深色（专注类 App 的正确默认）
    @Published public var appearanceMode: String       { didSet { save() } }

    // MARK: - Daily goal
    @Published public var dailyGoalPomodoros: Int      { didSet { save() } }

    // MARK: - Persistence

    private let defaults = UserDefaults.standard

    private init() {
        let d = UserDefaults.standard
        focusDuration           = d.object(forKey: "focusDuration") as? Int ?? 25 * 60
        shortBreakDuration      = d.object(forKey: "shortBreakDuration") as? Int ?? 5 * 60
        longBreakDuration       = d.object(forKey: "longBreakDuration") as? Int ?? 15 * 60
        pomodorosBeforeLongBreak = d.object(forKey: "pomodorosBeforeLongBreak") as? Int ?? 4

        whiteNoiseEnabled   = d.object(forKey: "whiteNoiseEnabled") as? Bool ?? false
        whiteNoiseType     = d.object(forKey: "whiteNoiseType") as? String ?? "rain"
        whiteNoiseLayerType = d.object(forKey: "whiteNoiseLayerType") as? String ?? "none"
        breakSuggestionEnabled = d.object(forKey: "breakSuggestionEnabled") as? Bool ?? true
        whiteNoiseVolume   = d.object(forKey: "whiteNoiseVolume") as? Float ?? 0.5
        completionSoundEnabled = d.object(forKey: "completionSoundEnabled") as? Bool ?? true
        completionSoundType    = d.object(forKey: "completionSoundType") as? String ?? "bell"

        hapticsEnabled      = d.object(forKey: "hapticsEnabled") as? Bool ?? true
        notificationsEnabled = d.object(forKey: "notificationsEnabled") as? Bool ?? true

        appShieldEnabled    = d.object(forKey: "appShieldEnabled") as? Bool ?? false
        shieldedBundleIds   = d.object(forKey: "shieldedBundleIds") as? [String] ?? []

        autoStartBreaks     = d.object(forKey: "autoStartBreaks") as? Bool ?? false
        autoStartFocus      = d.object(forKey: "autoStartFocus") as? Bool ?? false
        flipClockStyle      = d.object(forKey: "flipClockStyle") as? String ?? "classic"
        themeColorHex       = d.object(forKey: "themeColorHex") as? String ?? "#FF4D4A"
        dailyGoalPomodoros  = d.object(forKey: "dailyGoalPomodoros") as? Int ?? 8
        keepScreenAwake     = d.object(forKey: "keepScreenAwake") as? Bool ?? true
        immersiveMode       = d.object(forKey: "immersiveMode") as? Bool ?? true
        appearanceMode      = d.object(forKey: "appearanceMode") as? String ?? "dark"

        // 保证 themeColorHex 在合法列表内（老版本默认值 #FF6B6B 不在列表）
        if !Self.themeColors.contains(where: { $0.hex == self.themeColorHex }) {
            self.themeColorHex = Self.themeColors[0].hex
        }
    }

    private func save() {
        defaults.set(focusDuration, forKey: "focusDuration")
        defaults.set(shortBreakDuration, forKey: "shortBreakDuration")
        defaults.set(longBreakDuration, forKey: "longBreakDuration")
        defaults.set(pomodorosBeforeLongBreak, forKey: "pomodorosBeforeLongBreak")
        defaults.set(whiteNoiseEnabled, forKey: "whiteNoiseEnabled")
        defaults.set(whiteNoiseType, forKey: "whiteNoiseType")
        defaults.set(whiteNoiseLayerType, forKey: "whiteNoiseLayerType")
        defaults.set(breakSuggestionEnabled, forKey: "breakSuggestionEnabled")
        defaults.set(whiteNoiseVolume, forKey: "whiteNoiseVolume")
        defaults.set(completionSoundEnabled, forKey: "completionSoundEnabled")
        defaults.set(completionSoundType, forKey: "completionSoundType")
        defaults.set(hapticsEnabled, forKey: "hapticsEnabled")
        defaults.set(notificationsEnabled, forKey: "notificationsEnabled")
        defaults.set(appShieldEnabled, forKey: "appShieldEnabled")
        defaults.set(shieldedBundleIds, forKey: "shieldedBundleIds")
        defaults.set(autoStartBreaks, forKey: "autoStartBreaks")
        defaults.set(autoStartFocus, forKey: "autoStartFocus")
        defaults.set(flipClockStyle, forKey: "flipClockStyle")
        defaults.set(themeColorHex, forKey: "themeColorHex")
        defaults.set(dailyGoalPomodoros, forKey: "dailyGoalPomodoros")
        defaults.set(keepScreenAwake, forKey: "keepScreenAwake")
        defaults.set(immersiveMode, forKey: "immersiveMode")
        defaults.set(appearanceMode, forKey: "appearanceMode")
    }

    // MARK: - Presets

    /// Available focus accent colors (hex). The first is the default.
    public static let themeColors: [(name: String, hex: String)] = [
        ("红", "#FF4D4A"),
        ("橙", "#FF9F0A"),
        ("绿", "#32D74B"),
        ("蓝", "#0A84FF"),
        ("紫", "#BF5AF2"),
        ("粉", "#FF2D55"),
    ]

    public enum Preset: String, CaseIterable {
        case classic    = "经典 25/5/15"
        case long       = "深度 50/10/30"
        case short      = "极速 15/3/10"
        case ninety     = "90分钟深度"

        // 结构化数值（供设置页判断当前激活的预设）
        public var focus: Int {
            switch self {
            case .classic: return 25*60
            case .long: return 50*60
            case .short: return 15*60
            case .ninety: return 90*60
            }
        }
        public var short: Int {
            switch self {
            case .classic: return 5*60
            case .long: return 10*60
            case .short: return 3*60
            case .ninety: return 20*60
            }
        }
        public var long: Int {
            switch self {
            case .classic: return 15*60
            case .long: return 30*60
            case .short: return 10*60
            case .ninety: return 30*60
            }
        }
        public var longEvery: Int {
            switch self {
            case .classic: return 4
            case .long: return 3
            case .short: return 4
            case .ninety: return 2
            }
        }

        public func apply(to s: AppSettings) {
            s.focusDuration = focus
            s.shortBreakDuration = short
            s.longBreakDuration = long
            s.pomodorosBeforeLongBreak = longEvery
        }
    }
}
