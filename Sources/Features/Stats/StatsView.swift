import SwiftUI
import Charts

/// Statistics screen with clean card layout and consistent palette.
/// Requires iOS 16.0+ for Charts framework.
@available(iOS 16.0, *)
struct StatsView: View {

    @State private var todaySessions: [FocusSession] = []
    @State private var weekData: [DayStat] = []
    @State private var totalFocusSeconds: Int = 0
    @State private var totalPomodoros: Int = 0
    @State private var currentStreak: Int = 0

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DS.S.md) {
                    todayCard
                    weeklyChart
                    statsGrid
                    breakdownCard
                }
                .padding(.horizontal, DS.S.md)
                .padding(.bottom, DS.S.xxxl)
            }
            .background(DS.Color.bgPrimary.ignoresSafeArea())
            .navigationTitle("统计")
        }
        .preferredColorScheme(.dark)
        .onAppear { loadData() }
    }

    // MARK: - Today summary

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
                miniStat(value: "\(todayPomodoros)", label: "番茄", icon: "circle.fill")
                miniStat(value: "\(todaySessions.count)", label: "会话", icon: "list.bullet")
                miniStat(value: "\(currentStreak)", label: "连续天", icon: "flame")
            }
        }
        .frame(maxWidth: .infinity)
        .card(padding: DS.S.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.R.lg)
                .fill(DS.Color.bgSecondary)
        )
    }

    private func miniStat(value: String, label: String, icon: String) -> some View {
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

    // MARK: - Weekly chart

    private var weeklyChart: some View {
        VStack(alignment: .leading, spacing: DS.S.sm) {
            Text("近 7 天")
                .font(DS.Font.captionBold)
                .foregroundColor(DS.Color.textSecondary)

            Chart(weekData) { stat in
                BarMark(
                    x: .value("星期", stat.label),
                    y: .value("分钟", stat.focusMinutes)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [DS.Color.focus.opacity(0.8), DS.Color.focus.opacity(0.3)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    GridLine().foregroundStyle(DS.Color.textPrimary.opacity(0.05))
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    GridLine().foregroundStyle(.clear)
                    AxisValueText()
                        .foregroundColor(DS.Color.textMuted)
                }
            }
            .frame(height: 160)
        }
        .card()
        .background(
            RoundedRectangle(cornerRadius: DS.R.lg)
                .fill(DS.Color.bgSecondary)
        )
    }

    // MARK: - Stats grid

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
            statTile(icon: "calendar", title: "本周",
                     value: DateUtils.hoursMinutes(from: weekFocusSeconds),
                 color: DS.Color.shortBreak)
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

    // MARK: - Breakdown

    private var breakdownCard: some View {
        let allSessions = PersistenceController.shared.fetchAllSessions()
        let focus = allSessions.filter { $0.sessionType == .focus }.count
        let shortB = allSessions.filter { $0.sessionType == .shortBreak }.count
        let longB = allSessions.filter { $0.sessionType == .longBreak }.count
        let total = max(1, focus + shortB + longB)

        return VStack(alignment: .leading, spacing: DS.S.md) {
            Text("会话分布")
                .font(DS.Font.captionBold)
                .foregroundColor(DS.Color.textSecondary)

            HStack(spacing: DS.S.sm) {
                breakdownBar(type: .focus, count: focus, total: total)
                breakdownBar(type: .shortBreak, count: shortB, total: total)
                breakdownBar(type: .longBreak, count: longB, total: total)
            }
        }
        .card()
        .background(
            RoundedRectangle(cornerRadius: DS.R.lg)
                .fill(DS.Color.bgSecondary)
        )
    }

    private func breakdownBar(type: SessionType, count: Int, total: Int) -> some View {
        let theme = PhaseTheme.theme(for: type)
        let pct = Double(count) / Double(total)

        return VStack(spacing: DS.S.xs) {
            Text("\(count)")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(DS.Color.textPrimary)

            GeometryReader { geo in
                RoundedRectangle(cornerRadius: DS.R.sm)
                    .fill(theme.color.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.R.sm)
                            .fill(theme.color)
                            .frame(height: geo.size.height * pct)
                            .frame(maxHeight: .infinity, alignment: .bottom)
                    )
            }
            .frame(height: 80)

            Text(theme.label)
                .font(DS.Font.micro)
                .foregroundColor(DS.Color.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Data

    private var todayFocusSeconds: Int {
        todaySessions.filter { $0.sessionType == .focus }
            .reduce(0) { $0 + Int($1.durationSeconds) }
    }

    private var todayPomodoros: Int {
        todaySessions.filter { $0.sessionType == .focus }.count
    }

    private var weekFocusSeconds: Int {
        weekData.reduce(0) { $0 + $1.focusMinutes * 60 }
    }

    private func loadData() {
        todaySessions = PersistenceController.shared.fetchSessions(for: Date())
        weekData = DateUtils.last7Days().map { date in
            let sessions = PersistenceController.shared.fetchSessions(for: date)
            let minutes = sessions.filter { $0.sessionType == .focus }
                .reduce(0) { $0 + Int($1.durationSeconds) } / 60
            return DayStat(date: date, label: DateUtils.weekdayLabel(date), focusMinutes: minutes)
        }
        let all = PersistenceController.shared.fetchAllSessions()
        totalFocusSeconds = all.filter { $0.sessionType == .focus }
            .reduce(0) { $0 + Int($1.durationSeconds) }
        totalPomodoros = all.filter { $0.sessionType == .focus }.count
        currentStreak = calculateStreak()
    }

    private func calculateStreak() -> Int {
        let cal = Calendar.current
        var streak = 0
        var date = cal.startOfDay(for: Date())
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
}

private struct DayStat: Identifiable {
    let id = UUID()
    let date: Date
    let label: String
    let focusMinutes: Int
}
