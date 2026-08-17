import Foundation
import Combine

/// User-configurable settings, persisted via UserDefaults.
/// Observable so SwiftUI views react to changes.
public final class AppSettings: ObservableObject {

    public static let shared = AppSettings()

    // MARK: - Pomodoro durations (seconds)
    @Published public var focusDuration: Int     { didSet { save() } }
    @Published public var shortBreakDuration: Int { didSet { save() } }
    @Published public var longBreakDuration: Int  { didSet { save() } }
    @Published public var pomodorosBeforeLongBreak: Int { didSet { save() } }

    // MARK: - Sound
    @Published public var whiteNoiseEnabled: Bool  { didSet { save() } }
    @Published public var whiteNoiseType: String   { didSet { save() } }
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
        themeColorHex       = d.object(forKey: "themeColorHex") as? String ?? "#FF6B6B"
    }

    private func save() {
        defaults.set(focusDuration, forKey: "focusDuration")
        defaults.set(shortBreakDuration, forKey: "shortBreakDuration")
        defaults.set(longBreakDuration, forKey: "longBreakDuration")
        defaults.set(pomodorosBeforeLongBreak, forKey: "pomodorosBeforeLongBreak")
        defaults.set(whiteNoiseEnabled, forKey: "whiteNoiseEnabled")
        defaults.set(whiteNoiseType, forKey: "whiteNoiseType")
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
    }

    // MARK: - Presets

    public enum Preset: String, CaseIterable {
        case classic    = "经典 25/5/15"
        case long       = "深度 50/10/30"
        case short      = "极速 15/3/10"
        case ninety     = "90分钟深度"

        public func apply(to s: AppSettings) {
            switch self {
            case .classic: s.focusDuration = 25*60; s.shortBreakDuration = 5*60;  s.longBreakDuration = 15*60; s.pomodorosBeforeLongBreak = 4
            case .long:    s.focusDuration = 50*60; s.shortBreakDuration = 10*60; s.longBreakDuration = 30*60; s.pomodorosBeforeLongBreak = 3
            case .short:   s.focusDuration = 15*60; s.shortBreakDuration = 3*60;  s.longBreakDuration = 10*60; s.pomodorosBeforeLongBreak = 4
            case .ninety:  s.focusDuration = 90*60; s.shortBreakDuration = 20*60; s.longBreakDuration = 30*60; s.pomodorosBeforeLongBreak = 2
            }
        }
    }
}
