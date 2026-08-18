import Foundation
import Combine
#if canImport(WidgetKit)
import WidgetKit
#endif

/// The pomodoro state machine: drives focus → shortBreak → focus → ... → longBreak cycles.
///
/// States:
///   .idle         — not running, waiting for user to start
///   .focusing     — in a focus session (counting down)
///   .paused       — focus paused by user
///   .shortBreak   — short break in progress
///   .longBreak    — long break in progress
///   .finished     — daily goal reached (all planned pomodoros done)
public final class PomodoroEngine: ObservableObject {

    public static let shared = PomodoroEngine()

    // MARK: - Published state
    @Published public private(set) var state: EngineState = .idle
    @Published public private(set) var remainingSeconds: Int = 0
    @Published public private(set) var totalSeconds: Int = 0
    @Published public private(set) var completedFocusCount: Int = 0
    @Published public private(set) var currentCycle: Int = 1   // 1-indexed

    /// Timestamp when the current counting phase started (for sub-second progress).
    @Published public private(set) var phaseStartDate: Date?

    // MARK: - Today stats (snapshot, refreshed on phase transitions)
    @Published public private(set) var todayPomodoros: Int = 0
    @Published public private(set) var todayFocusSeconds: Int = 0

    // MARK: - Settings reference
    private let settings = AppSettings.shared

    // MARK: - Timer service
    private let timerService = TimerService.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Callbacks
    public var onPhaseComplete: ((SessionType) -> Void)?
    public var onAllComplete: (() -> Void)?

    // MARK: - Current task
    public var currentTaskId: UUID?

    private init() {
        // React to timer ticks
        timerService.$tick
            .sink { [weak self] _ in
                self?.handleTick()
            }
            .store(in: &cancellables)
    }

    // MARK: - Public API

    public func startFocus() {
        totalSeconds = settings.focusDuration
        remainingSeconds = totalSeconds
        phaseStartDate = Date()
        state = .focusing
        timerService.start()
        startLiveActivity()
        NotificationService.shared.schedulePhaseComplete(after: totalSeconds, type: .focus)
    }

    public func startBreak() {
        let isLongBreak = completedFocusCount > 0 &&
            completedFocusCount % settings.pomodorosBeforeLongBreak == 0

        totalSeconds = isLongBreak ? settings.longBreakDuration : settings.shortBreakDuration
        remainingSeconds = totalSeconds
        phaseStartDate = Date()
        state = isLongBreak ? .longBreak : .shortBreak
        timerService.start()
        startLiveActivity()
        let breakType: SessionType = isLongBreak ? .longBreak : .shortBreak
        NotificationService.shared.schedulePhaseComplete(after: totalSeconds, type: breakType)
    }

    public func pause() {
        guard state == .focusing || state == .shortBreak || state == .longBreak else { return }
        let sessionType: SessionType
        switch state {
        case .focusing:   sessionType = .focus
        case .shortBreak: sessionType = .shortBreak
        case .longBreak:  sessionType = .longBreak
        default:          return
        }
        state = .paused(sessionType)
        timerService.stop()
        updateLiveActivity(endDate: nil)
        NotificationService.shared.cancelAll()
    }

    public func resume() {
        guard case .paused(let prev) = state else { return }
        // Adjust phase start to account for elapsed time
        let elapsed = totalSeconds - remainingSeconds
        phaseStartDate = Date().addingTimeInterval(TimeInterval(-elapsed))
        switch prev {
        case .focus:       state = .focusing
        case .shortBreak:  state = .shortBreak
        case .longBreak:   state = .longBreak
        }
        timerService.start()
        updateLiveActivity(endDate: Date().addingTimeInterval(TimeInterval(remainingSeconds)))
        // Re-schedule the notification for the remaining time
        NotificationService.shared.schedulePhaseComplete(after: remainingSeconds, type: prev)
    }

    public func skip() {
        endLiveActivity()
        timerService.stop()
        NotificationService.shared.cancelAll()
        advancePhase()
    }

    public func reset() {
        endLiveActivity()
        timerService.stop()
        NotificationService.shared.cancelAll()
        state = .idle
        remainingSeconds = 0
        totalSeconds = 0
        completedFocusCount = 0
        currentCycle = 1
        phaseStartDate = nil
        refreshTodayStats()
    }

