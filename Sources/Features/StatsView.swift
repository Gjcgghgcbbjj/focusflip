import SwiftUI
import CoreData

/// 统计页 —— 渐变英雄卡 + 多图表（iOS15 Canvas 自绘）
struct StatsView: View {

    private enum RangeKind: Int, CaseIterable, Identifiable {
        case today = 0, week, month
        var label: String {
            switch self {
            case .today: return "今日"
            case .week: return "本周"
            case .month: return "本月"
            }
        }
        var id: Int { rawValue }
    }

    @State private var range: RangeKind = .today

    // 数据
    @State private var pomodoros = 0
    @State private var totalMinutes = 0
    @State private var dayBars: [(label: String, minutes: Double)] = []
    @State private var hourBins = [Double](repeating: 0, count: 24)
    @State private var taskRows: [(name: String, colorHex: String, minutes: Int)] = []
    @State private var streak = 0

    private let accent = Color(hex: "#5865F2")

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 14) {
                    Picker("范围", selection: $range) {
                        ForEach(RangeKind.allCases) { k in
                            Text(k.label).tag(k)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)
                    .onChange(of: range) { _ in reload() }

                    heroCard
                    if range != .today && !dayBars.isEmpty { barChartCard }
                    if pomodoros > 0 {
                        if !hourBins.isEmpty && hourBins.max()! > 0 { hourCard }
                        if !taskRows.isEmpty { donutCard }
                    } else {
                        emptyView.padding(.top, 30)
                    }
                }
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("统计")
            .onAppear(perform: reload)
        }
    }

    // MARK: 英雄卡（渐变）

    private var heroCard: some View {
        VStack(spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(pomodoros)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("个完成的番茄")
                        .font(.system(size: 13))
                        .opacity(0.8)
                }
                Spacer()
                VStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 17))
                    Text("\(streak)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("连续天数")
                        .font(.system(size: 11))
                        .opacity(0.85)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.16)))
            }

            Divider().overlay(Color.white.opacity(0.25))

            HStack {
                heroStat(hoursText, "专注时长")
                heroStat(avgText, "日均")
                heroStat(bestTaskName, "最常投入")
            }
        }
        .foregroundColor(.white)
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: "#6A79FF"), Color(hex: "#4C50E0")],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .shadow(color: Color(hex: "#5865F2").opacity(0.35), radius: 16, y: 8)
        .padding(.horizontal, 20)
    }

    private func heroStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 11))
                .opacity(0.75)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: 柱状图卡（含均值线）

    private var barChartCard: some View {
        ChartCard(title: range == .week ? "最近 7 天" : "最近 30 天",
                  subtitle: "每日专注分钟") {
            let maxV = max(1, dayBars.map(\.minutes).max() ?? 1)
            let avg = dayBars.map(\.minutes).reduce(0, +) / Double(max(1, dayBars.count))
            let todayIdx = dayBars.count - 1

            return ZStack(alignment: .topLeading) {
                // 均值虚线
                GeometryReader { geo in
                    let y = geo.size.height * (1 - CGFloat(min(1, avg / Double(maxV))))
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundColor(.secondary.opacity(0.5))
                    .overlay(alignment: .trailing) {
                        Text("均 \(Int(avg))′")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .offset(y: -12)
                    }
                }

                HStack(alignment: .bottom, spacing: range == .week ? 10 : 3) {
                    ForEach(dayBars.indices, id: \.self) { i in
                        let bar = dayBars[i]
                        let isToday = i == todayIdx
                        VStack(spacing: 5) {
                            if isToday || bar.minutes == maxV {
                                Text("\(Int(bar.minutes))")
                                    .font(.system(size: 9, weight: .semibold))
                                    .monospacedDigit()
                                    .foregroundColor(accent)
                            }
                            ZStack(alignment: .bottom) {
                                Capsule().fill(accent.opacity(0.10))
                                    .frame(width: barW, height: chartH)
                                RoundedCapsule(fraction: min(1, bar.minutes / Double(maxV)))
                                    .fill(isToday ? AnyShapeStyle(accent)
                                                  : AnyShapeStyle(accent.opacity(0.38)))
                                    .frame(width: barW, height: chartH)
                            }
                            Text(bar.label)
                                .font(.system(size: 9))
                                .foregroundColor(isToday ? accent : .secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: chartH + 24)
            }
            .frame(height: chartH + 24)
        }
    }

    private var barW: CGFloat { range == .week ? 20 : 8 }
    private var chartH: CGFloat { 118 }

    // MARK: 时段分布

    private var hourCard: some View {
        ChartCard(title: "时段分布", subtitle: "你在什么时候最专注") {
            let maxV = max(1, hourBins.max() ?? 1)
            VStack(spacing: 6) {
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(0..<24, id: \.self) { h in
                        let frac = hourBins[h] / Double(maxV)
                        VStack {
                            Spacer()
                            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                .fill(h == currentHour ? AnyShapeStyle(accent)
                                                       : AnyShapeStyle(accent.opacity(0.25 + 0.75 * frac)))
                                .frame(height: max(4, 64 * frac))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 68)
                    }
                }
                HStack {
                    ForEach([0, 6, 12, 18, 23], id: \.self) { h in
                        Text("\(h)时")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        if h != 23 { Spacer() }
                    }
                }
            }
        }
    }

    private var currentHour: Int { Calendar.current.component(.hour, from: Date()) }

    // MARK: 任务占比（环形）

    private var donutCard: some View {
        ChartCard(title: "任务占比", subtitle: "按专注时长") {
            let total = Double(max(1, taskRows.reduce(0) { $0 + $1.minutes }))
            let segs = taskRows.map { ($0, Double($0.minutes) / total) }

            HStack(spacing: 20) {
                ZStack {
                    Canvas { ctx, size in
                        let c = CGPoint(x: size.width / 2, y: size.height / 2)
                        let rOut = min(size.width, size.height) / 2 - 3
                        let rIn = rOut * 0.60
                        let gapDeg = segs.count > 1 ? 3.0 : 0.0
                        var start = Angle.degrees(-90)
                        for ((row, frac)) in segs {
                            let sweep = frac * 360 - gapDeg
                            guard sweep > 0.5 else { continue }
                            let end = start + Angle.degrees(sweep)
                            var path = Path()
                            path.addArc(center: c, radius: rOut,
                                        startAngle: start, endAngle: end, clockwise: false)
                            path.addArc(center: c, radius: rIn,
                                        startAngle: end, endAngle: start, clockwise: true)
                            path.closeSubpath()
                            ctx.fill(path, with: .color(Color(hex: row.colorHex)))
                            start = end + Angle.degrees(gapDeg)
                        }
                    }
                    VStack(spacing: 0) {
                        Text(Self.durationText(totalMinutes))
                            .font(.system(size: 15, weight: .bold))
                            .monospacedDigit()
                        Text("总计")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 132, height: 132)

                VStack(alignment: .leading, spacing: 9) {
                    ForEach(taskRows.prefix(5).indices, id: \.self) { i in
                        let r = taskRows[i]
                        HStack(spacing: 7) {
                            Circle().fill(Color(hex: r.colorHex))
                                .frame(width: 8, height: 8)
                            Text(r.name)
                                .font(.system(size: 12))
                                .lineLimit(1)
                            Spacer()
                            Text("\(Int(Double(r.minutes) / total * 100))%")
                                .font(.system(size: 11, weight: .semibold))
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var bestTaskName: String {
        taskRows.first?.name ?? "—"
    }

    private var emptyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.pie.fill")
                .font(.system(size: 34))
                .foregroundStyle(
                    LinearGradient(colors: [Color(hex: "#6A79FF"), Color(hex: "#4C50E0")],
                                   startPoint: .top, endPoint: .bottom))
                .opacity(0.55)
            Text("这段时间还没有完成的番茄")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: 派生文本

    private var hoursText: String {
        let h = totalMinutes / 60, m = totalMinutes % 60
        return h > 0 ? "\(h)时\(m)分" : "\(m)分钟"
    }

    private var avgText: String {
        let days = range == .today ? 1 : (range == .week ? 7 : 30)
        return "\(totalMinutes / days)分"
    }

    // MARK: 数据加载

    private func reload() {
        let cal = Calendar.current
        let now = Date()

        let rangeStart: Date
        let dayCount: Int
        switch range {
        case .today:
            rangeStart = cal.startOfDay(for: now); dayCount = 1
        case .week:
            rangeStart = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: now))!; dayCount = 7
        case .month:
            rangeStart = cal.date(byAdding: .day, value: -29, to: cal.startOfDay(for: now))!; dayCount = 30
        }

        let req: NSFetchRequest<SessionEntity> = SessionEntity.fetchRequest()
        req.predicate = NSPredicate(format: "phaseRaw == %@ AND completed == YES AND startDate >= %@",
                                    Phase.focus.rawValue, rangeStart as NSDate)
        let sessions = (try? Store.shared.context.fetch(req)) ?? []

        pomodoros = sessions.count
        totalMinutes = sessions.reduce(0) { $0 + Int($1.durationSeconds) } / 60

        // 日柱
        let dfWeek = ["日", "一", "二", "三", "四", "五", "六"]
        var bars: [(String, Double)] = []
        for offset in stride(from: -(dayCount - 1), through: 0, by: 1) {
            guard let day = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: now)) else { continue }
            let next = cal.date(byAdding: .day, value: 1, to: day)!
            let mins = sessions.filter { $0.startDate >= day && $0.startDate < next }
                .reduce(0) { $0 + Int($1.durationSeconds) } / 60
            let label: String
            if dayCount == 1 { label = "今天" }
            else if dayCount == 7 { label = dfWeek[cal.component(.weekday, from: day) - 1] }
            else {
                let dnum = cal.component(.day, from: day)
                label = offset == 0 ? "今" : (dnum % 5 == 0 ? "\(dnum)" : "")
            }
            bars.append((label, Double(mins)))
        }
        dayBars = bars

        // 时段分布
        var bins = [Double](repeating: 0, count: 24)
        for s in sessions where range == .today {
            let h = cal.component(.hour, from: s.startDate)
            bins[h] += Double(Int(s.durationSeconds) / 60)
        }
        hourBins = bins

        // 任务分布
        var byTask: [UUID?: Int] = [:]
        for s in sessions {
            byTask[s.taskId, default: 0] += Int(s.durationSeconds) / 60
        }
        taskRows = byTask
            .map { (id, mins) -> (String, String, Int) in
                if let id, let t = Store.shared.task(id: id) {
                    return (t.name, t.colorHex, mins)
                }
                return ("未关联任务", "#8E8E93", mins)
            }
            .sorted { $0.2 > $1.2 }
            .map { ($0.0, $0.1, $0.2) }

        // 连续天数（近 120 天）
        streak = Self.computeStreak(cal: cal, now: now)
    }

    static func computeStreak(cal: Calendar, now: Date) -> Int {
        let start = cal.date(byAdding: .day, value: -119, to: cal.startOfDay(for: now))!
        let req: NSFetchRequest<SessionEntity> = SessionEntity.fetchRequest()
        req.predicate = NSPredicate(format: "phaseRaw == %@ AND completed == YES AND startDate >= %@",
                                    Phase.focus.rawValue, start as NSDate)
        let sessions = (try? Store.shared.context.fetch(req)) ?? []
        var days = Set<Date>()
        for s in sessions { days.insert(cal.startOfDay(for: s.startDate)) }

        var streak = 0
        var cursor = cal.startOfDay(for: now)
        // 今天没打卡不打断昨天开始的连击
        if !days.contains(cursor) { cursor = cal.date(byAdding: .day, value: -1, to: cursor)! }
        while days.contains(cursor) {
            streak += 1
            cursor = cal.date(byAdding: .day, value: -1, to: cursor)!
        }
        return streak
    }

    static func durationText(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        return h > 0 ? "\(h)时\(m)分" : "\(m)分"
    }
}

// MARK: - 图表小构件

private struct ChartCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal, 20)
    }
}

/// 顶部圆角的柱体（底部直角贴轴线）
private struct RoundedCapsule: Shape {
    let fraction: Double
    func path(in rect: CGRect) -> Path {
        let h = rect.height * CGFloat(max(0.02, fraction))
        let r: CGFloat = min(rect.width / 2, 5)
        var p = Path()
        p.addRoundedRect(in: CGRect(x: 0, y: rect.height - h,
                                    width: rect.width, height: h),
                         cornerSizes: CGSize(width: r, height: r),
                         style: .continuous)
        return p
    }
}
