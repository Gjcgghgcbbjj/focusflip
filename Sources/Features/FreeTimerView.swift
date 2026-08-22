import SwiftUI

/// 自由计时面板 —— 嵌入专注页「自由」模式
struct FreeTimerPane: View {

    private enum Mode: Int, CaseIterable, Identifiable {
        case stopwatch = 0, countdown
        var id: Int { rawValue }
        var label: String { self == .stopwatch ? "秒表" : "倒计时" }
    }

    @State private var mode: Mode = .stopwatch

    // 秒表
    @State private var swRunning = false
    @State private var swStart: Date?
    @State private var swAccum: TimeInterval = 0     // 暂停累计
    @State private var laps: [TimeInterval] = []

    // 倒计时
    @State private var cdMinutes = 10
    @State private var cdEnd: Date?
    @State private var cdPausedRemain: TimeInterval?
    @State private var cdFinished = false

    private let chipMinutes = [3, 5, 10, 15, 20, 30, 45, 60]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 30) {
                underTab("秒表", mode == .stopwatch)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.22)) { mode = .stopwatch }
                        Haptic.tick()
                    }
                underTab("倒计时", mode == .countdown)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.22)) { mode = .countdown }
                        Haptic.tick()
                    }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 14)

            Spacer()

            switch mode {
            case .stopwatch: stopwatchBody
            case .countdown: countdownBody
            }

            Spacer()
        }
    }

    private func underTab(_ title: String, _ selected: Bool) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(DS.F.bodySb)
                .foregroundColor(selected ? DS.accent : .secondary)
            Capsule()
                .fill(selected ? DS.accent : Color.clear)
                .frame(width: 26, height: 3)
        }
        .frame(minHeight: DS.H.touchMin - 8)
        .contentShape(Rectangle())
    }

    // MARK: 秒表

    private var swElapsed: TimeInterval {
        swAccum + (swRunning ? Date().timeIntervalSince(swStart ?? Date()) : 0)
    }

    private var stopwatchBody: some View {
        VStack(spacing: 28) {
            TimelineView(.animation(minimumInterval: 0.05)) { _ in
                Text(Self.format(swElapsed))
                    .font(.system(size: 62, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .kerning(-1)
            }

            HStack(spacing: 14) {
                Button {
                    Haptic.medium()
                    if swRunning {
                        swAccum = swElapsed; swRunning = false; swStart = nil
                    } else {
                        swStart = Date(); swRunning = true
                    }
                } label: {
                    Image(systemName: swRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 76, height: 76)
                        .background(Circle().fill(Color(hex: "#5865F2")))
                        .shadow(color: Color(hex: "#5865F2").opacity(0.35),
                                radius: 14, y: 6)
                }

                Button {
                    Haptic.tick()
                    if swRunning { laps.insert(swElapsed, at: 0) }
                    else if swElapsed > 0 { swAccum = 0; swStart = nil; laps = [] }
                    else { laps.insert(0, at: 0); swRunning = true; swStart = Date() }
                } label: {
                    Image(systemName: swRunning ? "flag.fill"
                          : (swElapsed > 0 ? "arrow.counterclockwise" : "play.fill"))
                        .font(.system(size: 19, weight: .medium))
                        .foregroundColor(swElapsed > 0 || swRunning ? Color(hex: "#E5573F") : Color(hex: "#5865F2"))
                        .frame(width: 56, height: 56)
                        .background(Circle()
                            .stroke((swElapsed > 0 || swRunning
                                     ? Color(hex: "#E5573F") : Color(hex: "#5865F2"))
                                    .opacity(0.30), lineWidth: 1.5))
                }
            }

            if !laps.isEmpty {
                let fastest = laps.min()
                let slowest = laps.count > 1 ? laps.max() : nil
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(laps.indices.reversed(), id: \.self) { i in
                            HStack {
                                Text(laps[i] == fastest && laps.count > 1 ? "最快"
                                     : laps[i] == slowest ? "最慢"
                                     : "Lap \(i + 1)")
                                    .font(DS.F.subhead)
                                    .foregroundColor(laps[i] == fastest && laps.count > 1
                                                     ? Color(hex: "#2FA84F")
                                                     : laps[i] == slowest
                                                     ? Color(hex: "#E5573F") : .secondary)
                                Spacer()
                                Text(Self.format(laps[i]))
                                    .font(DS.F.bodyMd.monospacedDigit())
                                    .foregroundColor(laps[i] == fastest && laps.count > 1
                                                     ? Color(hex: "#2FA84F")
                                                     : laps[i] == slowest
                                                     ? Color(hex: "#E5573F") : .primary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 11)
                            .contentShape(Rectangle())
                            .contextMenu {
                                Button(role: .destructive) {
                                    withAnimation(.easeOut(duration: 0.22)) {
                                        _ = laps.remove(at: i)
                                    }
                                    Haptic.tick()
                                } label: {
                                    Label("删除此计次", systemImage: "trash")
                                }
                            }
                            if i > 0 { Divider() }
                        }
                    }
                }
                .frame(maxHeight: 190)
                .background(
                    RoundedRectangle(cornerRadius: DS.R.card, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground)))
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: 倒计时

    private var cdRemaining: TimeInterval {
        guard let end = cdEnd else { return cdPausedRemain ?? TimeInterval(cdMinutes * 60) }
        return max(0, end.timeIntervalSince(Date()))
    }

    private var countdownBody: some View {
        VStack(spacing: 26) {
            TimelineView(.animation) { _ in
                let remain = cdRemaining
                Text(Self.format(remain, forceHours: true))
                    .font(.system(size: 62, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .kerning(-1)
                    .foregroundColor(cdFinished ? Color(hex: "#E5573F") : .primary)
                    .onChange(of: remain) { v in
                        if v <= 0 && !cdFinished && (cdEnd != nil || cdPausedRemain != nil) {
                            cdFinished = true
                            SoundPlayer.shared.playTone(Prefs.shared.toneType)
                            Haptic.medium()
                        }
                    }
            }

            if !cdRunningOrPaused {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(chipMinutes, id: \.self) { m in
                            Button {
                                Haptic.tick(); cdMinutes = m
                            } label: {
                                Text("\(m)分")
                                    .font(.system(size: 15, weight: cdMinutes == m ? .bold : .medium))
                                    .monospacedDigit()
                                    .foregroundColor(cdMinutes == m ? .white : Color(hex: "#5865F2"))
                                    .padding(.horizontal, 17).frame(height: 35)
                                    .background(Capsule().fill(cdMinutes == m ? AnyShapeStyle(Color(hex: "#5865F2"))
                                                                              : AnyShapeStyle(Color(hex: "#5865F2").opacity(0.12))))
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }

            HStack(spacing: 14) {
                Button {
                    Haptic.medium()
                    if cdRunningOrPaused {
                        if cdEnd != nil { cdPausedRemain = cdRemaining; cdEnd = nil }
                        else { cdEnd = Date().addingTimeInterval(cdPausedRemain ?? 1) }
                    } else {
                        cdFinished = false
                        cdPausedRemain = nil
                        cdEnd = Date().addingTimeInterval(TimeInterval(cdMinutes * 60))
                        Notifications.schedule(in: cdMinutes * 60, phase: .focus, taskName: "倒计时")
                    }
                } label: {
                    Text(!cdRunningOrPaused ? "开始"
                         : (cdEnd != nil ? "暂停" : "继续"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 38).frame(height: 52)
                        .background(Capsule().fill(Color(hex: "#5865F2")))
                        .shadow(color: Color(hex: "#5865F2").opacity(0.35), radius: 14, y: 6)
                }

                if cdRunningOrPaused || cdFinished {
                    Button {
                        Haptic.tick()
                        cdEnd = nil; cdPausedRemain = nil; cdFinished = false
                        Notifications.cancelAll()
                    } label: {
                        Text("重置")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 11)
                            .background(Capsule().stroke(Color.secondary.opacity(0.4), lineWidth: 1.2))
                    }
                }
            }

            if cdFinished {
                Text("时间到 ✅").font(.system(size: 13)).foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 24)
    }

    private var cdRunningOrPaused: Bool { cdEnd != nil || cdPausedRemain != nil }

    /// 统计页同款时间卡：大数字 + 状态副标题
    private func timeCard<Content: View>(caption: String,
                                         tint: Color? = nil,
                                         @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 10) {
            content()
            Text(caption)
                .font(DS.F.microCaps)
                .kerning(1.5)
                .foregroundColor(tint ?? .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(
            RoundedRectangle(cornerRadius: DS.R.card, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    static func format(_ t: TimeInterval, forceHours: Bool = false) -> String {
        let s = max(0, Int(t))
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60, cs = Int((t - Double(s)) * 100)
        if h > 0 || forceHours {
            return String(format: "%d:%02d:%02d", h, m, sec)
        }
        return String(format: "%02d:%02d.%02d", m, sec, cs)
    }
}
