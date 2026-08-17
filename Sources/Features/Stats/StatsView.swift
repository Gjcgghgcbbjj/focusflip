import SwiftUI
import Charts

/// Statistics screen with clean card layout and consistent palette.
/// Requires iOS 16.0+ for Charts framework.
@available(iOS 16.0, *)
struct StatsView: View {

    enum StatsRange: String, CaseIterable, Identifiable {
        case day = "日"
        case week = "周"
        case month = "月"
        var id: String { rawValue }
    }

    @State private var range: StatsRange = .week

    @State private var todaySessions: [FocusSession] = []
    @State private var rangeData: [DayStat] = []
    @State private var rangeFocusSeconds: Int = 0
    @State private var rangePomodoros: Int = 0
    @State private var totalFocusSeconds: Int = 0
    @State private var totalPomodoros: Int = 0
    @State private var currentStreak: Int = 0
    @State private var heatmapData: [HeatDay] = []

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DS.S.md) {
                    rangePicker
                    todayCard
                    chartCard
                    heatmapCard
                    statsGrid
                    breakdownCard
                }
                .padding(.horizontal, DS.S.md)
                .padding(.bottom, DS.S.xxxl)
            }
            .background(DS.Color.bgPrimary.ignoresSafeArea())
            .navigationTitle("统计")
        }
                .onAppear { loadData() }
        .onChange(of: range) { _ in loadData() }
    }

    // MARK: - Range picker

    private var rangePicker: some View {
        Picker("范围", selection: $range) {
            ForEach(StatsRange.allCases) { r in
                Text(r.rawValue).tag(r)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, DS.S.sm)
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

    // MARK: - Range chart

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: DS.S.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(chartTitle)
                    .font(DS.Font.captionBold)
                    .foregroundColor(DS.Color.textSecondary)
                Spacer()
                Text("\(rangePomodoros) 番茄 · \(DateUtils.hoursMinutes(from: rangeFocusSeconds))")
                    .font(DS.Font.micro)
                    .foregroundColor(DS.Color.textMuted)
            }

            Chart(rangeData) { stat in
                BarMark(
                    x: .value("标签", stat.label),
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
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4))
            }
            .chartXAxis {
                AxisMarks(values: .automatic)
            }
            .frame(height: 160)
        }
        .card()
        .background(
            RoundedRectangle(cornerRadius: DS.R.lg)
                .fill(DS.Color.bgSecondary)
        )
    }

    private var chartTitle: String {
        switch range {
        case .day:   return "今日每时段"
        case .week:  return "近 7 天"
        case .month: return "近 30 天"
        }
    }

    // MARK: - Month heatmap

    private var heatmapCard: some View {
        VStack(alignment: .leading, spacing: DS.S.md) {
            Text("本月热力图")
                .font(DS.Font.captionBold)
                .foregroundColor(DS.Color.textSecondary)

            // Weekday header
            HStack(spacing: 4) {
                ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { day in
                    Text(day)
                        .font(DS.Font.micro)
                        .foregroundColor(DS.Color.textMuted)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7),
                      spacing: 4) {
                ForEach(heatmapData) { day in
                    if day.isPlaceholder {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.clear)
                            .frame(height: 26)
                    } else {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(heatColor(day.pomodoros))
                            .frame(height: 26)
                            .overlay(
                                Text("\(day.dayNumber)")
                                    .font(.system(size: 9))
                                    .foregroundColor(day.pomodoros > 0 ? .white : DS.Color.textMuted)
                            )
                    }
                }
            }
        }
        .card()
        .background(
            RoundedRectangle(cornerRadius: DS.R.lg)
                .fill(DS.Color.bgSecondary)
        )
    }

    private func heatColor(_ pomodoros: Int) -> SwiftUI.Color {
        switch pomodoros {
        case 0:   return DS.Color.textPrimary.opacity(0.06)
        case 1:   return DS.Color.focus.opacity(0.25)
        case 2:   return DS.Color.focus.opacity(0.5)
        default:  return DS.Color.focus
        }
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
            statTile(icon: "calendar", title: "本月",
                     value: DateUtils.hoursMinutes(from: monthFocusSeconds),
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

    private var monthFocusSeconds: Int {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: Date()))!
        let sessions = PersistenceController.shared.fetchAllSessions()
            .filter { $0.startDate >= start && $0.sessionType == .focus }
        return sessions.reduce(0) { $0 + Int($1.durationSeconds) }
    }

    private func loadData() {
        todaySessions = PersistenceController.shared.fetchSessions(for: Date())

        switch range {
        case .day:
            rangeData = hourlyBars(for: Date())
            let todayFocus = todaySessions.filter { $0.sessionType == .focus }
            rangePomodoros = todayFocus.count
            rangeFocusSeconds = todayFocus.reduce(0) { $0 + Int($1.durationSeconds) }

        case .week:
            rangeData = DateUtils.last7Days().map { date in
                let sessions = PersistenceController.shared.fetchSessions(for: date)
                let minutes = sessions.filter { $0.sessionType == .focus }
                    .reduce(0) { $0 + Int($1.durationSeconds) } / 60
                return DayStat(date: date, label: DateUtils.weekdayLabel(date), focusMinutes: minutes)
            }
            let cal = Calendar.current
            let weekStart = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: Date()))!
            let all = PersistenceController.shared.fetchAllSessions()
                .filter { $0.startDate >= weekStart && $0.sessionType == .focus }
            rangePomodoros = all.count
            rangeFocusSeconds = all.reduce(0) { $0 + Int($1.durationSeconds) }

        case .month:
            rangeData = DateUtils.lastNDays(30).map { date in
                let sessions = PersistenceController.shared.fetchSessions(for: date)
                let minutes = sessions.filter { $0.sessionType == .focus }
                    .reduce(0) { $0 + Int($1.durationSeconds) } / 60
                return DayStat(date: date, label: String(Calendar.current.component(.day, from: date)),
                               focusMinutes: minutes)
            }
            let cal = Calendar.current
            let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: Date()))!
            let all = PersistenceController.shared.fetchAllSessions()
                .filter { $0.startDate >= monthStart && $0.sessionType == .focus }
            rangePomodoros = all.count
            rangeFocusSeconds = all.reduce(0) { $0 + Int($1.durationSeconds) }
        }

        heatmapData = buildHeatmap()
        let all = PersistenceController.shared.fetchAllSessions()
        totalFocusSeconds = all.filter { $0.sessionType == .focus }
            .reduce(0) { $0 + Int($1.durationSeconds) }
        totalPomodoros = all.filter { $0.sessionType == .focus }.count
        currentStreak = calculateStreak()
    }

    /// 24 hourly bars for today's focus minutes.
    private func hourlyBars(for date: Date) -> [DayStat] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let sessions = PersistenceController.shared.fetchSessions(for: date)
            .filter { $0.sessionType == .focus }

        return (0..<24).map { hour in
            let hourStart = cal.date(byAdding: .hour, value: hour, to: start)!
            let hourEnd = cal.date(byAdding: .hour, value: 1, to: hourStart)!
            let minutes = sessions
                .filter { $0.startDate >= hourStart && $0.startDate < hourEnd }
                .reduce(0) { $0 + Int($1.durationSeconds) } / 60
            return DayStat(date: hourStart, label: "\(hour)时", focusMinutes: minutes)
        }
    }

    private func buildHeatmap() -> [HeatDay] {
        let cal = Calendar.current
        let now = Date()
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now))!
        let monthRange = cal.range(of: .day, in: .month, for: now)!
        let daysInMonth = monthRange.count

        // Leading offset: weekday of monthStart (1=Sun ... 7=Sat)
        let leading = cal.component(.weekday, from: monthStart) - 1

        // Day-of-month → pomodoro count
        let sessions = PersistenceController.shared.fetchAllSessions()
            .filter { $0.sessionType == .focus && $0.startDate >= monthStart }
        var counts: [Int: Int] = [:]
        for s in sessions {
            let day = cal.component(.day, from: s.startDate)
            counts[day, default: 0] += 1
        }

        var cells: [HeatDay] = []
        // Leading empty cells (from previous month)
        for _ in 0..<leading {
            cells.append(HeatDay(dayNumber: -1, pomodoros: 0, isPlaceholder: true))
        }
        for day in 1...daysInMonth {
            cells.append(HeatDay(dayNumber: day, pomodoros: counts[day] ?? 0, isPlaceholder: false))
        }
        return cells
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

// MARK: - Data models

private struct DayStat: Identifiable {
    let id = UUID()
    let date: Date
    let label: String
    let focusMinutes: Int
}

private struct HeatDay: Identifiable {
    let id = UUID()
    let dayNumber: Int
    let pomodoros: Int
    let isPlaceholder: Bool
}
