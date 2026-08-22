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
    @State private var timeline: [(id: UUID, start: Date, end: Date,
                                   mins: Int, done: Bool,
                                   taskName: String, colorHex: String,
                                   note: String?)] = []
    @State private var noteTarget: SessionEntity?
    @State private var noteText = ""
    @State private var showAllTimeline = false
    @State private var filterName: String?

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
                    if range == .today && !timeline.isEmpty { timelineCard }
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
                    RollText(value: pomodoros,
                             font: .system(size: 44, weight: .bold, design: .rounded),
                             color: .white)
                    Text("个完成的番茄")
                        .font(.system(size: 13))
                        .opacity(0.8)
                }
                Spacer()
                VStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 17))
                    RollText(value: streak,
                             font: .system(size: 22, weight: .bold, design: .rounded),
                             color: .white)
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
            RoundedRectangle(cornerRadius: DS.R.card, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: "#6A79FF"), DS.accentDeep],
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
                        let selected = filterName == r.name
                        HStack(spacing: 7) {
                            Circle().fill(Color(hex: r.colorHex))
                                .frame(width: 8, height: 8)
                            Text(r.name)
                                .font(.system(size: selected ? 12.5 : 12,
                                              weight: selected ? .bold : .regular))
                                .foregroundColor(selected ? Color(hex: r.colorHex) : .primary)
                                .lineLimit(1)
                            Spacer()
                            if selected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: r.colorHex))
                            } else {
                                Text("\(Int(Double(r.minutes) / total * 100))%")
                                    .font(.system(size: 11, weight: .semibold))
                                    .monospacedDigit()
                                    .foregroundColor(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            Haptic.tick()
                            filterName = selected ? nil : r.name
                            reload()
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
                .font(DS.F.subhead)
                .foregroundColor(.secondary)
            Text("去「专注」页点亮第一个圆环吧")
                .font(DS.F.caption)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: 今日时间线（记录类）

    private var timelineCard: some View {
        ChartCard(title: "今日时间线", subtitle: "点一条可写一句话备注",
                  actionTitle: "全部", action: { showAllTimeline = true }) {
            VStack(spacing: 0) {
                ForEach(timeline.indices, id: \.self) { i in
                    let e = timeline[i]
                    HStack(alignment: .top, spacing: 12) {
                        Text(Self.clock(e.start))
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundColor(.secondary)
                            .frame(width: 40, alignment: .leading)

                        VStack(spacing: 0) {
                            Circle()
                                .fill(Color(hex: e.colorHex))
                                .frame(width: 8, height: 8)
                                .padding(.top, 4)
                            if i < timeline.count - 1 {
                                Rectangle().fill(Color.secondary.opacity(0.18))
                                    .frame(width: 1.5)
                                    .frame(minHeight: 26)
                                    .padding(.top, 2)
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 7) {
                                Text(e.taskName.isEmpty ? "未关联任务" : e.taskName)
                                    .font(.system(size: 13, weight: .medium))
                                    .lineLimit(1)
                                Text("\(e.mins)′")
                                    .font(.system(size: 10, weight: .bold))
                                    .monospacedDigit()
                                    .foregroundColor(accent)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(accent.opacity(0.10)))
                                if !e.done {
                                    Text("中断")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color.secondary.opacity(0.12)))
                                }
                            }
                            if let note = e.note, !note.isEmpty {
                                HStack(alignment: .top, spacing: 4) {
                                    Image(systemName: "text.quote")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary.opacity(0.6))
                                    Text(note)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { openNote(i) }
                }
            }
        }
        .sheet(item: $noteTarget) { session in
            NoteSheet(session: session) { reload() }
        }
    }

    private func openNote(_ i: Int) {
        guard i < timeline.count else { return }
        let req: NSFetchRequest<SessionEntity> = SessionEntity.fetchRequest()
        req.predicate = NSPredicate(format: "id == %@", timeline[i].id as CVarArg)
        if let se = (try? Store.shared.context.fetch(req))?.first {
            noteText = se.note ?? ""
            noteTarget = se
        }
    }

    private static func clock(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: d)
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
        var sessions = (try? Store.shared.context.fetch(req)) ?? []
        if let fname = filterName {
            sessions = sessions.filter { s in
                let n = s.taskId.flatMap { Store.shared.task(id: $0) }?.name ?? "未关联任务"
                return n == fname
            }
        }

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

        // 时间线（仅今日）
        if range == .today {
            timeline = sessions.sorted { $0.startDate < $1.startDate }.map { se in
                let t = se.taskId.flatMap { Store.shared.task(id: $0) }
                return (se.id, se.startDate, se.endDate,
                        Int(se.durationSeconds) / 60, se.completed,
                        t?.name ?? "", t?.colorHex ?? "#8E8E93", se.note)
            }
        } else {
            timeline = []
        }

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
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
                    if let fn = filterName {
                        HStack(spacing: 6) {
                            Text("已筛选：\(fn)")
                                .font(DS.F.caption).foregroundColor(DS.accent)
                            Button { self.filterName = nil; self.reload() } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary.opacity(0.6))
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Capsule().fill(DS.accent.opacity(0.10)))
                    }
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                if let t = actionTitle, let act = action {
                    Button(action: act) {
                        HStack(spacing: 3) {
                            Text(t)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "#5865F2"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color(hex: "#5865F2").opacity(0.10)))
                    }
                }
            }
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.R.card, style: .continuous)
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
                         cornerSize: CGSize(width: r, height: r),
                         style: .continuous)
        return p
    }
}


