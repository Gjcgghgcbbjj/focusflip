import SwiftUI

/// 自由计时面板 —— 与专注主控共用一套计时/按钮语言。
/// 状态全部落盘（freetimer.snapshot.v1）：杀后台/切走后无缝恢复，与番茄引擎同标准。
struct FreeTimerPane: View {

    private enum Mode: Int, CaseIterable, Identifiable {
        case stopwatch = 0, countdown
        var id: Int { rawValue }
        var label: String { self == .stopwatch ? "秒表" : "倒计时" }
    }

    @ObservedObject private var model = FreeTimerModel.shared
    @State private var mode: Mode = .stopwatch

    var body: some View {
        VStack(spacing: 0) {
            modeTabs
                .padding(.top, 14)

            Spacer(minLength: DS.S.sm)

            Group {
                switch mode {
                case .stopwatch: stopwatchBody
                case .countdown: countdownBody
                }
            }
            .animation(DS.Motion.soft, value: mode)

            Spacer(minLength: DS.S.sm)
        }
    }

    private var modeTabs: some View {
        HStack(spacing: 4) {
            tabButton("秒表", .stopwatch)
            tabButton("倒计时", .countdown)
        }
        .padding(5)
        .background(
            Capsule()
                .fill(Color.primary.opacity(0.05))
                .overlay(Capsule().stroke(Color.primary.opacity(0.04), lineWidth: 0.5))
        )
        .animation(DS.Motion.soft, value: mode)
    }

    private func tabButton(_ title: String, _ target: Mode) -> some View {
        let selected = mode == target
        return Button {
            Haptic.light()
            withAnimation(DS.Motion.soft) { mode = target }
        } label: {
            Text(title)
                .font(DS.F.bodySb)
                .foregroundColor(selected ? .white : .secondary)
                .padding(.horizontal, 22)
                .frame(height: DS.H.segInner)
                .background(
                    Capsule()
                        .fill(selected ? AnyShapeStyle(DS.accent) : AnyShapeStyle(Color.clear))
                        .shadow(color: selected ? DS.accent.opacity(0.24) : .clear,
                                radius: 12, y: 4)
                )
        }
        .buttonStyle(PressStyle())
    }

    // MARK: 秒表

    private var swElapsed: TimeInterval { model.swElapsed }

    private var stopwatchBody: some View {
        VStack(spacing: 26) {
            VStack(spacing: 8) {
                TimelineView(.animation(minimumInterval: 0.05)) { _ in
                    Text(Self.format(swElapsed))
                        .font(DS.F.timerLg)
                        .monospacedDigit()
                        .kerning(-1)
                        .foregroundColor(.primary)
                }
                Text("秒表")
                    .font(DS.F.microCaps)
                    .kerning(1.5)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 16) {
                circularControl(icon: model.swRunning ? "pause.fill" : "play.fill",
                                size: DS.H.circleMain,
                                tint: DS.accent,
                                filled: true) {
                    model.toggleRun()
                }

                circularControl(icon: model.swRunning ? "flag.fill"
                                      : (swElapsed > 0 ? "arrow.counterclockwise" : "play.fill"),
                                size: 56,
                                tint: swElapsed > 0 || model.swRunning ? DS.danger : DS.accent,
                                filled: false) {
                    model.lapOrReset()
                }
            }

            if !model.laps.isEmpty {
                lapList
            }
        }
        .padding(.horizontal, 24)
    }

    private var lapList: some View {
        let fastest = model.laps.min()
        let slowest = model.laps.count > 1 ? model.laps.max() : nil

        return ScrollView {
            VStack(spacing: 0) {
                ForEach(model.laps.indices.reversed(), id: \.self) { i in
                    lapRow(i,
                           fastest: fastest,
                           slowest: slowest)
                    if i > 0 { Divider().opacity(0.45) }
                }
            }
        }
        .frame(maxHeight: 210)
        .hubSurface(.inset)
    }

