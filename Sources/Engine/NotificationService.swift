import Foundation
import UserNotifications

/// Schedules local notifications for phase completion.
/// On iOS 16.1+, Live Activity (in LiveActivityManager) is also used for in-progress display.
public final class NotificationService {

    public static let shared = NotificationService()

    private init() {}

    public func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                AppSettings.shared.notificationsEnabled = granted
            }
        }
    }

    public func schedulePhaseComplete(after seconds: Int, type: SessionType) {
        guard AppSettings.shared.notificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = type == .focus ? "专注完成 🎉" : "休息结束 ⏰"
        content.body = type == .focus
            ? "你完成了一个番茄钟，去休息一下吧！"
            : "休息结束，继续专注！"
        content.sound = .default
        content.categoryIdentifier = "PHASE_COMPLETE"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let request = UNNotificationRequest(identifier: "phase_\(UUID().uuidString)",
                                             content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    public func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
