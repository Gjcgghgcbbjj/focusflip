import Foundation
import ActivityKit

/// Live Activity attributes for pomodoro timer display on lock screen / Dynamic Island.
/// Available iOS 16.1+. On earlier versions, the app silently skips Live Activity.
@available(iOS 16.2, *)
public struct PomodoroActivityAttributes: ActivityAttributes {

    public typealias ContentState = PomodoroState

    public struct PomodoroState: Codable, Hashable {
        public var remainingSeconds: Int
        public var totalSeconds: Int
        public var sessionType: String        // "focus" | "shortBreak" | "longBreak"
        public var completedPomodoros: Int
        public var currentCycle: Int
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

    // MARK: - Public API

    public func startActivity(
        remaining: Int,
        total: Int,
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
            remainingSeconds: remaining,
            totalSeconds: total,
            sessionType: type.rawValue,
            completedPomodoros: completed,
            currentCycle: cycle
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
        type: SessionType,
        completed: Int,
        cycle: Int
    ) {
        guard let activity = currentActivity else { return }

        let state = PomodoroActivityAttributes.PomodoroState(
            remainingSeconds: remaining,
            totalSeconds: total,
            sessionType: type.rawValue,
            completedPomodoros: completed,
            currentCycle: cycle
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