    /// Refresh the today snapshot from CoreData (call on appear & after phase changes).
    public func refreshTodayStats() {
        let sessions = PersistenceController.shared.fetchSessions(for: Date())
        let focus = sessions.filter { $0.sessionType == .focus }
        todayPomodoros = focus.count
        todayFocusSeconds = focus.reduce(0) { $0 + Int($1.durationSeconds) }
        // Tell the widget to refresh its timeline so the home screen stats update.
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    // MARK: - Tick handling

    /// Elapsed seconds in the current phase (for accurate partial-session recording).
    private var phaseElapsedSeconds: Int {
        guard let start = phaseStartDate else { return 0 }
        return min(totalSeconds, Int(Date().timeIntervalSince(start)))
    }

    private func handleTick() {
        guard state == .focusing || state == .shortBreak || state == .longBreak else { return }

        remainingSeconds = max(0, remainingSeconds - 1)

        if remainingSeconds <= 0 {
            timerService.stop()
            advancePhase()
        }
    }

    // MARK: - Phase transitions

    private func advancePhase() {
        // Record the ACTUAL elapsed time, not the full planned duration.
        // This matters when the user skips early — we don't want to inflate stats.
        let actualElapsed = phaseElapsedSeconds
        switch state {
        case .focusing:
            completedFocusCount += 1
            PersistenceController.shared.recordSession(
                type: .focus, duration: actualElapsed, taskId: currentTaskId)
            refreshTodayStats()

            onPhaseComplete?(.focus)

            // Daily goal reached → whole cycle finished
            if settings.dailyGoalPomodoros > 0 && todayPomodoros >= settings.dailyGoalPomodoros {
                state = .finished
                onAllComplete?()
                endLiveActivity()
                return
            }

            let isLongBreak = completedFocusCount % settings.pomodorosBeforeLongBreak == 0
            if settings.autoStartBreaks {
                startBreak()
            } else {
                state = isLongBreak ? .breakReady(.longBreak) : .breakReady(.shortBreak)
                endLiveActivity()
            }

        case .shortBreak, .longBreak:
            let type: SessionType = (state == .shortBreak ? .shortBreak : .longBreak)
            PersistenceController.shared.recordSession(type: type, duration: actualElapsed)
            onPhaseComplete?(type)

            if state == .longBreak {
                // After long break, cycle resets
                currentCycle += 1
            }

            if settings.autoStartFocus {
                startFocus()
            } else {
                state = .focusReady
                endLiveActivity()
            }

        default:
            break
        }
    }

    // MARK: - Live Activity

    private func startLiveActivity() {
        guard #available(iOS 16.2, *) else { return }
        LiveActivityManager.shared.startActivity(
            remaining: remainingSeconds,
            total: totalSeconds,
            endDate: Date().addingTimeInterval(TimeInterval(remainingSeconds)),
            type: currentSessionType,
            completed: completedFocusCount,
            cycle: currentCycle,
            taskTitle: currentTaskTitle
        )
    }

    private func updateLiveActivity(endDate: Date?) {
        guard #available(iOS 16.2, *) else { return }
        LiveActivityManager.shared.updateActivity(
            remaining: remainingSeconds,
            total: totalSeconds,
            endDate: endDate,
            type: currentSessionType,
            completed: completedFocusCount,
            cycle: currentCycle
        )
    }

    private func endLiveActivity() {
        guard #available(iOS 16.2, *) else { return }
        LiveActivityManager.shared.endActivity()
    }

    private var currentTaskTitle: String? {
        guard let id = currentTaskId else { return nil }
        return PersistenceController.shared.fetchTask(id: id)?.title
    }

    // MARK: - Computed helpers

    public var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1.0 - Double(remainingSeconds) / Double(totalSeconds)
    }

    /// Continuous progress (0.0–1.0) computed from real elapsed time.
    /// Use this in UI TimelineView for smooth ring animation.
    public func smoothProgress(at date: Date = Date()) -> Double {
        guard totalSeconds > 0, let start = phaseStartDate else { return progress }
        let elapsed = date.timeIntervalSince(start)
        let clamped = min(Double(totalSeconds), max(0, elapsed))
        return clamped / Double(totalSeconds)
    }

    /// Sub-second accurate remaining time as a Double, for smooth UI if needed.
    public func smoothRemainingSeconds(at date: Date = Date()) -> Double {
        guard let start = phaseStartDate else { return Double(remainingSeconds) }
        let elapsed = date.timeIntervalSince(start)
        return max(0, Double(totalSeconds) - elapsed)
    }

    /// 0.0–1.0 progress toward the daily pomodoro goal.
    public var dailyGoalProgress: Double {
        guard settings.dailyGoalPomodoros > 0 else { return 0 }
        return min(1.0, Double(todayPomodoros) / Double(settings.dailyGoalPomodoros))
    }

    public var currentSessionType: SessionType {
        switch state {
        case .focusing:           return .focus
        case .shortBreak:         return .shortBreak
        case .longBreak:          return .longBreak
        case .paused(let prev):   return prev
        case .breakReady(let t):  return t
        default:                  return .focus
        }
    }

    public var isRunning: Bool {
        state == .focusing || state == .shortBreak || state == .longBreak
    }
}

// MARK: - State enum

public enum EngineState: Equatable {
    case idle
    case focusing
    case paused(SessionType)
    case shortBreak
    case longBreak
    case breakReady(SessionType)   // waiting for user to start break
    case focusReady                // waiting for user to start next focus
    case finished                  // daily goal reached
}
