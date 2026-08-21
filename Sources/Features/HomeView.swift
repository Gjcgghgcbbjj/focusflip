import SwiftUI

/// 主屏 —— Flow 式：任务色铺满全屏，圆环即一切。
struct HomeView: View {

    @ObservedObject private var engine = FocusEngine.shared
    @ObservedObject private var prefs = Prefs.shared

    @State private var showTaskPicker = false
    @State private var showTune = false
    @State private var showGiveUpConfirm = false
    @State private var showSound = false
    @State private var showCountdown = false
    @State private var countdowns: [CountdownEntity] = []

    // MARK: 底色（Flow 核心：色随内容）

    private var baseColor: Color {
        if let p = engine.phase, p != .focus {
            return p == .longBreak ? Palette.longBreakBase : Palette.shortBreakBase
        }
        if let hex = engine.currentTaskColorHex.isEmpty ? nil : engine.currentTaskColorHex {
            return Color(hex: hex)
        }
        return Palette.defaultBase
    }

    /// 用于动画的状态键（阶段变化时整屏颜色平滑过渡）
    private var phaseKey: String {
        let p = engine.phase.map { $0.rawValue } ?? "idle"
        return p + engine.currentTaskColorHex
    }

    var body: some View {
        ZStack {
            Palette.sceneGradient(baseColor)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.6), value: phaseKey)

