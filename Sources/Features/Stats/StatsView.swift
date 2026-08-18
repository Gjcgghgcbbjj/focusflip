import SwiftUI
import Charts

/// Statistics screen — Be Focused style data dashboard.
///
/// 对标 Be Focused / Focus Keeper：
/// - 今日大卡（专注时长 + 番茄数 + 连续天数）
/// - 日/周/月范围切换
/// - 柱状图（日=24h / 周=7天 / 月=30天）
/// - 月日历热力图（GitHub 式色块）
/// - 总览网格（累计/总番茄/本月/连续天数）
/// - 会话分布比例条
@available(iOS 16.0, *)
struct StatsView: View {

    enum StatsRange: String, CaseIterable, Identifiable {
        case day = "日"
        case week = "周"
        case month = "月"
        var id: String { rawValue }
    }

    @State private var range: StatsRange = .week

    // Cached data (loaded once in loadData, not on every render)
    @State private var todaySessions: [FocusSession] = []
    @State private var rangeData: [DayStat] = []
    @State private var rangeFocusSeconds: Int = 0
    @State private var rangePomodoros: Int = 0
    @State private var totalFocusSeconds: Int = 0
    @State private var totalPomodoros: Int = 0
    @State private var currentStreak: Int = 0
    @State private var bestStreak: Int = 0
    @State private var heatmapData: [HeatDay] = []
    @State private var sessionBreakdown: (focus: Int, shortBreak: Int, longBreak: Int) = (0, 0, 0)
    @State private var monthFocusSecondsCache: Int = 0
    @State private var monthPomodorosCache: Int = 0

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
    }

    // MARK: - Today card

    private var todayCard: some View {
        VStack(spacing: DS.S.sm) {
            Text("今日专注")
                .font(DS.Font.caption)
                .foregroundColor(DS.Color.textMuted)

            Text(DateUtils.hoursMinutes(from: todayFocusSeconds))
                .font(DS.Font.statLarge)
                .monospacedDigit()
                .foregroundColor(DS.Color.textPrimary)

            HStack(spacing: DS.S.xxxl) {
                miniStat(value: "\(todayPomodoros)", label: "番茄")
                miniStat(value: "\(currentStreak)", label: "连续天")
                miniStat(value: "\(bestStreak)", label: "最长记录")
            }
        }
        .frame(maxWidth: .infinity)
        .card()
    }

    private func miniStat(value: String, label: String) -> some View {
        VStack(spacing: DS.S.xxs) {
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(DS.Color.textPrimary)
            Text(label)
                .font(DS.Font.micro)
                .foregroundColor(DS.Color.textMuted)
        }
    }

    // MARK: - Chart card

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
                    .monospacedDigit()
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
                .cornerRadius(3)
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) {
                    AxisGridLine().foregroundStyle(DS.Color.separator)
                    AxisValueLabel().foregroundStyle(DS.Color.textMuted)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic) {
                    AxisValueLabel().foregroundStyle(DS.Color.textMuted)
                }
            }
            .frame(height: 160)
        }
        .card()
    }

    private var chartTitle: String {
        switch range {
        case .day:   return "今日每时段"
        case .week:  return "近 7 天"
        case .month: return "近 30 天"
        }
    }

    // MARK: - Heatmap

    private var heatmapCard: some View {
        VStack(alignment: .leading, spacing: DS.S.md) {
            HStack {
                Text("本月热力图")
                    .font(DS.Font.captionBold)
                    .foregroundColor(DS.Color.textSecondary)
                Spacer()
                Text("\(monthPomodorosCache) 番茄")
                    .font(DS.Font.micro)
                    .foregroundColor(DS.Color.textMuted)
                    .monospacedDigit()
            }

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
                            .frame(height: 28)
                    } else {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(DS.Color.heatLevel(day.pomodoros))
                            .frame(height: 28)
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
                     value: "\(totalPomodoros)", color: DS.Color.focus)
            statTile(icon: "calendar", title: "本月",
                     value: DateUtils.hoursMinutes(from: monthFocusSecondsCache),
                     color: DS.Color.shortBreak)
            statTile(icon: "flame.fill", title: "连续天数",
                     value: "\(currentStreak)", color: DS.Color.warning)
        }
    }

    private func statTile(icon: String, title: String, value: String, color: SwiftUI.Color) -> some View {
        HStack(spacing: DS.S.md) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(Circle().fill(color.opacity(0.12)))

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
    }

    // MARK: - Breakdown

    private var breakdownCard: some View {
        let total = max(1, sessionBreakdown.focus + sessionBreakdown.shortBreak + sessionBreakdown.longBreak)

        return VStack(alignment: .leading, spacing: DS.S.md) {
            Text("会话分布")
                .font(DS.Font.captionBold)
                .foregroundColor(DS.Color.textSecondary)

            HStack(spacing: DS.S.sm) {
                breakdownBar(type: .focus, count: sessionBreakdown.focus, total: total)
                breakdownBar(type: .shortBreak, count: sessionBreakdown.shortBreak, total: total)
                breakdownBar(type: .longBreak, count: sessionBreakdown.longBreak, total: total)
            }
        }
        .card()
    }

    private func breakdownBar(type: SessionType, count: Int, total: Int) -> some View {
        let theme = PhaseTheme.theme(for: type)
        let pct = Double(count) / Double(total)

        return VStack(spacing: DS.S.xxs) {
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

    // MARK: - Data loading

    private var todayFocusSeconds: Int {
        todaySessions.filter { $0.sessionType == .focus }
            .reduce(0) { $0 + Int($1.durationSeconds) }
    }

    private var todayPomodoros: Int {
        todaySessions.filter { $0.sessionType == .focus }.count
    }

    private var monthFocusSeconds: Int { monthFocusSecondsCache }
    private var monthPomodoros: Int { monthPomodorosCache }

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
        sessionBreakdown = (
            focus: all.filter { $0.sessionType == .focus }.count,
            shortBreak: all.filter { $0.sessionType == .shortBreak }.count,
            longBreak: all.filter { $0.sessionType == .longBreak }.count
        )
        currentStreak = calculateStreak()
        bestStreak = calculateBestStreak()

        // Cache month totals (avoid per-render fetchAllSessions in view body)
        let cal = Calendar.current
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: Date()))!
        let monthSessions = all.filter { $0.startDate >= monthStart && $0.sessionType == .focus }
        monthFocusSecondsCache = monthSessions.reduce(0) { $0 + Int($1.durationSeconds) }
        monthPomodorosCache = monthSessions.count
    }

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
            return DayStat(date: hourStart,
                          label: hour % 2 == 0 ? "\(hour)" : "",
                          focusMinutes: minutes)
        }
    }

    private func buildHeatmap() -> [HeatDay] {
        let cal = Calendar.current
        let now = Date()
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now))!
        let monthRange = cal.range(of: .day, in: .month, for: now)!
        let daysInMonth = monthRange.count

        let leading = cal.component(.weekday, from: monthStart) - 1

        let sessions = PersistenceController.shared.fetchAllSessions()
            .filter { $0.sessionType == .focus && $0.startDate >= monthStart }
        var counts: [Int: Int] = [:]
        for s in sessions {
            let day = cal.component(.day, from: s.startDate)
            counts[day, default: 0] += 1
        }

        var cells: [HeatDay] = []
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
