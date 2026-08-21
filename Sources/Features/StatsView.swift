import SwiftUI
import CoreData

/// 统计页 —— 今日 / 本周 / 本月，Flow 式清爽排版
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

    // 汇总结果
    @State private var pomodoros = 0
    @State private var totalMinutes = 0
    @State private var dayBars: [(label: String, minutes: Double)] = []
    @State private var taskRows: [(name: String, colorHex: String, minutes: Int)] = []

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("范围", selection: $range) {
                        ForEach(RangeKind.allCases) { k in
                            Text(k.label).tag(k)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)
                    .onChange(of: range) { _ in reload() }

                    heroCard
                    if range != .today && !dayBars.isEmpty {
                        chartCard
                    }
                    if !taskRows.isEmpty {
                        taskCard
                    }
                    if pomodoros == 0 {
                        emptyView.padding(.top, 40)
                    }
                }
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("统计")
            .onAppear(perform: reload)
        }
    }

    // MARK: 总览卡

    private var heroCard: some View {
        HStack(spacing: 0) {
            heroNumber("\(pomodoros)", unit: "个番茄")
            Divider().frame(height: 36)
            heroNumber(hoursText, unit: "专注时长")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal, 20)
    }

    private func heroNumber(_ value: String, unit: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(Color(hex: "#5865F2"))
            Text(unit)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var hoursText: String {
        let h = totalMinutes / 60, m = totalMinutes % 60
        return h > 0 ? "\(h) 时 \(m) 分" : "\(m) 分钟"
    }

    // MARK: 柱状图（自定义，iOS15 可用）

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(range == .week ? "最近 7 天" : "最近 30 天")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            chartBars
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal, 20)
    }

    private var chartBars: some View {
        let maxV = max(1, dayBars.map(\.minutes).max() ?? 1)
        return HStack(alignment: .bottom, spacing: range == .week ? 10 : 3) {
            ForEach(dayBars.indices, id: \.self) { i in
                let bar = dayBars[i]
                VStack(spacing: 6) {
                    ZStack(alignment: .bottom) {
                        Capsule().fill(Color(hex: "#5865F2").opacity(0.12))
                            .frame(width: barWidth, height: chartHeight)
                        if bar.minutes > 0 {
                            Capsule().fill(Color(hex: "#5865F2"))
                                .frame(width: barWidth,
                                       height: max(6, chartHeight * bar.minutes / maxV))
                        }
                    }
                    Text(bar.label)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: chartHeight + 22)
    }

    private var barWidth: CGFloat { range == .week ? 18 : 7 }
    private var chartHeight: CGFloat { 110 }

    // MARK: 任务分布

    private var taskCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("任务分布")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            ForEach(taskRows.indices, id: \.self) { i in
                let row = taskRows[i]
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Circle().fill(Color(hex: row.colorHex)).frame(width: 8, height: 8)
                        Text(row.name)
                            .font(.system(size: 14))
                            .lineLimit(1)
                        Spacer()
                        Text(Self.durationText(row.minutes))
                            .font(.system(size: 12).monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(hex: row.colorHex).opacity(0.15))
                            Capsule().fill(Color(hex: row.colorHex))
                                .frame(width: geo.size.width
                                       * CGFloat(row.minutes) / CGFloat(max(1, totalMinutes)))
                        }
                    }
                    .frame(height: 5)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal, 20)
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar")
                .font(.system(size: 30))
                .foregroundColor(.secondary.opacity(0.5))
            Text("这段时间还没有完成的番茄")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
    }

    // MARK: 数据加载

    private func reload() {
        let cal = Calendar.current
        let now = Date()

        let rangeStart: Date
        switch range {
        case .today:
            rangeStart = cal.startOfDay(for: now)
        case .week:
            let day = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: now))!
            rangeStart = day
        case .month:
            let day = cal.date(byAdding: .day, value: -29, to: cal.startOfDay(for: now))!
            rangeStart = day
        }

        let req: NSFetchRequest<SessionEntity> = SessionEntity.fetchRequest()
        req.predicate = NSPredicate(format: "phaseRaw == %@ AND completed == YES AND startDate >= %@",
                                    Phase.focus.rawValue, rangeStart as NSDate)
        let sessions = (try? Store.shared.context.fetch(req)) ?? []

        pomodoros = sessions.count
        totalMinutes = sessions.reduce(0) { $0 + Int($1.durationSeconds) } / 60

        // 日柱
        let dayCount = range == .week ? 7 : 30
        var bars: [(String, Double)] = []
        let dfWeek = ["日", "一", "二", "三", "四", "五", "六"]
        for offset in stride(from: -(dayCount - 1), through: 0, by: 1) {
            guard let day = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: now)) else { continue }
            let next = cal.date(byAdding: .day, value: 1, to: day)!
            let mins = sessions.filter { $0.startDate >= day && $0.startDate < next }
                .reduce(0) { $0 + Int($1.durationSeconds) } / 60
            let label: String
            if range == .week {
                label = dfWeek[cal.component(.weekday, from: day) - 1]
            } else {
                let d = cal.component(.day, from: day)
                label = d % 5 == 0 || offset == 0 ? "\(d)" : ""
            }
            bars.append((label, Double(mins)))
        }
        dayBars = bars

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
    }

    static func durationText(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        return h > 0 ? "\(h)时\(m)分" : "\(m)分"
    }
}
