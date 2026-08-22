import Foundation
import Combine

// MARK: - 阶段与状态

enum Phase: String, Equatable {
    case focus, shortBreak, longBreak

    var label: String {
        switch self {
        case .focus: return "专注中"
        case .shortBreak: return "小憩"
        case .longBreak: return "长歇"
        }
    }
}

/// prepared = 屏幕展示该阶段的开始页（Flow 式阶段切换）
enum EngineState: Equatable {
    case idle
    case running(Phase)
    case paused(Phase)
    case prepared(Phase)
}

// MARK: - 引擎（墙钟派生，后台不漂移）

struct PhaseCompletion: Equatable {
    let id = UUID()
    let minutes: Int
    let wasFocus: Bool
    let nextPrepared: Bool   // true=下一阶段待启动(false=已自动开跑)
}

final class FocusEngine: ObservableObject {

    static let shared = FocusEngine()

    /// 最近一次阶段自然完成（供结算卡展示）
    @Published var lastCompletion: PhaseCompletion?

    @Published private(set) var state: EngineState = .idle
    @Published private(set) var remainingSeconds: Int = 0
    @Published private(set) var totalSeconds: Int = 0
    @Published private(set) var todayPomodoros: Int = 0

    /// 当前关联任务（颜色驱动整个界面）
    @Published var currentTaskID: UUID? {
        didSet { refreshTaskColor() }
    }
    @Published private(set) var currentTaskName: String = ""
    @Published private(set) var currentTaskColorHex: String = ""

    // 墙钟
    private var startedAt: Date?
    private var cancellables = Set<AnyCancellable>()

    private let prefs = Prefs.shared
    private let keepAlive = KeepAlive()

    var phase: Phase? {
        switch state {
        case .running(let p), .paused(let p), .prepared(let p): return p
        case .idle: return nil
        }
    }

    var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    var isPaused: Bool {
        if case .paused = state { return true }
        return false
    }

    /// 界面规划态：可改下一次时长 / 显示 chips
    var isPlanning: Bool {
        switch state {
        case .idle, .prepared(.focus): return true
        default: return false
        }
    }

    private static let pk = "eng.snapshot.v1"