    private func lapRow(_ i: Int, fastest: TimeInterval?, slowest: TimeInterval?) -> some View {
        let isFast = model.laps[i] == fastest && model.laps.count > 1
        let isSlow = model.laps[i] == slowest && model.laps.count > 1
        let color: Color = isFast ? DS.success : isSlow ? DS.danger : .primary

        return HStack(spacing: DS.S.md) {
            Text(isFast ? "最快" : isSlow ? "最慢" : "Lap \(i + 1)")
                .font(DS.F.subheadSb)
                .foregroundColor(isFast || isSlow ? color : .secondary)
            Spacer()
            Text(Self.format(model.laps[i]))
                .font(DS.F.bodySb.monospacedDigit())
                .foregroundColor(color)
            Button {
                Haptic.light()
                withAnimation(DS.Motion.quick) { model.removeLap(at: i) }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary.opacity(0.4))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DS.S.lg)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .contextMenu {
            Button(role: .destructive) {
                withAnimation(DS.Motion.quick) { model.removeLap(at: i) }
                Haptic.light()
            } label: {
                Label("删除此计次", systemImage: "trash")
            }
        }
    }

    // MARK: 倒计时

    private var cdRemaining: TimeInterval { model.cdRemaining }

    private var countdownBody: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                TimelineView(.animation) { _ in
                    let remain = cdRemaining
                    Text(Self.format(remain, forceHours: true))
                        .font(DS.F.timerLg)
                        .monospacedDigit()
                        .kerning(-1)
                        .foregroundColor(model.cdFinished ? DS.danger : .primary)
                        .onChange(of: remain) { v in
                            if v <= 0 && !model.cdFinished && model.cdActive {
                                model.markCountdownFinished()
                            }
                        }
                }
                Text(model.cdFinished ? "时间到" : "倒计时")
                    .font(DS.F.microCaps)
                    .kerning(1.5)
                    .foregroundColor(model.cdFinished ? DS.danger : .secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(model.chipMinutes, id: \.self) { minutes in
                        countdownChip(minutes)
                    }
                }
                .padding(.horizontal, 24)
            }

            HStack(spacing: 14) {
                Button {
                    Haptic.medium()
                    model.startPauseResume()
                } label: {
                    Text(!model.cdActive ? "开始"
                         : (model.cdEnd != nil ? "暂停" : "继续"))
                        .font(DS.F.headline)
                        .foregroundColor(.white)
                        .frame(minWidth: 168, minHeight: DS.H.primaryButton)
                        .background(
                            Capsule()
                                .fill(DS.accent)
                                .shadow(color: DS.accent.opacity(0.26), radius: 20, y: 8)
                        )
                }
                .buttonStyle(PressStyle())

                if model.cdActive || model.cdFinished {
                    Button {
                        Haptic.light()
                        model.resetCountdown()
                    } label: {
                        Text("重置")
                            .font(DS.F.subheadSb)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 24)
                            .frame(minHeight: DS.H.primaryButton - 14)
                            .background(
                                Capsule()
                                    .stroke(Color.secondary.opacity(0.28), lineWidth: 1.2)
                            )
                    }
                    .buttonStyle(PressStyle())
                }
            }
        }
        .padding(.horizontal, 24)
    }

    private func countdownChip(_ minutes: Int) -> some View {
        let selected = model.cdMinutes == minutes
        return Button {
            Haptic.light()
            model.cdMinutes = minutes
        } label: {
            PillControl(isSelected: selected) {
                Text("\(minutes)分")
            }
        }
        .buttonStyle(PressStyle())
    }

    static func format(_ t: TimeInterval, forceHours: Bool = false) -> String {
        let s = max(0, Int(t))
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60, cs = Int((t - Double(s)) * 100)
        if h > 0 || forceHours {
            return String(format: "%d:%02d:%02d", h, m, sec)
        }
        return String(format: "%02d:%02d.%02d", m, sec, cs)
    }

    // MARK: 控件

    private func circularControl(icon: String,
                                 size: CGFloat,
                                 tint: Color,
                                 filled: Bool,
                                 action: @escaping () -> Void) -> some View {
        Button {
            if filled { Haptic.medium() } else { Haptic.light() }
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: size > 64 ? 25 : 19, weight: .medium))
                .foregroundColor(filled ? .white : tint)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(filled ? AnyShapeStyle(tint) : AnyShapeStyle(Color.clear))
                        .overlay(Circle().stroke(tint.opacity(filled ? 0 : 0.28), lineWidth: 1.5))
                        .shadow(color: filled ? tint.opacity(0.24) : .clear,
                                radius: size > 64 ? 20 : 10,
                                y: size > 64 ? 8 : 4)
                )
        }
        .buttonStyle(PressStyle())
    }
}

// MARK: - 状态模型（落盘）

/// 秒表/倒计时状态快照，杀后台恢复与番茄引擎同标准（墙钟派生不漂移）
final class FreeTimerModel: ObservableObject {

    static let shared = FreeTimerModel()
    private static let key = "freetimer.snapshot.v1"
    private let d = UserDefaults.standard

