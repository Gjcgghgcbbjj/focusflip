import SwiftUI
import Charts

// MARK: - Stats entry (iOS 16 Charts / iOS 15 fallback)

struct StatsView3: View {
    var body: some View {
        if #available(iOS 16.0, *) {
            StatsModern3()
        } else {
            StatsFallback3()
        }
    }
}

// MARK: - Shared data model

@MainActor
final class StatsModel3: ObservableObject {
    @Published var todaySeconds = 0
    @Published var todayPomodoros = 0
    @Published var currentStreak = 0
    @Published var bestStreak = 0
    @Published var totalSeconds = 0
    @Published var totalPomodoros = 0
    @Published var monthSeconds = 0
    @Published var monthPomodoros = 0
    @Published var rangeBars: [Bar] = []
    @Published var rangePomodoros = 0
    @Published var rangeSeconds = 0
    @Published var heatmap: [HeatCell] = []
    @Published var breakdown = (focus: 0, short: 0, long: 0)
    @Published var taskStats: [TaskStat] = []
    @Published var yearWeeks: [[YearCell]] = []
    @Published var interruptReasons: [ReasonCount] = []

    struct Bar: Identifiable {
        let id = UUID()
        let label: String
        let minutes: Int
    }

    struct YearCell: Identifiable {
        let id = UUID()
        let day: Int            // pomodoro count
        let isFuture: Bool
        let isEmpty: Bool       // leading/trailing padding
    }

    struct ReasonCount: Identifiable {
        let id = UUID()
        let label: String
        let count: Int
    }

    struct TaskStat: Identifiable {
        let id = UUID()
        let name: String
        let colorHex: String
        let pomodoros: Int
        let seconds: Int
    }

    struct HeatCell: Identifiable {
        let id = UUID()
        let day: Int          // 1-based; -1 placeholder
        let pomodoros: Int
        var isPlaceholder: Bool { day < 0 }
    }

    enum Range: String, CaseIterable, Identifiable {
        case day = "日", week = "周", month = "月"
        var id: String { rawValue }
    }