/// 一句话备注
struct NoteSheet: View {
    let session: SessionEntity
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        NavigationView {
            Form {
                Section("这一段专注的备注") {
                    TextField("比如：状态不错 / 被打断两次…", text: $text)
                }
            }
            .navigationTitle("备注")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Store.shared.setNote(session, text)
                        onDone(); dismiss()
                    }.font(.system(size: 17, weight: .semibold))
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .onAppear { text = session.note ?? "" }
        }
    }
}


// MARK: - 全部时间线（近 7 天分组）

struct TimelineAllSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var groups: [(day: String, items: [SessionEntity])] = []
    @State private var noteTarget: SessionEntity?

    var body: some View {
        NavigationView {
            List {
                ForEach(groups.indices, id: \.self) { gi in
                    Section(groups[gi].day) {
                        ForEach(groups[gi].items, id: \.id) { se in
                            allRow(se)
                        }
                    }
                }
                if groups.isEmpty {
                    Text("最近七天还没有记录").foregroundColor(.secondary)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("专注记录")
.background(SheetDetents())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .onAppear(perform: load)
            .sheet(item: $noteTarget) { se in
                NoteSheet(session: se) { load() }
            }
        }
    }

    private func allRow(_ se: SessionEntity) -> some View {
        let t = se.taskId.flatMap { Store.shared.task(id: $0) }
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return HStack(spacing: 10) {
            Text(f.string(from: se.startDate))
                .font(.system(size: 11).monospacedDigit())
                .foregroundColor(.secondary)
            Circle().fill(Color(hex: t?.colorHex ?? "#8E8E93"))
                .frame(width: 7, height: 7)
            Text(t?.name ?? "未关联任务")
                .font(.system(size: 14))
                .lineLimit(1)
            Spacer()
            Text("\(Int(se.durationSeconds) / 60)′")
                .font(.system(size: 11, weight: .bold).monospacedDigit())
                .foregroundColor(Color(hex: "#5865F2"))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Capsule().fill(Color(hex: "#5865F2").opacity(0.10)))
            if let n = se.note, !n.isEmpty {
                Image(systemName: "text.quote")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { noteTarget = se }
    }

    private func load() {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: Date()))!
        let req: NSFetchRequest<SessionEntity> = SessionEntity.fetchRequest()
        req.predicate = NSPredicate(format: "startDate >= %@", start as NSDate)
        req.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
        let sessions = (try? Store.shared.context.fetch(req)) ?? []
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 EEEE"
        var dict: [String: [SessionEntity]] = [:]
        var order: [String] = []
        for s in sessions {
            let key = f.string(from: s.startDate)
            if dict[key] == nil { order.append(key) }
            dict[key, default: []].append(s)
        }
        groups = order.map { ($0, dict[$0]!) }
    }
}
