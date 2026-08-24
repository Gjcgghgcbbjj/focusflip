import SwiftUI

/// 自由计时面板 —— 与专注主控共用一套计时/按钮语言。
struct FreeTimerPane: View {

    private enum Mode: Int, CaseIterable, Identifiable {
        case stopwatch = 0, countdown
        var id: Int { rawValue }
        var label: String { self == .stopwatch ? "秒表" : "倒计时" }
    }

    @State private var mode: Mode = .stopwatch

    // 秒表：startedAt + accumulated 是唯一真相源。
    @State private var swRunning = false
    @State private var swStart: Date?
    @State private var swAccum: TimeInterval = 0
    @State private var laps: [TimeInterval] = []

    // 倒计时：end/remain 沿用墙钟派生，后台不漂移。
    @State private var cdMinutes = 10
    @State private var cdEnd: Date?
    @State private var cdPausedRemain: TimeInterval?
    @State private var cdFinished = false

    private let chipMinutes = [3, 5, 10, 15, 20, 30, 45, 60]

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

    private var swElapsed: TimeInterval {
        swAccum + (swRunning ? Date().timeIntervalSince(swStart ?? Date()) : 0)
    }

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
                circularControl(icon: swRunning ? "pause.fill" : "play.fill",
                                size: DS.H.circleMain,
                                tint: DS.accent,
                                filled: true) {
                    if swRunning {
                        swAccum = swElapsed
                        swRunning = false
                        swStart = nil
                    } else {
                        swStart = Date()
                        swRunning = true
                    }
                }

                circularControl(icon: swRunning ? "flag.fill"
                                      : (swElapsed > 0 ? "arrow.counterclockwise" : "play.fill"),
                                size: 56,
                                tint: swElapsed > 0 || swRunning ? DS.danger : DS.accent,
                                filled: false) {
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
            }

            if !laps.isEmpty {
                lapList
            }
        }
        .padding(.horizontal, 24)
    }

    private var lapList: some View {
        let fastest = laps.min()
        let slowest = laps.count > 1 ? laps.max() : nil

        return ScrollView {
            VStack(spacing: 0) {
                ForEach(laps.indices.reversed(), id: \.self) { i in
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
        let isFast = laps[i] == fastest && laps.count > 1
        let isSlow = laps[i] == slowest && laps.count > 1
        let color: Color = isFast ? DS.success : isSlow ? DS.danger : .primary

        return HStack(spacing: DS.S.md) {
            Text(isFast ? "最快" : isSlow ? "最慢" : "Lap \(i + 1)")
                .font(DS.F.subheadSb)
                .foregroundColor(isFast || isSlow ? color : .secondary)
            Spacer()
            Text(Self.format(laps[i]))
                .font(DS.F.bodySb.monospacedDigit())
                .foregroundColor(color)
        }
        .padding(.horizontal, DS.S.lg)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .contextMenu {
            Button(role: .destructive) {
                withAnimation(DS.Motion.quick) {
                    _ = laps.remove(at: i)
                }
                Haptic.light()
            } label: {
                Label("删除此计次", systemImage: "trash")
            }
        }
    }

    // MARK: 倒计时

    private var cdRemaining: TimeInterval {
        guard let end = cdEnd else { return cdPausedRemain ?? TimeInterval(cdMinutes * 60) }
        return max(0, end.timeIntervalSince(Date()))
    }

    private var countdownBody: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                TimelineView(.animation) { _ in
                    let remain = cdRemaining
                    Text(Self.format(remain, forceHours: true))
                        .font(DS.F.timerLg)
                        .monospacedDigit()
                        .kerning(-1)
                        .foregroundColor(cdFinished ? DS.danger : .primary)
                        .onChange(of: remain) { v in
                            if v <= 0 && !cdFinished && (cdEnd != nil || cdPausedRemain != nil) {
                                cdFinished = true
                                SoundPlayer.shared.playTone(Prefs.shared.toneType)
                                Haptic.medium()
                            }
                        }
                }
                Text(cdFinished ? "时间到" : "倒计时")
                    .font(DS.F.microCaps)
                    .kerning(1.5)
                    .foregroundColor(cdFinished ? DS.danger : .secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(chipMinutes, id: \.self) { minutes in
                        countdownChip(minutes)
                    }
                }
                .padding(.horizontal, 24)
            }

            HStack(spacing: 14) {
                Button {
                    Haptic.medium()
                    if cdRunningOrPaused {
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
                } label: {
                    Text(!cdRunningOrPaused ? "开始"
                         : (cdEnd != nil ? "暂停" : "继续"))
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

                if cdRunningOrPaused || cdFinished {
                    Button {
                        Haptic.light()
                        cdEnd = nil
                        cdPausedRemain = nil
                        cdFinished = false
                        Notifications.cancelAll()
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
        let selected = cdMinutes == minutes
        return Button {
            Haptic.light()
            cdMinutes = minutes
        } label: {
            PillControl(isSelected: selected) {
                Text("\(minutes)分")
            }
        }
        .buttonStyle(PressStyle())
    }

    private var cdRunningOrPaused: Bool { cdEnd != nil || cdPausedRemain != nil }

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