    func load(range: Range) {
        let cal = Calendar.current
        let todaySessions = PersistenceController.shared.fetchSessions(for: Date())
        let todayFocus = todaySessions.filter { $0.sessionType == .focus }
        todaySeconds = todayFocus.reduce(0) { $0 + Int($1.durationSeconds) }
        todayPomodoros = todayFocus.count

        let all = PersistenceController.shared.fetchAllSessions()
        let focusAll = all.filter { $0.sessionType == .focus }
        totalSeconds = focusAll.reduce(0) { $0 + Int($1.durationSeconds) }
        totalPomodoros = focusAll.count

        breakdown = (
            focus: all.filter { $0.sessionType == .focus }.count,
            short: all.filter { $0.sessionType == .shortBreak }.count,
            long: all.filter { $0.sessionType == .longBreak }.count
        )

        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: Date()))!
        let monthFocus = focusAll.filter { $0.startDate >= monthStart }
        monthSeconds = monthFocus.reduce(0) { $0 + Int($1.durationSeconds) }
        monthPomodoros = monthFocus.count

        // 任务维度统计（按 taskId 聚合全部专注会话）
        var byId: [UUID: TaskItem] = [:]
        PersistenceController.shared.fetchTasks().forEach { byId[$0.id] = $0 }
        var acc: [UUID: (p: Int, s: Int)] = [:]
        focusAll.forEach { session in
            if let tid = session.taskId {
                let cur = acc[tid] ?? (0, 0)
                acc[tid] = (cur.p + 1, cur.s + Int(session.durationSeconds))
            }
        }
        taskStats = acc.compactMap { key, val -> TaskStat? in
            guard let t = byId[key] else { return nil }
            return TaskStat(name: t.title, colorHex: t.colorHex,
                            pomodoros: val.p, seconds: val.s)
        }
        .sorted { $0.seconds > $1.seconds }

        currentStreak = calcStreak()
        bestStreak = calcBestStreak(focusAll)
        heatmap = buildHeatmap()
        buildYearHeatmap(focusAll)
        buildInterruptReasons(focusAll)

        switch range {
        case .day:
            rangeBars = hourlyBars(todayFocus, cal: cal)
            rangePomodoros = todayPomodoros
            rangeSeconds = todaySeconds
        case .week:
            let days = DateUtils.last7Days()
            rangeBars = days.map { d in
                .init(label: DateUtils.weekdayLabel(d),
                      minutes: minutes(on: d, focusAll: focusAll))
            }
            summarize(focusAll, from: days.first!)
        case .month:
            let days = DateUtils.lastNDays(30)
            rangeBars = days.map { d in
                .init(label: String(cal.component(.day, from: d)),
                      minutes: minutes(on: d, focusAll: focusAll))
            }
            summarize(focusAll, from: days.first!)
        }
    }

    private func minutes(on day: Date, focusAll: [FocusSession]) -> Int {
        let start = Calendar.current.startOfDay(for: day)
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else { return 0 }
        return focusAll.filter { $0.startDate >= start && $0.startDate < end }
            .reduce(0) { $0 + Int($1.durationSeconds) } / 60
    }

    private func summarize(_ focusAll: [FocusSession], from start: Date) {
        let s = Calendar.current.startOfDay(for: start)
        let inRange = focusAll.filter { $0.startDate >= s }
        rangePomodoros = inRange.count
        rangeSeconds = inRange.reduce(0) { $0 + Int($1.durationSeconds) }
    }

    private func hourlyBars(_ sessions: [FocusSession], cal: Calendar) -> [Bar] {
        let start = cal.startOfDay(for: Date())
        return (0..<24).map { h in
            let hs = cal.date(byAdding: .hour, value: h, to: start)!
            let he = cal.date(byAdding: .hour, value: 1, to: hs)!
            let m = sessions.filter { $0.startDate >= hs && $0.startDate < he }
                .reduce(0) { $0 + Int($1.durationSeconds) } / 60
            return .init(label: "\(h)", minutes: m)
        }
    }

    private func buildHeatmap() -> [HeatCell] {
        let cal = Calendar.current
        let now = Date()
        guard let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)),
              let days = cal.range(of: .day, in: .month, for: now) else { return [] }
        let leading = (cal.component(.weekday, from: monthStart) + 5) % 7   // 周一开头
        let focusAll = PersistenceController.shared.fetchAllSessions()
            .filter { $0.sessionType == .focus && $0.startDate >= monthStart }
        var counts: [Int: Int] = [:]
        focusAll.forEach { counts[cal.component(.day, from: $0.startDate), default: 0] += 1 }

        var cells: [HeatCell] = Array(repeating: .init(day: -1, pomodoros: 0), count: leading)
        cells += (1...days.count).map { .init(day: $0, pomodoros: counts[$0] ?? 0) }
        return cells
    }

    private func buildYearHeatmap(_ focusAll: [FocusSession]) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        // 从 52 周前的周一开始
        guard let start = cal.date(byAdding: .weekOfYear, value: -52, to: today),
              let gridStart = cal.date(byAdding: .day,
                                       value: -((cal.component(.weekday, from: start) + 5) % 7),
                                       to: start) else { return }

        var counts: [Date: Int] = [:]
        for session in focusAll where session.startDate >= gridStart {
            counts[cal.startOfDay(for: session.startDate), default: 0] += 1
        }

        var weeks: [[YearCell]] = []
        var current: [YearCell] = []
        var day = gridStart
        while day <= today {
            current.append(YearCell(day: counts[day] ?? 0, isFuture: false, isEmpty: false))
            if current.count == 7 {
                weeks.append(current); current = []
            }
            day = cal.date(byAdding: .day, value: 1, to: day)!
        }
        if !current.isEmpty {
            while current.count < 7 {
                current.append(YearCell(day: 0, isFuture: true, isEmpty: true))
            }
            weeks.append(current)
        }
        yearWeeks = weeks
    }

    private func buildInterruptReasons(_ focusAll: [FocusSession]) {
        let req = focusAll.compactMap { $0.interruptReason }
        var dict: [String: Int] = [:]
        req.forEach { dict[$0, default: 0] += 1 }
        interruptReasons = dict
            .map { ReasonCount(label: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    private func calcStreak() -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let hasToday = PersistenceController.shared.fetchSessions(for: today)
            .contains { $0.sessionType == .focus }
        var streak = 0
        var date = hasToday ? today : cal.date(byAdding: .day, value: -1, to: today)!
        while PersistenceController.shared.fetchSessions(for: date)
            .contains(where: { $0.sessionType == .focus }) {
            streak += 1
            date = cal.date(byAdding: .day, value: -1, to: date)!
        }
        return streak
    }

    private func calcBestStreak(_ focusAll: [FocusSession]) -> Int {
        guard !focusAll.isEmpty else { return 0 }
        let cal = Calendar.current
        let days = Set(focusAll.map { cal.startOfDay(for: $0.startDate) })
            .sorted()
        var best = 1, cur = 1
        for i in 1..<days.count {
            if let diff = cal.dateComponents([.day], from: days[i-1], to: days[i]).day, diff == 1 {
                cur += 1; best = max(best, cur)
            } else {
                cur = 1
            }
        }
        return best
    }
}

// MARK: - Modern (iOS 16+, Charts)

@available(iOS 16.0, *)
private struct StatsModern3: View {
    @StateObject private var model = StatsModel3()
    @State private var range: StatsModel3.Range = .week
    @State private var showShareCard = false
    @State private var shareImage: UIImage?

    // MARK: 分享卡片渲染（iOS16 ImageRenderer / iOS15 hosting 回退）

    private func renderShareCard(_ m: StatsModel3) -> UIImage? {
        // StatsModern3 整体已 iOS16 门控，直接用 ImageRenderer
        let renderer = ImageRenderer(content: ShareCardView3(model: m))
        renderer.scale = 3
        return renderer.uiImage
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DS3.S.md) {
                    picker
                    heroCard
                    chartCard
                    heatCard
                    grid
                    if !model.taskStats.isEmpty { taskDistribution(model) }
                    breakdownCard
                    yearHeatmapCard
                    if !model.interruptReasons.isEmpty { interruptCard }
                }
                .padding(.horizontal, DS3.S.md)
                .padding(.bottom, DS3.S.xxl)
            }
            .hideScrollBackground3()
            .background(DS3.Color.bg.ignoresSafeArea())
            .navigationTitle("统计")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        shareImage = renderShareCard(model)
                        showShareCard = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(DS3.Color.textDim)
                    }
                }
            }
        }
        .sheet(isPresented: $showShareCard) {
            if let img = shareImage { ShareSheet(items: [img]) }
        }
        .onAppear { model.load(range: range) }
        .onChange(of: range) { model.load(range: $0) }
    }

    private var picker: some View {
        Picker("范围", selection: $range) {
            ForEach(StatsModel3.Range.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .tint(DS3.Color.accent)
    }

    private var heroCard: some View {
        VStack(spacing: DS3.S.sm) {
            Text("今日专注")
                .font(DS3.Font.caption)
                .foregroundColor(DS3.Color.textDim)
            Text(DateUtils.hoursMinutes(from: model.todaySeconds))
                .font(.system(size: 44, weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundColor(DS3.Color.text)
            HStack(spacing: DS3.S.xl) {
                stat("\(model.todayPomodoros)", "番茄")
                stat("\(model.currentStreak)", "连续天")
                stat("\(model.bestStreak)", "最长记录")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS3.S.md)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(colors: [DS3.Color.accent.opacity(0.16),
                                              DS3.Color.surface],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 20)
                    .stroke(DS3.Color.accent.opacity(0.25), lineWidth: 0.5))
        )
    }

    private func stat(_ v: String, _ l: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(DS3.Font.numL).monospacedDigit().foregroundColor(DS3.Color.text)
            Text(l).font(DS3.Font.micro).foregroundColor(DS3.Color.textDim)
        }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: DS3.S.sm) {
            HStack {
                Text(chartTitle).font(DS3.Font.sub.weight(.semibold)).foregroundColor(DS3.Color.textDim)
                Spacer()
                Text("\(model.rangePomodoros) 番茄 · \(DateUtils.hoursMinutes(from: model.rangeSeconds))")
                    .font(DS3.Font.caption).monospacedDigit().foregroundColor(DS3.Color.textDim)
            }
            Chart(model.rangeBars) { bar in
                BarMark(
                    x: .value("t", bar.label),
                    y: .value("min", bar.minutes)
                )
                .foregroundStyle(DS3.Color.accent.gradient)
                .cornerRadius(2)
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) {
                    AxisGridLine().foregroundStyle(DS3.Color.hairline)
                    AxisValueLabel().foregroundStyle(DS3.Color.textDim)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: range == .day ? 12 : 6)) {
                    AxisValueLabel().foregroundStyle(DS3.Color.textDim)
                }
            }
            .frame(height: 150)
        }
        .card3()
    }

    private var chartTitle: String {
        switch range {
        case .day: return "今日时段"
        case .week: return "近 7 天"
        case .month: return "近 30 天"
        }
    }

    private var heatCard: some View {
        VStack(alignment: .leading, spacing: DS3.S.sm) {
            HStack {
                Text("本月").font(DS3.Font.sub.weight(.semibold)).foregroundColor(DS3.Color.textDim)
                Spacer()
                Text("\(model.monthPomodoros) 番茄 · \(DateUtils.hoursMinutes(from: model.monthSeconds))")
                    .font(DS3.Font.caption).monospacedDigit().foregroundColor(DS3.Color.textDim)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7),
                      spacing: 4) {
                ForEach(model.heatmap) { cell in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(cell.isPlaceholder ? Color.clear : heatColor(cell.pomodoros))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                            Group {
                                if !cell.isPlaceholder {
                                    Text("\(cell.day)")
                                        .font(.system(size: 9))
                                        .foregroundColor(cell.pomodoros > 2 ? .white : DS3.Color.textDim)
                                }
                            }
                        )
                }
            }
        }
        .card3()
    }

    private func heatColor(_ p: Int) -> Color {
        switch p {
        case 0: return DS3.Color.hairline.opacity(0.35)
        case 1: return DS3.Color.accent.opacity(0.25)
        case 2: return DS3.Color.accent.opacity(0.45)
        case 3...4: return DS3.Color.accent.opacity(0.65)
        default: return DS3.Color.accent
        }
    }

    private var grid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: DS3.S.sm),
                            GridItem(.flexible(), spacing: DS3.S.sm)],
                  spacing: DS3.S.sm) {
            tile("clock", "累计专注", DateUtils.hoursMinutes(from: model.totalSeconds), DS3.Color.longBreak)
            tile("circle.fill", "总番茄", "\(model.totalPomodoros)", DS3.Color.accent)
            tile("calendar", "本月", DateUtils.hoursMinutes(from: model.monthSeconds), DS3.Color.shortBreak)
            tile("flame.fill", "连续天数", "\(model.currentStreak)", DS3.Color.warn)
        }
    }

    private func tile(_ icon: String, _ title: String, _ value: String, _ color: Color) -> some View {
        HStack(spacing: DS3.S.md) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 34, height: 34)
                .background(Circle().fill(color.opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(DS3.Font.numL).monospacedDigit().foregroundColor(DS3.Color.text)
                Text(title).font(DS3.Font.micro).foregroundColor(DS3.Color.textDim)
            }
            Spacer()
        }
        .card3(inset: DS3.S.md)
    }

    private var yearHeatmapCard: some View {
        VStack(alignment: .leading, spacing: DS3.S.sm) {
            Text("近一年").font(DS3.Font.sub.weight(.semibold)).foregroundColor(DS3.Color.textDim)
            YearHeatmapView(weeks: model.yearWeeks)
        }
        .card3()
    }

    private var interruptCard: some View {
        VStack(alignment: .leading, spacing: DS3.S.sm) {
            Text("打断原因").font(DS3.Font.sub.weight(.semibold)).foregroundColor(DS3.Color.textDim)
            ForEach(model.interruptReasons) { r in
                HStack {
                    Text(r.label).font(DS3.Font.sub).foregroundColor(DS3.Color.text)
                    Spacer()
                    Text("\(r.count) 次")
                        .font(DS3.Font.caption).monospacedDigit()
                        .foregroundColor(DS3.Color.textDim)
                }
            }
        }
        .card3()
    }

    private func taskDistribution(_ model: StatsModel3) -> some View {
        let maxSeconds = max(1, model.taskStats.first?.seconds ?? 1)
        return VStack(alignment: .leading, spacing: DS3.S.sm) {
            Text("任务时间分布").font(DS3.Font.sub.weight(.semibold)).foregroundColor(DS3.Color.textDim)
            ForEach(model.taskStats.prefix(6)) { stat in
                VStack(spacing: DS3.S.xs) {
                    HStack(spacing: DS3.S.sm) {
                        Circle().fill(Color(hex: stat.colorHex)).frame(width: 7, height: 7)
                        Text(stat.name).font(DS3.Font.sub).foregroundColor(DS3.Color.text).lineLimit(1)
                        Spacer()
                        Text(DateUtils.hoursMinutes(from: stat.seconds))
                            .font(DS3.Font.caption).monospacedDigit()
                            .foregroundColor(DS3.Color.textDim)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(DS3.Color.hairline.opacity(0.4))
                            Capsule()
                                .fill(Color(hex: stat.colorHex))
                                .frame(width: geo.size.width * CGFloat(stat.seconds) / CGFloat(maxSeconds))
                        }
                    }
                    .frame(height: 5)
                }
                .padding(.vertical, 2)
            }
        }
        .card3()
    }

    private var breakdownCard: some View {
        let total = max(1, model.breakdown.focus + model.breakdown.short + model.breakdown.long)
        return VStack(alignment: .leading, spacing: DS3.S.sm) {
            Text("会话分布").font(DS3.Font.sub.weight(.semibold)).foregroundColor(DS3.Color.textDim)
            HStack(spacing: DS3.S.sm) {
                seg("专注", model.breakdown.focus, total, DS3.Color.focus)
                seg("小憩", model.breakdown.short, total, DS3.Color.shortBreak)
                seg("长歇", model.breakdown.long, total, DS3.Color.longBreak)
            }
        }
        .card3()
    }

    private func seg(_ label: String, _ count: Int, _ total: Int, _ color: Color) -> some View {
        VStack(spacing: DS3.S.xs) {
            Text("\(count)").font(DS3.Font.numL).monospacedDigit().foregroundColor(DS3.Color.text)
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.12))
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color)
                        .frame(height: geo.size.height * CGFloat(count) / CGFloat(total))
                }
            }
            .frame(height: 64)
            Text(label).font(DS3.Font.micro).foregroundColor(DS3.Color.textDim)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 年度热力图（GitHub 风格，纯 SwiftUI，iOS15 可用）

