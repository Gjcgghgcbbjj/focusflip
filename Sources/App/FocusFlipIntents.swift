import Foundation
import AppIntents

// MARK: - Siri 快捷指令（iOS 16+）
//
// "嘿 Siri，开始专注" / 灵动岛外的一切入口。
// 全部 openAppWhenRun：执行时回到 App 前台。

@available(iOS 16.0, *)
struct StartFocusIntent: AppIntent {
    static let title: LocalizedStringResource = "开始专注"
    static let description = IntentDescription("开始一个专注番茄")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            PomodoroEngine.shared.startFocus()
            if AppSettings.shared.whiteNoiseEnabled {
                SoundPlayer.shared.playWhiteNoise()
            }
        }
        return .result()
    }
}

@available(iOS 16.0, *)
struct PauseFocusIntent: AppIntent {
    static let title: LocalizedStringResource = "暂停专注"
    static let description = IntentDescription("暂停当前计时")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await MainActor.run { PomodoroEngine.shared.pause() }
        return .result()
    }
}

@available(iOS 16.0, *)
struct ResumeFocusIntent: AppIntent {
    static let title: LocalizedStringResource = "继续专注"
    static let description = IntentDescription("继续被暂停的计时")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await MainActor.run { PomodoroEngine.shared.resume() }
        return .result()
    }
}

@available(iOS 16.0, *)
struct SkipPhaseIntent: AppIntent {
    static let title: LocalizedStringResource = "跳过当前阶段"
    static let description = IntentDescription("结束当前专注或休息，进入下一阶段")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await MainActor.run { PomodoroEngine.shared.skip() }
        return .result()
    }
}

@available(iOS 16.0, *)
struct FocusFlipShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartFocusIntent(),
                    phrases: ["\(.applicationName) 开始专注"],
                    shortTitle: "开始专注",
                    systemImageName: "timer")
        AppShortcut(intent: PauseFocusIntent(),
                    phrases: ["\(.applicationName) 暂停"],
                    shortTitle: "暂停",
                    systemImageName: "pause.fill")
        AppShortcut(intent: ResumeFocusIntent(),
                    phrases: ["\(.applicationName) 继续"],
                    shortTitle: "继续",
                    systemImageName: "play.fill")
        AppShortcut(intent: SkipPhaseIntent(),
                    phrases: ["\(.applicationName) 跳过"],
                    shortTitle: "跳过",
                    systemImageName: "forward.fill")
    }
}