    let chipMinutes = [3, 5, 10, 15, 20, 30, 45, 60]

    @Published var swRunning = false { didSet { persist() } }
    @Published var swAccum: TimeInterval = 0 { didSet { persist() } }
    @Published var swStart: Date? { didSet { persist() } }
    @Published var laps: [TimeInterval] = [] { didSet { persist() } }

    @Published var cdMinutes = 10 { didSet { persist() } }
    @Published var cdEnd: Date? { didSet { persist() } }
    @Published var cdPausedRemain: TimeInterval? { didSet { persist() } }
    @Published var cdFinished = false { didSet { persist() } }

    private init() { restore() }

    var swElapsed: TimeInterval {
        swAccum + (swRunning ? Date().timeIntervalSince(swStart ?? Date()) : 0)
    }

    var cdRemaining: TimeInterval {
        guard let end = cdEnd else { return cdPausedRemain ?? TimeInterval(cdMinutes * 60) }
        return max(0, end.timeIntervalSince(Date()))
    }

    var cdActive: Bool { cdEnd != nil || cdPausedRemain != nil }

    func toggleRun() {
        if swRunning {
            swAccum = swElapsed
            swRunning = false
            swStart = nil
        } else {
            swStart = Date()
            swRunning = true
        }
    }

    func lapOrReset() {
        if swRunning {
            laps.insert(swElapsed, at: 0)
        } else if swElapsed > 0 {
            swAccum = 0
            swStart = nil
            laps = []
        } else {
            laps.insert(0, at: 0)
            swRunning = true
            swStart = Date()
        }
    }

    func removeLap(at i: Int) {
        guard laps.indices.contains(i) else { return }
        laps.remove(at: i)
    }

    func startPauseResume() {
        if cdActive {
            if cdEnd != nil {
                cdPausedRemain = cdRemaining
                cdEnd = nil
            } else {
                cdEnd = Date().addingTimeInterval(cdPausedRemain ?? 1)
            }
        } else {
            cdFinished = false
            cdPausedRemain = nil
            cdEnd = Date().addingTimeInterval(TimeInterval(cdMinutes * 60))
            Notifications.scheduleCountdown(in: cdMinutes * 60)
        }
    }

    func resetCountdown() {
        cdEnd = nil
        cdPausedRemain = nil
        cdFinished = false
        Notifications.cancelAll()
    }

    /// 自然走完：提示音 + 触觉 +（可选）计入今日统计
    func markCountdownFinished() {
        cdFinished = true
        SoundPlayer.shared.playTone(Prefs.shared.toneType)
        Haptic.medium()
        if Prefs.shared.countdownCounts, cdMinutes > 0 {
            Store.shared.record(phase: .focus, seconds: cdMinutes * 60,
                                start: Date().addingTimeInterval(-Double(cdMinutes * 60)),
                                completed: true,
                                taskId: FocusEngine.shared.currentTaskID)
            FocusEngine.shared.refreshToday()
        }
    }

    // MARK: 快照

    private func persist() {
        d.set(swRunning, forKey: key + ".swRunning")
        d.set(swAccum, forKey: key + ".swAccum")
        d.set(swStart?.timeIntervalSince1970 ?? 0, forKey: key + ".swStart")
        d.set(laps, forKey: key + ".laps")
        d.set(cdMinutes, forKey: key + ".cdMinutes")
        d.set(cdEnd?.timeIntervalSince1970 ?? 0, forKey: key + ".cdEnd")
        d.set(cdPausedRemain ?? -1, forKey: key + ".cdPaused")
        d.set(cdFinished, forKey: key + ".cdFinished")
    }

    private func restore() {
        swRunning = d.bool(forKey: key + ".swRunning")
        swAccum = d.object(forKey: key + ".swAccum") as? TimeInterval ?? 0
        let s = d.double(forKey: key + ".swStart")
        swStart = s > 0 ? Date(timeIntervalSince1970: s) : nil
        laps = d.object(forKey: key + ".laps") as? [TimeInterval] ?? []
        cdMinutes = d.object(forKey: key + ".cdMinutes") as? Int ?? 10
        let e = d.double(forKey: key + ".cdEnd")
        cdEnd = e > Date().timeIntervalSince1970 ? Date(timeIntervalSince1970: e) : nil
        let p = d.double(forKey: key + ".cdPaused")
        cdPausedRemain = p > 0 ? p : nil
        cdFinished = d.bool(forKey: key + ".cdFinished")
    }
}