struct YearHeatmapView: View {
    let weeks: [[StatsModel3.YearCell]]
    private let cell: CGFloat = 11
    private let gap: CGFloat = 3

    var body: some View {
        VStack(alignment: .leading, spacing: DS3.S.xs) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(weeks.indices, id: \.self) { w in
                        VStack(spacing: DS3.S.xs) {
                            monthLabel(forWeek: w)
                                .frame(height: 12)
                            VStack(spacing: 2) {
                                ForEach(weeks[w].indices, id: \.self) { d in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(color(weeks[w][d]))
                                        .frame(width: cell, height: cell)
                                }
                            }
                        }
                        .padding(.trailing, gap)
                    }
                }
            }
            HStack(spacing: DS3.S.xs) {
                Text("少").font(DS3.Font.micro).foregroundColor(DS3.Color.textDim)
                ForEach(0..<5, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(levelColor(level))
                        .frame(width: 9, height: 9)
                }
                Text("多").font(DS3.Font.micro).foregroundColor(DS3.Color.textDim)
            }
        }
    }

    private func monthLabel(forWeek w: Int) -> some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .weekOfYear, value: -52, to: today)
        let gridStart = start.flatMap {
            cal.date(byAdding: .day,
                     value: -((cal.component(.weekday, from: $0) + 5) % 7), to: $0)
        }
        let weekStart = gridStart.flatMap { cal.date(byAdding: .day, value: w * 7, to: $0) }
        let prevStart = weekStart.flatMap { cal.date(byAdding: .day, value: -7, to: $0) }
        let m = weekStart.map { cal.component(.month, from: $0) } ?? 0
        let prevM = prevStart.map { cal.component(.month, from: $0) } ?? 0

        return Group {
            if w > 0 && m != prevM {
                Text("\(m)月")
                    .font(.system(size: 9))
                    .foregroundColor(DS3.Color.textDim)
                    .frame(width: cell + gap, alignment: .leading)
            } else {
                Color.clear.frame(width: cell + gap, height: 12)
            }
        }
    }

    private func color(_ c: StatsModel3.YearCell) -> Color {
        if c.isEmpty { return Color.clear }
        switch c.day {
        case 0: return DS3.Color.hairline.opacity(0.35)
        case 1: return DS3.Color.accent.opacity(0.25)
        case 2: return DS3.Color.accent.opacity(0.45)
        case 3...4: return DS3.Color.accent.opacity(0.65)
        default: return DS3.Color.accent
        }
    }

    private func levelColor(_ l: Int) -> Color {
        switch l {
        case 0: return DS3.Color.hairline.opacity(0.35)
        case 1: return DS3.Color.accent.opacity(0.25)
        case 2: return DS3.Color.accent.opacity(0.45)
        case 3: return DS3.Color.accent.opacity(0.65)
        default: return DS3.Color.accent
        }
    }
}

