import SwiftUI

/// 自由计时器 —— 秒表 / 任意倒计时（不进番茄流程）
struct FreeTimerView: View {

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
        NavigationView {
            VStack(spacing: 0) {
                Picker("模式", selection: $mode.animation()) {
                    ForEach(Mode.allCases) { m in Text(m.label).tag(m) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Spacer()

                switch mode {
                case .stopwatch: stopwatchBody
                case .countdown: countdownBody
                }

                Spacer()
            }
            .navigationTitle("自由计时")
            .navigationBarTitleDisplayMode(.inline)
        }
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
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(laps.indices.reversed(), id: \.self) { i in
                            HStack {
                                Text("Lap \(i + 1)")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(Self.format(laps[i]))
                                    .font(.system(size: 14).monospacedDigit())
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(.secondarySystemGroupedBackground)))
                        }
                    }
                }
                .frame(maxHeight: 190)
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
                                    .font(.system(size: 14, weight: cdMinutes == m ? .semibold : .regular))
                                    .monospacedDigit()
                                    .foregroundColor(cdMinutes == m ? .white : Color(hex: "#5865F2"))
                                    .padding(.horizontal, 14).frame(height: 30)
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
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
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

    static func format(_ t: TimeInterval, forceHours: Bool = false) -> String {
        let s = max(0, Int(t))
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60, cs = Int((t - Double(s)) * 100)
        if h > 0 || forceHours {
            return String(format: "%d:%02d:%02d", h, m, sec)
        }
        return String(format: "%02d:%02d.%02d", m, sec, cs)
    }
}
