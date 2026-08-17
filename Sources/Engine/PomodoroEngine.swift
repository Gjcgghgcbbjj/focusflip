import Foundation
import Combine

/// The pomodoro state machine: drives focus → shortBreak → focus → ... → longBreak cycles.
///
/// States:
///   .idle         — not running, waiting for user to start
///   .focusing     — in a focus session (counting down)
///   .paused       — focus paused by user
///   .shortBreak   — short break in progress
///   .longBreak    — long break in progress
///   .finished     — all planned cycles done
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
    }

    public func startBreak() {
        let isLongBreak = completedFocusCount > 0 &&
            completedFocusCount % settings.pomodorosBeforeLongBreak == 0

        totalSeconds = isLongBreak ? settings.longBreakDuration : settings.shortBreakDuration
        remainingSeconds = totalSeconds
        phaseStartDate = Date()
        state = isLongBreak ? .longBreak : .shortBreak
        timerService.start()
    }

    public func pause() {
        guard state == .focusing || state == .shortBreak || state == .longBreak else { return }
        state = .paused(state == .focusing ? .focusing :
                        state == .shortBreak ? .shortBreak : .longBreak)
        timerService.stop()
    }

    public func resume() {
        guard case .paused(let prev) = state else { return }
        // Adjust phase start to account for elapsed time
        let elapsed = totalSeconds - remainingSeconds
        phaseStartDate = Date().addingTimeInterval(TimeInterval(-elapsed))
        state = prev
        timerService.start()
    }

    public func skip() {
        timerService.stop()
        advancePhase()
    }

    public func reset() {
        timerService.stop()
        state = .idle
        remainingSeconds = 0
        totalSeconds = 0
        completedFocusCount = 0
        currentCycle = 1
        phaseStartDate = nil
    }

    // MARK: - Tick handling

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
        switch state {
        case .focusing:
            completedFocusCount += 1
            PersistenceController.shared.recordSession(
                type: .focus, duration: totalSeconds, taskId: currentTaskId)

            onPhaseComplete?(.focus)

            let isLongBreak = completedFocusCount % settings.pomodorosBeforeLongBreak == 0
            if settings.autoStartBreaks {
                startBreak()
            } else {
                state = isLongBreak ? .breakReady(.longBreak) : .breakReady(.shortBreak)
            }

        case .shortBreak, .longBreak:
            let type: SessionType = (state == .shortBreak ? .shortBreak : .longBreak)
            PersistenceController.shared.recordSession(type: type, duration: totalSeconds)
            onPhaseComplete?(type)

            if state == .longBreak {
                // After long break, cycle resets
                currentCycle += 1
            }

            if settings.autoStartFocus {
                startFocus()
            } else {
                state = .focusReady
            }

        default:
            break
        }
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
        return Double(remainingSeconds) - (elapsed - Double(totalSeconds - remainingSeconds))
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
    case finished
}
