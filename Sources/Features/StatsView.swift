import SwiftUI
import CoreData
import UIKit

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
    @State private var yearDays: [(day: Date, minutes: Int)] = []
    @State private var yearHasData = false

    private let accent = Color(hex: "#5865F2")

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 14) {
                    rangeSelector
                    heroCard
                    if range == .today && !timeline.isEmpty { timelineCard }
                    if range != .today && !dayBars.isEmpty { barChartCard }
                    if pomodoros > 0 {
                        if !hourBins.isEmpty && hourBins.max()! > 0 { hourCard }
                        if !taskRows.isEmpty { donutCard }
                    } else {
                        emptyView.padding(.top, 30)
                    }
                    if yearHasData { heatmapCard }
                }
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("统计")
            .onAppear(perform: reload)
        }
    }

    // MARK: 英雄卡（渐变）
    private var rangeSelector: some View {
        HStack(spacing: 5) {
            ForEach(RangeKind.allCases) { kind in
                let selected = range == kind
                Button {
                    Haptic.light()
                    withAnimation(DS.Motion.quick) { range = kind }
                    reload()
                } label: {
                    Text(kind.label)
                        .font(DS.F.subheadSb)
                        .monospacedDigit()
                        .foregroundColor(selected ? .white : .secondary)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 36)
                        .background(
                            Capsule().fill(selected ? AnyShapeStyle(DS.accent)
                                                    : AnyShapeStyle(Color.clear))
                                .shadow(color: selected ? DS.accent.opacity(0.20) : .clear,
                                        radius: 10, y: 4)
                        )
                }
                .buttonStyle(PressStyle())
            }
        }
        .padding(5)
        .background(
            Capsule()
                .fill(Color.primary.opacity(0.05))
                .overlay(Capsule().stroke(Color.primary.opacity(0.04), lineWidth: 0.5))
        )
        .padding(.horizontal, DS.S.screen)
        .animation(DS.Motion.soft, value: range)
    }


    private var heroCard: some View {
        VStack(spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    RollText(value: pomodoros,
                             font: DS.F.hero,
                             color: .white)
                    Text("个完成的番茄")
                        .font(DS.F.subhead)
                        .opacity(0.82)
                }
                Spacer()
                VStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 17, weight: .semibold))
                    RollText(value: streak,
                             font: DS.F.numberL,
                             color: .white)
                    Text("连续天数")
                        .font(DS.F.caption)
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
        .padding(DS.S.card + 2)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: DS.R.hero, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: "#6A79FF"), DS.accentDeep],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.R.hero, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 0.5)
                )
        )
        .shadow(color: DS.accent.opacity(0.22), radius: 26, y: 12)
        .padding(.horizontal, DS.S.screen)
    }

    private func heroStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(DS.F.subheadSb)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(DS.F.caption)
                .opacity(0.78)
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

    private var donutCard: some View { VStack(spacing: 8) { filterChip; donutCardContent } }

    private var filterChip: some View {
        Group {
            if let fn = filterName {
                HStack(spacing: 6) {
                    Text("已筛选：\(fn)")
                        .font(DS.F.caption).foregroundColor(DS.accent)
                    Button {
                        filterName = nil; reload()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private var donutCardContent: some View {
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
                    VStack(spacing: 2) {
                        Text(Self.durationText(totalMinutes))
                            .font(DS.F.numberM)
                            .monospacedDigit()
                        Text(filterName ?? "总计")
                            .font(DS.F.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
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
                            Haptic.light()
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
        VStack(spacing: DS.S.md) {
            ZStack {
                Circle().fill(DS.accent.opacity(0.07)).frame(width: 76, height: 76)
                Circle().stroke(DS.accent.opacity(0.15), lineWidth: 1.4).frame(width: 76, height: 76)
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(DS.accent.opacity(0.62))
            }
            Text("这段时间还没有完成的番茄")
                .font(DS.F.headline)
            Text("去「专注」页点亮第一个圆环吧")
                .font(DS.F.subhead)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.S.card)
        .hubCard(.standard)
        .padding(.horizontal, DS.S.screen)
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
                    .onTapGesture {
                        Haptic.light()
                        openNote(i)
                    }
                    .contextMenu {
                        Button {
                            UIPasteboard.general.string = "\(Self.clock(e.start)) · \(e.taskName) · \(e.mins) 分钟"
                            Haptic.light()
                        } label: {
                            Label("复制摘要", systemImage: "doc.on.doc")
                        }
                    }
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

    // MARK: 全年热力

    private var heatmapCard: some View {
        ChartCard(title: "全年热力", subtitle: "过去一年，每个专注的日子") {
            VStack(alignment: .leading, spacing: 10) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 3) {
                        let cols = yearDays.count / 7
                        ForEach(0..<max(cols, 1), id: \.self) { c in
                            VStack(spacing: 3) {
                                ForEach(0..<7, id: \.self) { r in
                                    let idx = c * 7 + r
                                    heatCell(idx < yearDays.count ? yearDays[idx].minutes : 0)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 1)
                }
                HStack(spacing: 4) {
                    Text("少")
                        .font(DS.F.caption)
                        .foregroundColor(.secondary)
                    ForEach([0, 20, 45, 90, 150], id: \.self) { m in
                        heatCell(m)
                    }
                    Text("多")
                        .font(DS.F.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("近 12 个月 · 每格一天")
                        .font(DS.F.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }
        }
    }

    private func heatCell(_ minutes: Int) -> some View {
        RoundedRectangle(cornerRadius: 2.5)
            .fill(heatColor(minutes))
            .frame(width: 11, height: 11)
    }

    private func heatColor(_ minutes: Int) -> Color {
        switch minutes {
        case 0: return Color.primary.opacity(0.06)
        case ..<25: return DS.accent.opacity(0.25)
        case ..<50: return DS.accent.opacity(0.5)
        case ..<100: return DS.accent.opacity(0.75)
        default: return DS.accent
        }
    }

    private func refreshYearHeat() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard var gridStart = cal.date(byAdding: .day, value: -364, to: today) else { return }
        // 对齐周一开头（isoWeekday: 周一=2 → 回退 iso-1 天）
        let iso = (cal.component(.weekday, from: gridStart) + 5) % 7
        gridStart = cal.date(byAdding: .day, value: -iso, to: gridStart) ?? gridStart

        let req: NSFetchRequest<SessionEntity> = SessionEntity.fetchRequest()
        req.predicate = NSPredicate(format: "phaseRaw == %@ AND completed == YES AND startDate >= %@",
                                    Phase.focus.rawValue, gridStart as NSDate)
        let sessions = (try? Store.shared.context.fetch(req)) ?? []
        var byDay: [Date: Int] = [:]
        for s in sessions {
            byDay[cal.startOfDay(for: s.startDate), default: 0] += max(0, Int(s.durationSeconds))
        }

        var cells: [(day: Date, minutes: Int)] = []
        var cursor = gridStart
        while cursor <= today {
            cells.append((cursor, byDay[cursor] ?? 0))
            cursor = cal.date(byAdding: .day, value: 1, to: cursor) ?? cursor.addingTimeInterval(86400)
        }
        while cells.count % 7 != 0 { cells.append((cursor, 0)) }  // 末周补齐（未来格）

        yearDays = cells
        yearHasData = byDay.values.contains { $0 > 0 }
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

        refreshYearHeat()
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
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DS.F.headline)
                    Text(subtitle)
                        .font(DS.F.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if let t = actionTitle, let act = action {
                    Button {
                        Haptic.light()
                        act()
                    } label: {
                        HStack(spacing: 3) {
                            Text(t)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .font(DS.F.subheadSb)
                        .foregroundColor(DS.accent)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 30)
                        .background(Capsule().fill(DS.accent.opacity(0.10)))
                    }
                    .buttonStyle(PressStyle())
                }
            }
            content
        }
        .padding(DS.S.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hubSurface(.standard)
        .padding(.horizontal, DS.S.screen)
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
