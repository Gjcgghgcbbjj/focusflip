import Foundation

public struct DateUtils {

    /// Returns a short label like "25:00" from seconds.
    public static func formatTime(_ seconds: Int, showHours: Bool = false) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if showHours || h > 0 {
            return String(format: "%02d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    /// "今天" / "昨天" / "M月d日"
    public static func relativeDayLabel(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "今天" }
        if cal.isDateInYesterday(date) { return "昨天" }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "M月d日"
        return fmt.string(from: date)
    }

    /// Last 7 days labels for chart
    public static func last7Days() -> [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<7).reversed().map { cal.date(byAdding: .day, value: -$0, to: today)! }
    }

    /// Short weekday label: "一", "二", ...
    public static func weekdayLabel(_ date: Date) -> String {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: date)
        // Calendar.weekday: 1=Sunday, 2=Monday, ...
        let labels = ["日", "一", "二", "三", "四", "五", "六"]
        return labels[(weekday - 1) % 7]
    }

    public static func hoursMinutes(from seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 { return "\(h)小时\(m)分" }
        return "\(m)分钟"
    }
}
