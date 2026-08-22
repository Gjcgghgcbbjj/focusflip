import SwiftUI

/// 主屏 —— Flow 式：任务色铺满全屏，圆环即一切。
struct HomeView: View {

    @ObservedObject private var engine = FocusEngine.shared
    @ObservedObject private var prefs = Prefs.shared

    @State private var showTaskPicker = false
    @State private var showTune = false
    @State private var showGiveUpConfirm = false
    @State private var homeMode = 0          // 0 番茄 / 1 自由
    @State private var bloom = false         // 阶段完成光晕
    @State private var settle: (minutes: Int, wasFocus: Bool)?

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

            // 阶段完成结算卡（全屏）
            if let done = engine.lastCompletion {
                SettleCard(info: done,
                           taskColor: baseColor,
                           todayCount: engine.todayPomodoros) {
                    engine.startPreparedPhase()
                    engine.lastCompletion = nil
                } later: {
                    engine.lastCompletion = nil
                }
                .transition(.opacity)
                .zIndex(10)
            }
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

    // MARK: 沉浸模式（计时中隐藏底部标签栏）

    private func applyImmersive() {
        guard prefs.immersive else { setTabBar(hidden: false); return }
        setTabBar(hidden: engine.isRunning)
    }

    private func setTabBar(hidden: Bool) {
        DispatchQueue.main.async {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            for scene in scenes {
                for window in scene.windows {
                    Self.walk(window.rootViewController) { vc in
                        guard let bar = (vc as? UITabBarController)?.tabBar else { return }
                        guard bar.superview != nil else { return }
                        UIView.animate(withDuration: 0.28, delay: 0,
                                       options: [.beginFromCurrentState, .curveEaseInOut]) {
                            bar.alpha = hidden ? 0 : 1
                            bar.frame.origin.y = hidden
                                ? UIScreen.main.bounds.height
                                : UIScreen.main.bounds.height - bar.frame.height
                        }
                    }
                }
            }
        }
    }

    private static func walk(_ vc: UIViewController?, _ visit: (UIViewController) -> Void) {
        guard let vc else { return }
        visit(vc)
        vc.children.forEach { walk($0, visit) }
    }

    private func fireBloom() {
        guard !bloom else { return }
        withAnimation(.easeOut(duration: 0.7)) { bloom = true }
        Haptic.medium()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            withAnimation(.easeIn(duration: 0.3)) { bloom = false }
        }
    }

    /// 自由模式在浅灰底上, 场景墨色不适用 → 双方案
    private var onScene: Bool { homeMode == 0 }

    private var segContainerBg: Color {
        onScene ? Palette.panel(baseColor) : Color.black.opacity(0.06)
    }
    private var segSelectedBg: Color {
        onScene ? Color.white : DS.accent
    }
    private func segText(selected: Bool) -> Color {
        if selected { return onScene ? Palette.deepVariant(baseColor) : .white }
        return onScene ? fg : .primary.opacity(0.55)
    }

    private var modeSwitch: some View {
        HStack(spacing: 4) {
            segButton("番茄", 0)
            segButton("自由", 1)
        }
        .padding(4)
        .background(Capsule().fill(segContainerBg))
        .animation(.easeInOut(duration: 0.25), value: homeMode)
    }

    private func segButton(_ t: String, _ i: Int) -> some View {
        let selected = homeMode == i
        return Button {
            withAnimation(.easeInOut(duration: 0.25)) { homeMode = i }
            Haptic.tick()
        } label: {
            Text(t)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(segText(selected: selected))
                .padding(.horizontal, 22)
                .frame(height: 34)
                .background(Capsule().fill(selected ? AnyShapeStyle(segSelectedBg)
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
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(fg)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(fgSoft)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
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
                    .scaleEffect(bloom ? 1.12 : 1.0)
                    .opacity(bloom ? 0.35 : 1)

                if bloom {
                    Circle()
                        .stroke(fg.opacity(0.55), lineWidth: Layout.ringWidth)
                        .scaleEffect(1.18)
                }

                VStack(spacing: 6) {
                    Text(modeLabel)
                        .font(.system(size: 13, weight: .medium))
                        .kerning(2)
                        .foregroundColor(fgSoft)
                    Text(timeText(remaining))
                        .font(DS.F.display)
                        .monospacedDigit()
                        .kerning(-1)
                        .foregroundColor(fg)
                        .scaleEffect(bloom ? 1.05 : 1.0)
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
                        .onChange(of: engine.phase) { _ in fireBloom() }
            .onAppear { applyImmersive() }
            .onDisappear { setTabBar(hidden: false) }
            .onChange(of: engine.isRunning) { _ in applyImmersive() }
            .contextMenu {
                if engine.isRunning {
                    Button { Haptic.tick(); engine.pause() } label: {
                        Label("暂停", systemImage: "pause.fill")
                    }
                } else if engine.isPaused {
                    Button { Haptic.tick(); engine.resume() } label: {
                        Label("继续", systemImage: "play.fill")
                    }
                }
                if !engine.isPlanning {
                    Button { Haptic.tick(); engine.skip() } label: {
                        Label("跳过此阶段", systemImage: "forward.fill")
                    }
                }
                if engine.isRunning || engine.isPaused {
                    Button(role: .destructive) { showGiveUpConfirm = true } label: {
                        Label("放弃专注", systemImage: "xmark.circle")
                    }
                }
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
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(fgSoft)
                        .frame(width: 44, height: 37)
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
                .font(.system(size: 16, weight: selected ? .bold : .medium))
                .monospacedDigit()
                .foregroundColor(selected ? Palette.deepVariant(baseColor) : fgSoft)
                .padding(.horizontal, 19)
                .frame(height: 37)
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
                        .font(DS.F.headline)
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
                Text("放弃")
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Palette.panel(baseColor)))
            }
            Spacer()
            Button {
                Haptic.tick()
                engine.skip()
            } label: {
                Text("跳过")
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Palette.panel(baseColor)))
            }
        }
        .foregroundColor(fg)
        .padding(.horizontal, 48)
    }
}

// MARK: - 按压反馈

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7),
                       value: configuration.isPressed)
    }
}

enum Haptic {
    static func tick() { UISelectionFeedbackGenerator().selectionChanged() }
    static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