// MARK: - 分享卡片视图

struct ShareCardView3: View {
    @StateObject private var holder: CardModelHolder

    init(model: StatsModel3) {
        _holder = StateObject(wrappedValue: CardModelHolder(model: model))
    }

    final class CardModelHolder: ObservableObject {
        let model: StatsModel3
        init(model: StatsModel3) { self.model = model }
    }

    var body: some View {
        let m = holder.model
        VStack(alignment: .leading, spacing: DS3.S.md) {
            HStack {
                Text("FocusFlip 专注报告")
                    .font(DS3.Font.headline).foregroundColor(DS3.Color.text)
                Spacer()
                Text(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none))
                    .font(DS3.Font.caption).monospacedDigit().foregroundColor(DS3.Color.textDim)
            }

            VStack(alignment: .leading, spacing: DS3.S.xs) {
                Text("本周专注")
                    .font(DS3.Font.caption).foregroundColor(DS3.Color.textDim)
                Text(DateUtils.hoursMinutes(from: m.rangeSeconds))
                    .font(DS3.Font.numXL).monospacedDigit().foregroundColor(DS3.Color.text)
            }

            HStack(spacing: DS3.S.lg) {
                mini("\(m.rangePomodoros)", "番茄")
                mini("\(m.currentStreak)", "连续天")
                mini("\(m.totalPomodoros)", "累计番茄")
            }

            // 近 7 天迷你柱图
            HStack(alignment: .bottom, spacing: DS3.S.sm) {
                ForEach(m.rangeBars) { bar in
                    Capsule()
                        .fill(DS3.Color.accent.opacity(0.85))
                        .frame(height: min(CGFloat(bar.minutes), 64))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 70, alignment: .bottom)

            Text("记录每一次专注 · FocusFlip")
                .font(DS3.Font.micro)
                .foregroundColor(DS3.Color.textDim)
        }
        .padding(DS3.S.lg)
        .frame(width: 340, height: 480, alignment: .top)
        .background(RoundedRectangle(cornerRadius: DS3.R.lg).fill(DS3.Color.surface))
    }