    private init() {
        KeepAlive.tickPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.handleTick() }
            .store(in: &cancellables)
        refreshToday()
        restoreState()
        if currentTaskID == nil {
            if let first = Store.shared.tasks().first { currentTaskID = first.id }
            else { refreshTaskColor() }
        }
    }

    // MARK: 杀后台恢复（墙钟补偿）

    private func saveState() {
        let key: String
        switch state {
        case .running: key = "running"
        case .paused: key = "paused"
        case .prepared: key = "prepared"
        case .idle: key = "idle"
        }
        UserDefaults.standard.set([
            "state": key,
            "phase": phase?.rawValue ?? "",
            "total": totalSeconds,
            "remain": remainingSeconds,
            "startedAt": startedAt?.timeIntervalSince1970 ?? 0,
            "taskID": currentTaskID?.uuidString ?? ""
        ] as [String: Any], forKey: Self.pk)
    }

    private func restoreState() {
        guard let d = UserDefaults.standard.dictionary(forKey: Self.pk),
              let ph = Phase(rawValue: d["phase"] as? String ?? "") else { return }
        totalSeconds = d["total"] as? Int ?? 0
        remainingSeconds = d["remain"] as? Int ?? 0
        if let s = d["taskID"] as? String, let u = UUID(uuidString: s) {
            currentTaskID = u; refreshTaskColor()
        }
        switch d["state"] as? String {
        case "running":
            let ts = d["startedAt"] as? Double ?? Date().timeIntervalSince1970
            startedAt = Date(timeIntervalSince1970: ts)
            state = .running(ph)
            if remaining() <= 0 {
                remainingSeconds = 0
                finishCurrent(completed: true)
                advanceToNext(afterCompleted: true)      // 死亡期间走完 → 结算推进
            } else {
                remainingSeconds = remaining()
                keepAlive.start()
                if prefs.soundAutoPlay && prefs.soundType != "none" {
                    SoundPlayer.shared.startAmbient(type: prefs.soundType,
                                                    volume: prefs.soundVolume)
                }
                Notifications.schedule(in: remainingSeconds, phase: ph,
                                       taskName: currentTaskName.isEmpty ? nil : currentTaskName)
            }
        case "paused":
            state = .paused(ph)
        case "prepared":
            startedAt = nil
            state = .prepared(ph)
        default:
            goIdle()
        }
    }

    // MARK: 剩余时间（唯一真相源）

    func remaining(at date: Date = Date()) -> Int {
        guard let start = startedAt else { return remainingSeconds }
        return max(0, totalSeconds - Int(date.timeIntervalSince(start)))
    }

    private func handleTick() {
        guard isRunning else { return }
        remainingSeconds = remaining()
        if remainingSeconds <= 0 { completePhase() }
    }

    // MARK: 动作

    func startFocus() {
        begin(phase: .focus, seconds: prefs.focusMinutes * 60)
    }

    func startPreparedPhase() {
        guard case .prepared(let p) = state else { return }
        let seconds: Int
        switch p {
        case .focus: seconds = prefs.focusMinutes * 60
        case .shortBreak: seconds = prefs.shortMinutes * 60
        case .longBreak: seconds = prefs.longMinutes * 60
        }
        begin(phase: p, seconds: seconds)
    }

    private func begin(phase: Phase, seconds: Int) {
        totalSeconds = seconds
        remainingSeconds = seconds
        startedAt = Date()
        state = .running(phase)
        keepAlive.start()
        if prefs.soundAutoPlay && prefs.soundType != "none" {
            SoundPlayer.shared.startAmbient(type: prefs.soundType, volume: prefs.soundVolume)
        }
        Notifications.schedule(in: seconds, phase: phase,
                               taskName: currentTaskName.isEmpty ? nil : currentTaskName)
        saveState()
    }

    func pause() {
        guard isRunning, let p = phase else { return }
        remainingSeconds = remaining()
        startedAt = nil
        state = .paused(p)
        keepAlive.stop()
        Notifications.cancelAll()
        saveState()
    }

    func resume() {
        guard isPaused, let p = phase else { return }
        startedAt = Date()
        totalSeconds = remainingSeconds          // 从冻结值继续
        state = .running(p)
        keepAlive.start()
        Notifications.schedule(in: remainingSeconds, phase: p,
                               taskName: currentTaskName.isEmpty ? nil : currentTaskName)
        saveState()
    }

    func togglePause() { isRunning ? pause() : resume() }

    /// 跳过当前阶段（专注未完成则记录为中断）
    func skip() {
        finishCurrent(completed: false)
        advanceToNext(afterCompleted: false)
    }

    /// 放弃整次专注，回到空闲
    func giveUp() {
        finishCurrent(completed: false)
        goIdle()
    }

    private func completePhase() {
        let mins = max(1, totalSeconds / 60)
        let wasFocus = phase == .focus
        finishCurrent(completed: true)
        SoundPlayer.shared.playTone(Prefs.shared.toneType)
        advanceToNext(afterCompleted: true)

        var preparedNext = false
        if case .prepared = state { preparedNext = true }
        lastCompletion = PhaseCompletion(minutes: mins,
                                         wasFocus: wasFocus,
                                         nextPrepared: preparedNext)
    }

    private func finishCurrent(completed: Bool) {
        keepAlive.stop()
        SoundPlayer.shared.stopAmbient()
        Notifications.cancelAll()
        let elapsed = min(totalSeconds, max(0, totalSeconds - remaining()))
        guard let p = phase, elapsed > 0 else { return }
        Store.shared.record(phase: p, seconds: elapsed,
                            start: Date().addingTimeInterval(TimeInterval(-elapsed)),
                            completed: completed,
                            taskId: p == .focus ? currentTaskID : nil)
        if p == .focus && completed { refreshToday() }
    }

    private func advanceToNext(afterCompleted completed: Bool) {
        guard let prev = phase else { goIdle(); return }

        if prev == .focus {
            // 完成的番茄已在 finishCurrent 中刷新进 todayPomodoros
            let done = todayPomodoros
            let isLong = done > 0 && done % prefs.longEvery == 0
            let next: Phase = isLong ? .longBreak : .shortBreak
            prepare(next, autoStart: prefs.autoStartBreaks && completed)
        } else {
            prepare(.focus, autoStart: prefs.autoStartFocus && completed)
        }
    }

    private func prepare(_ p: Phase, autoStart: Bool) {
        let seconds: Int
        switch p {
        case .focus: seconds = prefs.focusMinutes * 60
        case .shortBreak: seconds = prefs.shortMinutes * 60
        case .longBreak: seconds = prefs.longMinutes * 60
        }
        totalSeconds = seconds
        remainingSeconds = seconds
        startedAt = nil
        state = .prepared(p)
        saveState()
        if autoStart { startPreparedPhase() }
    }

    private func goIdle() {
        state = .idle
        totalSeconds = 0
        remainingSeconds = 0
        startedAt = nil
        saveState()
    }

    // MARK: 任务联动

    func select(taskID: UUID?) {
        currentTaskID = taskID
    }

    private func refreshTaskColor() {
        guard let t = Store.shared.task(id: currentTaskID) else {
            currentTaskName = ""
            currentTaskColorHex = ""
            return
        }
        currentTaskName = t.name
        currentTaskColorHex = t.colorHex
    }

    func refreshToday() {
        todayPomodoros = Store.shared.todayFocusCount()
    }
}
