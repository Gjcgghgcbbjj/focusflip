import SwiftUI

/// iOS 15 fallback statistics screen (no Charts framework).
/// Simple Capsule bars + totals, same data sources as StatsView.
struct StatsLegacyView: View {

    @State private var weekData: [(label: String, minutes: Int)] = []
    @State private var todaySessions: [FocusSession] = []
    @State private var totalFocusSeconds: Int = 0
    @State private var totalPomodoros: Int = 0
    @State private var currentStreak: Int = 0
    @State private var bestStreak: Int = 0

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DS.S.md) {
                    todayCard
                    weekCard
                    statsGrid
                }
                .padding(.horizontal, DS.S.md)
                .padding(.bottom, DS.S.xxxl)
            }
            .background(DS.Color.bgPrimary.ignoresSafeArea())
            .navigationTitle("统计")
        }
        .onAppear { loadData() }
    }

    // MARK: - Today

    private var todayCard: some View {
        VStack(spacing: DS.S.sm) {
            Text("今日专注")
                .font(DS.Font.caption)
                .foregroundColor(DS.Color.textMuted)
            Text(DateUtils.hoursMinutes(from: todayFocusSeconds))
                .font(.system(size: 44, weight: .ultraLight, design: .rounded))
                .monospacedDigit()
                .foregroundColor(DS.Color.textPrimary)
            HStack(spacing: DS.S.xl) {
                miniStat(value: "\(todayPomodoros)", label: "番茄")
                miniStat(value: "\(currentStreak)", label: "连续天")
                miniStat(value: "\(bestStreak)", label: "最长记录")
            }
        }
        .frame(maxWidth: .infinity)
        .card(padding: DS.S.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.R.lg)
                .fill(DS.Color.bgSecondary)
        )
    }

    private func miniStat(value: String, label: String) -> some View {
        VStack(spacing: DS.S.xs) {
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(DS.Color.textPrimary)
            Text(label)
                .font(DS.Font.micro)
                .foregroundColor(DS.Color.textMuted)
        }
    }

    // MARK: - Week bars (no Charts — plain Capsules)

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: DS.S.md) {
            Text("近 7 天")
                .font(DS.Font.captionBold)
                .foregroundColor(DS.Color.textSecondary)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(weekData.enumerated()), id: \.offset) { _, item in
                    VStack(spacing: 4) {
                        Text("\(item.minutes)")
                            .font(.system(size: 9))
                            .foregroundColor(DS.Color.textMuted)
                        GeometryReader { geo in
                            Capsule()
                                .fill(DS.Color.focus.opacity(0.15))
                                .overlay(
                                    Capsule()
                                        .fill(DS.Color.focus)
                                        .frame(height: barHeight(item.minutes, maxValue: maxWeekMinutes, in: geo.size.height))
                                        .frame(maxHeight: .infinity, alignment: .bottom)
                                )
                        }
                        .frame(height: 80)
                        Text(item.label)
                            .font(DS.Font.micro)
                            .foregroundColor(DS.Color.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .card()
        .background(
            RoundedRectangle(cornerRadius: DS.R.lg)
                .fill(DS.Color.bgSecondary)
        )
    }

    private var maxWeekMinutes: Int {
        max(1, weekData.map { $0.minutes }.max() ?? 1)
    }

    private func barHeight(_ minutes: Int, maxValue: Int, in totalHeight: CGFloat) -> CGFloat {
        let pct = CGFloat(minutes) / CGFloat(maxValue)
        return Swift.max(4, totalHeight * pct)
    }

    // MARK: - Totals

    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: DS.S.sm),
            GridItem(.flexible(), spacing: DS.S.sm)
        ], spacing: DS.S.sm) {
            statTile(icon: "clock", title: "累计专注",
                     value: DateUtils.hoursMinutes(from: totalFocusSeconds),
                     color: DS.Color.longBreak)
            statTile(icon: "circle.fill", title: "总番茄数",
                     value: "\(totalPomodoros)",
                     color: DS.Color.focus)
            statTile(icon: "flame.fill", title: "连续天数",
                     value: "\(currentStreak)",
                     color: DS.Color.warning)
        }
    }

    private func statTile(icon: String, title: String, value: String, color: SwiftUI.Color) -> some View {
        HStack(spacing: DS.S.md) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(
                    Circle().fill(color.opacity(0.12))
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(DS.Color.textPrimary)
                Text(title)
                    .font(DS.Font.micro)
                    .foregroundColor(DS.Color.textMuted)
            }
            Spacer()
        }
        .card(padding: DS.S.md)
        .background(
            RoundedRectangle(cornerRadius: DS.R.lg)
                .fill(DS.Color.bgSecondary)
        )
    }

    // MARK: - Data

    private var todayFocusSeconds: Int {
        todaySessions.filter { $0.sessionType == .focus }
            .reduce(0) { $0 + Int($1.durationSeconds) }
    }

    private var todayPomodoros: Int {
        todaySessions.filter { $0.sessionType == .focus }.count
    }

    private func loadData() {
        todaySessions = PersistenceController.shared.fetchSessions(for: Date())
        weekData = DateUtils.last7Days().map { date in
            let sessions = PersistenceController.shared.fetchSessions(for: date)
            let minutes = sessions.filter { $0.sessionType == .focus }
                .reduce(0) { $0 + Int($1.durationSeconds) } / 60
            return (DateUtils.weekdayLabel(date), minutes)
        }
        let all = PersistenceController.shared.fetchAllSessions()
        totalFocusSeconds = all.filter { $0.sessionType == .focus }
            .reduce(0) { $0 + Int($1.durationSeconds) }
        totalPomodoros = all.filter { $0.sessionType == .focus }.count
        currentStreak = calculateStreak()
        bestStreak = calculateBestStreak()
    }

    private func calculateStreak() -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let todayHasFocus = PersistenceController.shared
            .fetchSessions(for: today)
            .contains { $0.sessionType == .focus }

        var streak = 0
        var date = todayHasFocus ? today : cal.date(byAdding: .day, value: -1, to: today)!
        while true {
            let sessions = PersistenceController.shared.fetchSessions(for: date)
            if sessions.contains(where: { $0.sessionType == .focus }) {
                streak += 1
                date = cal.date(byAdding: .day, value: -1, to: date)!
            } else {
                break
            }
        }
        return streak
    }

    private func calculateBestStreak() -> Int {
        let all = PersistenceController.shared.fetchAllSessions()
            .filter { $0.sessionType == .focus }
            .sorted { $0.startDate < $1.startDate }

        guard !all.isEmpty else { return 0 }
        let cal = Calendar.current
        var best = 1
        var current = 1
        var prevDate = cal.startOfDay(for: all[0].startDate)

        for session in all.dropFirst() {
            let day = cal.startOfDay(for: session.startDate)
            let diff = cal.dateComponents([.day], from: prevDate, to: day).day ?? 0
            if diff == 1 {
                current += 1
                best = max(best, current)
            } else if diff > 1 {
                current = 1
            }
            prevDate = day
        }
        return best
    }
}
