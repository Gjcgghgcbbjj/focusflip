import SwiftUI
import WidgetKit
import ActivityKit

/// Live Activity widget for pomodoro timer on lock screen and Dynamic Island.
/// Shows remaining time, session type, and progress.
@available(iOS 16.2, *)
struct PomodoroLiveActivity: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PomodoroActivityAttributes.self) { context in
            // Lock screen Live Activity view
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Dynamic Island
                DynamicIslandExpandedRegion(.leading) {
                    VStack {
                        Image(systemName: sessionIcon(context.state.sessionType))
                            .font(.title2)
                            .foregroundColor(sessionColor(context.state.sessionType))
                        Text(sessionLabel(context.state.sessionType))
                            .font(.caption2)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack {
                        Text(formatTime(context.state.remainingSeconds))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("第 \(context.state.currentCycle) 轮")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let task = context.attributes.taskTitle {
                        Text("任务: \(task)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: sessionIcon(context.state.sessionType))
                    .foregroundColor(sessionColor(context.state.sessionType))
            } compactTrailing: {
                Text(formatTime(context.state.remainingSeconds))
                    .font(.caption.monospacedDigit())
            } minimal: {
                Text("\(context.state.remainingSeconds / 60)")
                    .font(.caption.monospacedDigit())
            }
        }
    }

    // MARK: - Helpers

    private func sessionIcon(_ type: String) -> String {
        switch type {
        case "focus":       return "brain.head.profile"
        case "shortBreak":  return "cup.and.saucer"
        case "longBreak":   return "leaf"
        default:            return "timer"
        }
    }

    private func sessionLabel(_ type: String) -> String {
        switch type {
        case "focus":       return "专注"
        case "shortBreak":  return "短休息"
        case "longBreak":   return "长休息"
        default:            return "计时"
        }
    }

    private func sessionColor(_ type: String) -> Color {
        switch type {
        case "focus":       return .red
        case "shortBreak":  return .green
        case "longBreak":   return .purple
        default:            return .blue
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Lock screen view

@available(iOS 16.2, *)
private struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<PomodoroActivityAttributes>

    var body: some View {
        HStack(spacing: 16) {
            // Left: icon + label
            VStack(spacing: 8) {
                Image(systemName: sessionIcon)
                    .font(.title)
                    .foregroundColor(sessionColor)
                Text(sessionLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 60)

            // Center: timer + progress
            VStack(spacing: 6) {
                Text(formatTime(context.state.remainingSeconds))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()

                ProgressView(value: progress)
                    .tint(sessionColor)
                    .frame(width: 120)
            }

            // Right: cycle info
            VStack(spacing: 8) {
                Text("\(context.state.completedPomodoros)")
                    .font(.title2.bold())
                Text("番茄")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 60)
        }
        .padding()
        .widgetContainerBackground()
    }

    private var sessionIcon: String {
        switch context.state.sessionType {
        case "focus":       return "brain.head.profile"
        case "shortBreak":  return "cup.and.saucer"
        case "longBreak":   return "leaf"
        default:            return "timer"
        }
    }

    private var sessionLabel: String {
        switch context.state.sessionType {
        case "focus":       return "专注"
        case "shortBreak":  return "短休息"
        case "longBreak":   return "长休息"
        default:            return "计时"
        }
    }

    private var sessionColor: Color {
        switch context.state.sessionType {
        case "focus":       return .red
        case "shortBreak":  return .green
        case "longBreak":   return .purple
        default:            return .blue
        }
    }

    private var progress: Double {
        guard context.state.totalSeconds > 0 else { return 0 }
        return 1.0 - Double(context.state.remainingSeconds) / Double(context.state.totalSeconds)
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}
