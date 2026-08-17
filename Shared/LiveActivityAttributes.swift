import Foundation
import ActivityKit

/// Live Activity attributes for pomodoro timer display on lock screen / Dynamic Island.
/// Available iOS 16.2+. On earlier versions, the app silently skips Live Activity.
///
/// The content state carries an absolute `phaseEndDate` so the widget extension
/// can render a self-ticking countdown with TimelineView — the app only pushes
/// updates on state changes (start / pause / resume / skip), not every second.
@available(iOS 16.2, *)
public struct PomodoroActivityAttributes: ActivityAttributes {

    public typealias ContentState = PomodoroState

    public struct PomodoroState: Codable, Hashable {
        /// When the current phase ends (nil when paused — show `remainingSeconds`).
        public var phaseEndDate: Date?
        /// Snapshot of remaining seconds (used when paused / as fallback).
        public var remainingSeconds: Int
        public var totalSeconds: Int
        public var sessionType: String        // "focus" | "shortBreak" | "longBreak"
        public var completedPomodoros: Int
        public var currentCycle: Int
        public var isPaused: Bool
    }

    public var taskTitle: String?

    public init(taskTitle: String? = nil) {
        self.taskTitle = taskTitle
    }
}

// MARK: - Live Activity Manager

@available(iOS 16.2, *)
public final class LiveActivityManager {

    public static let shared = LiveActivityManager()

    private var currentActivity: Activity<PomodoroActivityAttributes>?

    private init() {}

    /// Whether a Live Activity is currently presented.
    public var isActive: Bool { currentActivity != nil }

    // MARK: - Public API

    public func startActivity(
        remaining: Int,
        total: Int,
        endDate: Date?,
        type: SessionType,
        completed: Int,
        cycle: Int,
        taskTitle: String? = nil
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // End any existing activity
        endActivity()

        let attributes = PomodoroActivityAttributes(taskTitle: taskTitle)
        let state = PomodoroActivityAttributes.PomodoroState(
            phaseEndDate: endDate,
            remainingSeconds: remaining,
            totalSeconds: total,
            sessionType: type.rawValue,
            completedPomodoros: completed,
            currentCycle: cycle,
            isPaused: endDate == nil
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
        } catch {
            NSLog("[FocusFlip] Live Activity start error: \(error.localizedDescription)")
        }
    }

    public func updateActivity(
        remaining: Int,
        total: Int,
        endDate: Date?,
        type: SessionType,
        completed: Int,
        cycle: Int
    ) {
        guard let activity = currentActivity else { return }

        let state = PomodoroActivityAttributes.PomodoroState(
            phaseEndDate: endDate,
            remainingSeconds: remaining,
            totalSeconds: total,
            sessionType: type.rawValue,
            completedPomodoros: completed,
            currentCycle: cycle,
            isPaused: endDate == nil
        )

        Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    public func endActivity() {
        guard let activity = currentActivity else { return }

        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        currentActivity = nil
    }
}