            VStack(spacing: 0) {
                countdownStrip
                    .padding(.horizontal, 20)
                    .padding(.bottom, 4)
                content
                    .overlay(alignment: .topTrailing) {
                        soundButton
                            .padding(.trailing, 20)
                            .padding(.top, 6)
                    }
            }
        }
        .onAppear {
            engine.refreshToday()
            countdowns = Store.shared.countdowns()
        }
        .onChange(of: showCountdown) { open in
            if !open { countdowns = Store.shared.countdowns() }
        }
        .onChange(of: engine.isRunning) { running in
            UIApplication.shared.isIdleTimerDisabled = running && prefs.keepAwake
        }
        .sheet(isPresented: $showTaskPicker) { TaskPickerSheet() }
        .sheet(isPresented: $showTune) { DurationTuneSheet() }
        .sheet(isPresented: $showSound) { SoundSheet() }
        .sheet(isPresented: $showCountdown) { CountdownSheet() }
        .confirmationDialog("放弃这次专注？", isPresented: $showGiveUpConfirm,
                            titleVisibility: .visible) {
            Button("放弃", role: .destructive) { engine.giveUp() }
            Button("继续专注", role: .cancel) {}
        }
    }

    // MARK: 内容布局

    private var content: some View {
        VStack(spacing: 0) {
            taskHeader
                .padding(.top, 8)

            Spacer(minLength: 12)

            ringBlock
            ringHint

            Spacer(minLength: 16)

            if engine.isPlanning {
                durationChips
                    .padding(.bottom, 20)
            }

            mainButton

            if engine.isRunning || engine.isPaused {
                sideControls
                    .padding(.top, 18)
            }

            Spacer(minLength: 28)
        }
    }

    // MARK: 声音入口

    private var soundButton: some View {
        Button {
            Haptic.tick()
            showSound = true
        } label: {
            Image(systemName: prefs.soundType == "none" ? "speaker.slash" : "speaker.wave.2")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.white.opacity(0.16)))
        }
        .buttonStyle(PressStyle())
    }

    // MARK: 日期倒计时条（常驻入口：没有目标时也能点进添加）

    private var nearestCountdown: CountdownEntity? {
        countdowns.first { CountdownSheet.daysLeft($0.targetDate) >= 0 }
    }

    @ViewBuilder
    private var countdownStrip: some View {
        if let cd = nearestCountdown {
            countdownBanner(cd)
        } else if !countdowns.isEmpty {
            ghostRow("日期倒计时 · 全部已过期")
        } else {
            ghostRow("＋ 添加日期倒计时")
        }
    }

    private func ghostRow(_ text: String) -> some View {
        Button {
            Haptic.tick(); showCountdown = true
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.75))
                Text(text)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.75))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.45))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1))
        }
        .buttonStyle(PressStyle())
    }

    private func countdownBanner(_ c: CountdownEntity) -> some View {
        let days = CountdownSheet.daysLeft(c.targetDate)
        return Button {
            Haptic.tick(); showCountdown = true
        } label: {
            HStack(spacing: 8) {
                Circle().fill(Color(hex: c.colorHex)).frame(width: 7, height: 7)
                Text(c.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.95))
                    .lineLimit(1)
                Spacer()
                Text(days == 0 ? "就是今天" : "剩 \(days) 天")
                    .font(.system(size: 12, weight: .bold))
                    .monospacedDigit()
                    .foregroundColor(days <= 7 ? Color(hex: "#FFD60A") : .white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.white.opacity(0.16)))
        }
        .buttonStyle(PressStyle())
    }

    // MARK: 任务头

    private var taskHeader: some View {
        Button {
            showTaskPicker = true
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(hex: engine.currentTaskColorHex.isEmpty
                                ? "#FFFFFF" : engine.currentTaskColorHex))
                    .frame(width: 8, height: 8)
                    .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 1))
                Text(engine.currentTaskName.isEmpty ? "选择任务" : engine.currentTaskName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.white.opacity(0.16)))
        }
        .buttonStyle(PressStyle())
    }

    // MARK: 圆环

    private var ringBlock: some View {
        TimelineView(.animation) { ctx in
            let remaining = engine.remaining(at: ctx.date)
            let fraction = displayFraction(remaining: remaining)
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.25), lineWidth: Layout.ringWidth)
                Circle()
                    .trim(from: 0, to: max(0.001, fraction))
                    .stroke(Color.white,
                            style: StrokeStyle(lineWidth: Layout.ringWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: .black.opacity(0.15), radius: 10)

                VStack(spacing: 6) {
                    Text(modeLabel)
                        .font(.system(size: 13, weight: .medium))
                        .kerning(2)
                        .foregroundColor(.white.opacity(0.85))
                    Text(timeText(remaining))
                        .font(.system(size: 56, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .kerning(-1)
                        .foregroundColor(.white)
                        .animation(.easeInOut(duration: 0.25), value: remaining)
                }
            }
            .frame(width: Layout.ringSize, height: Layout.ringSize)
            .contentShape(Rectangle())
            .onTapGesture {
                guard engine.isRunning || engine.isPaused else { return }
                Haptic.tick()
                engine.togglePause()
            }
        }
    }

    private var ringHint: some View {
        Group {
            if engine.isRunning || engine.isPaused {
                Text("点按圆环暂停 / 继续")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.55))
            } else {
                EmptyView()
            }
        }
        .padding(.top, 14)
        .frame(height: 26)
    }

    private func displayFraction(remaining: Int) -> Double {
        guard total > 0 else { return 0 }
        switch engine.state {
        case .prepared:
            return 0                       // 开始页：空环展示即将开始的时长
        case .paused(let p) where p == .focus && total == 0:
            return 0
        default:
            return Double(total - remaining) / Double(total)
        }
    }

    private var total: Int { engine.totalSeconds }

    private var modeLabel: String {
        switch engine.state {
        case .idle: return "准备开始"
        case .running(let p): return p.label
        case .paused(let p): return "已暂停 · \(p.label)"
        case .prepared(let p): return p == .focus ? "下一个 · 专注" : "该\(p.label)了"
        }
    }

    private func timeText(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec)
                     : String(format: "%02d:%02d", m, sec)
    }

    // MARK: 时长快选（Flow 式 chips）

    private let chipMinutes = [15, 20, 25, 30, 45, 50, 60]

    private var durationChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chipMinutes, id: \.self) { m in
                    chip(m)
                }
                if !chipMinutes.contains(prefs.focusMinutes) {
                    chip(prefs.focusMinutes)
                }
                Button {
                    Haptic.tick()
                    showTune = true
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(width: 36, height: 32)
                        .background(Capsule().stroke(Color.white.opacity(0.35), lineWidth: 1))
                }
                .buttonStyle(PressStyle())
            }
            .padding(.horizontal, 32)
        }
    }

    private func chip(_ m: Int) -> some View {
        let selected = m == prefs.focusMinutes
        return Button {
            Haptic.tick()
            prefs.focusMinutes = m
        } label: {
            Text("\(m)")
                .font(.system(size: 15, weight: selected ? .semibold : .regular))
                .monospacedDigit()
                .foregroundColor(selected ? Palette.deepVariant(baseColor) : .white.opacity(0.9))
                .padding(.horizontal, 16)
                .frame(height: 32)
                .background(
                    Capsule().fill(selected ? AnyShapeStyle(Color.white)
                                            : AnyShapeStyle(Color.white.opacity(0.14)))
                )
        }
        .buttonStyle(PressStyle())
    }

    // MARK: 主按钮

    private var mainButton: some View {
        Group {
            switch engine.state {
            case .running:
                circleButton(icon: "pause.fill") { engine.pause() }
            case .paused:
                circleButton(icon: "play.fill") { engine.resume() }
            default:
                Button {
                    Haptic.medium()
                    if case .prepared(let p) = engine.state, p != .focus {
                        engine.startPreparedPhase()
                    } else {
                        engine.startFocus()
                    }
                } label: {
                    Text(mainTitle)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Palette.deepVariant(baseColor))
                        .padding(.horizontal, 46)
                        .frame(height: 54)
                        .background(Capsule().fill(Color.white))
                        .shadow(color: .black.opacity(0.18), radius: 14, y: 4)
                }
                .buttonStyle(PressStyle())
            }
        }
    }

    private var mainTitle: String {
        if case .prepared(let p) = engine.state, p != .focus {
            return "开始\(p.label)"
        }
        return "开始专注"
    }

    private func circleButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: { Haptic.medium(); action() }) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .medium))
                .foregroundColor(Palette.deepVariant(baseColor))
                .frame(width: 74, height: 74)
                .background(Circle().fill(Color.white))
                .shadow(color: .black.opacity(0.18), radius: 14, y: 4)
        }
        .buttonStyle(PressStyle())
    }

    // MARK: 放弃 / 跳过

    private var sideControls: some View {
        HStack {
            Button {
                if engine.phase == .focus { showGiveUpConfirm = true }
                else { engine.skip() }
            } label: {
                Text("放弃").font(.system(size: 14))
            }
            Spacer()
            Button {
                Haptic.tick()
                engine.skip()
            } label: {
                Text("跳过").font(.system(size: 14))
            }
        }
        .foregroundColor(.white.opacity(0.85))
        .padding(.horizontal, 56)
    }
}

// MARK: - 按压反馈

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

enum Haptic {
    static func tick() { UISelectionFeedbackGenerator().selectionChanged() }
    static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
}
