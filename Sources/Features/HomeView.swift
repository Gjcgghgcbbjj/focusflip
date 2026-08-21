import SwiftUI

/// 主屏 —— Flow 式：任务色铺满全屏，圆环即一切。
struct HomeView: View {

    @ObservedObject private var engine = FocusEngine.shared
    @ObservedObject private var prefs = Prefs.shared

    @State private var showTaskPicker = false
    @State private var showTune = false
    @State private var showGiveUpConfirm = false
    @State private var homeMode = 0          // 0 番茄 / 1 自由

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

    private var fg: Color { Palette.ink(baseColor) }
    private var fgSoft: Color { Palette.inkSoft(baseColor) }

    /// 用于动画的状态键（阶段变化时整屏颜色平滑过渡）
    private var phaseKey: String {
        let p = engine.phase.map { $0.rawValue } ?? "idle"
        return p + engine.currentTaskColorHex
    }

    var body: some View {
        ZStack {
            if homeMode == 0 {
                Palette.sceneGradient(baseColor)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.6), value: phaseKey)
            } else {
                Color.clear
            }

            VStack(spacing: 0) {
                modeSwitch
                    .padding(.top, 10)

                if homeMode == 0 {
                    content
                        .padding(.top, 8)
                } else {
                    ZStack {
                        Color(.systemGroupedBackground)
                            .ignoresSafeArea()
                        VStack(spacing: 0) {
                            Text("自 由 计 时")
                                .font(.system(size: 11, weight: .semibold))
                                .kerning(2)
                                .foregroundColor(.secondary)
                                .padding(.top, 14)
                            FreeTimerPane()
                        }
                    }
                }
            }
        }
        .onAppear { engine.refreshToday() }
        .onChange(of: engine.isRunning) { running in
            UIApplication.shared.isIdleTimerDisabled = running && prefs.keepAwake
        }
        .sheet(isPresented: $showTaskPicker) { TaskPickerSheet() }
        .sheet(isPresented: $showTune) { DurationTuneSheet() }
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
                .padding(.top, 14)

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

    // MARK: 番茄/自由 模式切换

    private var modeSwitch: some View {
        HStack(spacing: 4) {
            segButton("番茄", 0)
            segButton("自由", 1)
        }
        .padding(3)
        .background(Capsule().fill(Palette.panel(baseColor)))
        .animation(.easeInOut(duration: 0.25), value: homeMode)
        .animation(.easeInOut(duration: 0.25), value: homeMode)
    }

    private func segButton(_ t: String, _ i: Int) -> some View {
        let selected = homeMode == i
        return Button {
            withAnimation(.easeInOut(duration: 0.25)) { homeMode = i }
            Haptic.tick()
        } label: {
            Text(t)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(selected ? Palette.deepVariant(baseColor) : fg)
                .padding(.horizontal, 20)
                .frame(height: 30)
                .background(Capsule().fill(selected ? AnyShapeStyle(Color.white)
                                                    : AnyShapeStyle(Color.clear)))
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
                    .foregroundColor(fg)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(fgSoft)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Palette.panel(baseColor)))
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
                    .stroke(fg.opacity(0.25), lineWidth: Layout.ringWidth)
                Circle()
                    .trim(from: 0, to: max(0.001, fraction))
                    .stroke(fg,
                            style: StrokeStyle(lineWidth: Layout.ringWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 6) {
                    Text(modeLabel)
                        .font(.system(size: 13, weight: .medium))
                        .kerning(2)
                        .foregroundColor(fgSoft)
                    Text(timeText(remaining))
                        .font(.system(size: 56, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .kerning(-1)
                        .foregroundColor(fg)
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
                    .foregroundColor(fgSoft)
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
                        .foregroundColor(fgSoft)
                        .frame(width: 36, height: 32)
                        .background(Capsule().stroke(fgSoft.opacity(0.6), lineWidth: 1))
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
                .foregroundColor(selected ? Palette.deepVariant(baseColor) : fgSoft)
                .padding(.horizontal, 16)
                .frame(height: 32)
                .background(
                    Capsule().fill(selected ? AnyShapeStyle(Color.white)
                                            : AnyShapeStyle(Palette.panel(baseColor)))
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
        .foregroundColor(fgSoft)
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