    private func mini(_ v: String, _ l: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(DS3.Font.numL).monospacedDigit().foregroundColor(DS3.Color.text)
            Text(l).font(DS3.Font.micro).foregroundColor(DS3.Color.textDim)
        }
    }
}

// MARK: - Fallback (iOS 15, no Charts)

private struct StatsFallback3: View {
    @StateObject private var model = StatsModel3()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DS3.S.md) {
                    // 简化：仅周视图柱条
                    VStack(alignment: .leading, spacing: DS3.S.sm) {
                        Text("近 7 天").font(DS3.Font.sub.weight(.semibold)).foregroundColor(DS3.Color.textDim)
                        HStack(alignment: .bottom, spacing: DS3.S.sm) {
                            ForEach(model.rangeBars) { bar in
                                VStack(spacing: DS3.S.xs) {
                                    Capsule()
                                        .fill(DS3.Color.accent.opacity(0.85))
                                        .frame(height: min(CGFloat(bar.minutes), 100))
                                    Text(bar.label)
                                        .font(DS3.Font.micro)
                                        .foregroundColor(DS3.Color.textDim)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(height: 140, alignment: .bottom)
                    }
                    .card3()

                    HStack(spacing: DS3.S.xl) {
                        stat("\(model.todayPomodoros)", "番茄")
                        stat("\(model.currentStreak)", "连续天")
                        stat("\(model.bestStreak)", "最长记录")
                    }
                    .frame(maxWidth: .infinity)
                    .card3()

                    VStack(spacing: DS3.S.sm) {
                        row("累计专注", DateUtils.hoursMinutes(from: model.totalSeconds))
                        row("总番茄", "\(model.totalPomodoros)")
                        row("本月", DateUtils.hoursMinutes(from: model.monthSeconds))
                    }
                    .card3()

                    VStack(alignment: .leading, spacing: DS3.S.sm) {
                        Text("近一年").font(DS3.Font.sub.weight(.semibold)).foregroundColor(DS3.Color.textDim)
                        YearHeatmapView(weeks: model.yearWeeks)
                    }
                    .card3()
                }
                .padding(.horizontal, DS3.S.md)
                .padding(.bottom, DS3.S.xxl)
            }
            .hideScrollBackground3()
            .background(DS3.Color.bg.ignoresSafeArea())
            .navigationTitle("统计")
        }
        .onAppear { model.load(range: .week) }
    }

    private func stat(_ v: String, _ l: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(DS3.Font.numL).monospacedDigit().foregroundColor(DS3.Color.text)
            Text(l).font(DS3.Font.micro).foregroundColor(DS3.Color.textDim)
        }
    }

    private func row(_ t: String, _ v: String) -> some View {
        HStack {
            Text(t).font(DS3.Font.body).foregroundColor(DS3.Color.textDim)
            Spacer()
            Text(v).font(DS3.Font.body.weight(.semibold)).monospacedDigit().foregroundColor(DS3.Color.text)
        }
    }
}
