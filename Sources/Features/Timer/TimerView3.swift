import SwiftUI

/// FocusFlip 3.0 — 计时页。
///
/// 设计原则：
/// - 圆环是唯一主角，撑满宽度
/// - 数字超细体居中，与环同一时间源（无漂移）
/// - 阶段色只出现在环/主按钮/状态点上，其余全部黑白灰
/// - 暂停时环轻微"呼吸"，暗示可继续
struct TimerView3: View {

    @ObservedObject private var engine = PomodoroEngine.shared
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var sound = SoundPlayer.shared
    @Environment(\.colorScheme) private var colorScheme

    private var pal: DS3.ScenePalette { .scene(colorScheme) }

    @State private var showTaskPicker = false
    @State private var selectedTask: TaskItem?
    @State private var showCelebration = false
    @State private var showClock = false
    @State private var showInterruptDialog = false
    @State private var showDurationSheet = false

    var body: some View {
        ZStack {
            DS3.Color.bg.ignoresSafeArea()
            PhaseTheme3.sceneBackground(for: engine.currentSessionType, scheme: colorScheme)
                .animation(DS3.Anim.gentle, value: engine.currentSessionType)

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, DS3.S.lg)
                    .padding(.top, DS3.S.md)

                Spacer(minLength: DS3.S.sm)

                ringArea
                    .padding(.horizontal, DS3.S.xl)

                Spacer(minLength: DS3.S.sm)

                todayStrip
                taskChip
                    .padding(.top, DS3.S.sm)
                if isIdleState {
                    durationChips
                        .padding(.top, DS3.S.sm)
                }
                if engine.isRunning && !engine.isFreeFocus {
                    Button(action: extendPhase) {
                        Label("加 5 分钟", systemImage: "plus")
                            .font(DS3.Font.caption.weight(.medium))
                            .foregroundColor(theme.color)
                            .padding(.horizontal, DS3.S.md)
                            .padding(.vertical, DS3.S.xs + 2)
                            .background(Capsule().fill(theme.color.opacity(0.12)))
                    }
                    .pressable3()
                    .padding(.top, DS3.S.sm)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
                controls
                    .padding(.top, DS3.S.lg)

                if isIdleState {
                    Button {
                        HapticManager.shared.light()
                        engine.startFreeFocus()
                        if settings.whiteNoiseEnabled { sound.playWhiteNoise() }
                    } label: {
                        Text("或开始自由专注（正计时）")
                            .font(DS3.Font.caption)
                            .foregroundColor(pal.dim)
                            .padding(.top, DS3.S.sm)
                    }
                    .pressable3()
                }

                if showBreakSuggestion {
                    breakSuggestionCard
                        .padding(.top, DS3.S.md)
                }
                Spacer(minLength: 0)
                .padding(.bottom, DS3.S.xxl)
            }
        }
        .onAppear {
            NotificationService.shared.requestPermission()
            engine.refreshTodayStats()
            applyKeepAwake()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: engine.isRunning) { _ in applyKeepAwake() }
        .onReceive(engine.$state) { onState($0) }
        .overlay { celebrationOverlay }
        .sheet(isPresented: $showTaskPicker) {
            TaskPickerSheet3(selectedTask: $selectedTask)
        }
        .fullScreenCover(isPresented: $showClock) {
            ClockView3()
        }
        .sheet(isPresented: $showDurationSheet) {
            DurationTuneSheet()
        }
        .confirmationDialog("为什么中断这次专注？",
                            isPresented: $showInterruptDialog, titleVisibility: .visible) {
            ForEach(InterruptReason.all) { r in
                Button(r.label) {
                    engine.skip(interruptReason: r.label)
                }
            }
            Button("不记原因，直接跳过", role: .cancel) {
                engine.skip()
            }
        }
    }

    // MARK: Header

    private var theme: PhaseTheme3 { PhaseTheme3.theme(for: engine.currentSessionType) }

    private var header: some View {
        HStack {
            // 阶段指示：色点 + 标签
            HStack(spacing: DS3.S.sm) {
                Circle()
                    .fill(theme.color)
                    .frame(width: 8, height: 8)
                Text(theme.label)
                    .font(DS3.Font.sub)
                    .foregroundColor(pal.dim)
            }

            Spacer()

            Button {
                showClock = true
            } label: {
                Image(systemName: "moon.stars")
                    .font(.system(size: 16))
                    .foregroundColor(pal.dim)
                    .frame(width: 40, height: 40)
            }
            .pressable3()

            if settings.whiteNoiseEnabled {
                Button {
                    sound.toggleWhiteNoise()
                } label: {
                    Image(systemName: sound.isPlaying ? "waveform" : "waveform.slash")
                        .font(.system(size: 16))
                        .foregroundColor(pal.dim)
                        .frame(width: 40, height: 40)
                }
                .pressable3()
            }
        }
    }

    // MARK: Ring

    private var ringArea: some View {
        TimelineView(.animation) { ctx in
            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                RingView3(
                    progress: engine.smoothProgress(at: ctx.date),
                    remaining: displayRemaining(at: ctx.date),
                    color: theme.color,
                    isPaused: isPausedState,
                    side: side,
                    caption: engine.isFreeFocus ? "自由专注" : "",
                    isRunning: engine.isRunning
                )
                .frame(width: side, height: side)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
            .frame(height: ringHeight)
        }
    }

    private var ringHeight: CGFloat { 340 }

    private func displayRemaining(at date: Date) -> Double {
        engine.isRunning
            ? engine.smoothRemainingSeconds(at: date)
            : Double(engine.remainingSeconds)
    }

    private var isPausedState: Bool {
        if case .paused = engine.state { return true }
        return false
    }

    // MARK: Today strip

    private var todayStrip: some View {
        HStack(spacing: DS3.S.sm) {
            Image(systemName: "flame.fill")
                .font(.system(size: 11))
                .foregroundColor(DS3.Color.warn)

            Text("\(engine.todayPomodoros)/\(settings.dailyGoalPomodoros)")
                .font(DS3.Font.sub.weight(.semibold))
                .monospacedDigit()
                .foregroundColor(pal.text)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(pal.hairline)
                    Capsule()
                        .fill(theme.color)
                        .frame(width: max(4, geo.size.width * engine.dailyGoalProgress))
                        .animation(DS3.Anim.smooth, value: engine.dailyGoalProgress)
                }
            }
            .frame(height: 4)

            Text(DateUtils.hoursMinutes(from: engine.todayFocusSeconds))
                .font(DS3.Font.caption)
                .monospacedDigit()
                .foregroundColor(pal.dim)
        }
        .padding(.horizontal, DS3.S.lg + DS3.S.md)
    }

    // MARK: Task chip

    private var taskChip: some View {
        Button {
            showTaskPicker = true
        } label: {
            HStack(spacing: DS3.S.sm) {
                if let task = selectedTask {
                    Circle().fill(Color(hex: task.colorHex)).frame(width: 6, height: 6)
                    Text(task.title).font(DS3.Font.caption)
                    Text("\(task.completedPomodoros)/\(task.estimatedPomodoros)")
                        .font(DS3.Font.micro)
                        .foregroundColor(pal.dim)
                } else {
                    Image(systemName: "plus").font(.system(size: 10))
                    Text("关联任务").font(DS3.Font.caption)
                }
            }
            .foregroundColor(selectedTask == nil ? pal.dim : pal.text)
            .padding(.horizontal, DS3.S.md)
            .padding(.vertical, DS3.S.sm + 2)
            .background(Capsule().stroke(pal.hairline, lineWidth: 1))
        }
        .pressable3()
        .padding(.horizontal, DS3.S.lg)
    }

    // MARK: Controls

    private var controls: some View {
        HStack(spacing: DS3.S.xl) {
            // 重置
            Button {
                HapticManager.shared.light()
                engine.reset()
                sound.stopWhiteNoise()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 17))
                    .foregroundColor(pal.dim)
                    .frame(width: 54, height: 54)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            .pressable3()

            // 主按钮
            Button {
                HapticManager.shared.medium()
                primaryAction()
            } label: {
                Image(systemName: primaryIcon)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundColor(isFinished ? pal.text : pal.iconOnAccent)
                    .frame(width: 78, height: 78)
                    .background(
                        Circle().fill(isFinished ? AnyShapeStyle(.ultraThinMaterial)
                                                 : AnyShapeStyle(theme.color))
                    )
                    .glow(theme.color, radius: isFinished ? 0 : 18, opacity: 0.45)
            }
            .pressable3()

            // 跳过
            Button {
                HapticManager.shared.light()
                if engine.state == .focusing && !engine.isFreeFocus {
                    showInterruptDialog = true
                } else {
                    engine.skip()
                }
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 17))
                    .foregroundColor(pal.dim)
                    .frame(width: 54, height: 54)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            .pressable3()
        }
    }

    private let chipMinutes = [15, 20, 25, 40, 50, 60]

    private var currentFocusMinutes: Int { settings.focusDuration / 60 }

    /// Flow 式时长快选：点选即生效，尾部 ··· 打开精调面板
    private var durationChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS3.S.sm) {
                ForEach(chipMinutes, id: \.self) { m in
                    chipButton(m)
                }
                if !chipMinutes.contains(currentFocusMinutes) {
                    chipButton(currentFocusMinutes)
                }
                Button {
                    HapticManager.shared.light()
                    showDurationSheet = true
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(pal.dim)
                        .frame(width: 34, height: 32)
                        .background(
                            Capsule().stroke(pal.hairline, lineWidth: 1)
                        )
                }
                .pressable3()
            }
            .padding(.horizontal, DS3.S.lg + DS3.S.md)
        }
    }

    private func chipButton(_ m: Int) -> some View {
        let selected = m == currentFocusMinutes
        return Button {
            HapticManager.shared.selection()
            settings.focusDuration = m * 60
        } label: {
            Text("\(m)")
                .font(DS3.Font.sub.weight(selected ? .semibold : .regular))
                .monospacedDigit()
                .foregroundColor(selected ? pal.iconOnAccent : pal.dim)
                .padding(.horizontal, DS3.S.md)
                .frame(height: 32)
                .background(
                    Capsule().fill(selected ? AnyShapeStyle(theme.color)
                                            : AnyShapeStyle(pal.hairline.opacity(0.5)))
                )
        }
        .pressable3()
    }

    private var isIdleState: Bool {
        if case .idle = engine.state { return true }
        return false
    }

    private var showBreakSuggestion: Bool {
        settings.breakSuggestionEnabled &&
        (engine.state == .shortBreak || engine.state == .longBreak)
    }

    private var breakSuggestionCard: some View {
        let suggestions = ["喝一杯水 💧", "看看 6 米外的远处 20 秒 👀",
                           "站起来伸展一下肩颈 🙆", "深呼吸 10 次 🌬",
                           "走动一下，活动双腿 🚶"]
        let idx = min(suggestions.count - 1,
                      abs(engine.completedFocusCount) % suggestions.count)
        return HStack(spacing: DS3.S.sm) {
            Text(suggestions[idx])
                .font(DS3.Font.sub)
                .foregroundColor(pal.dim)
        }
        .padding(.horizontal, DS3.S.lg)
        .padding(.vertical, DS3.S.sm)
        .background(Capsule().stroke(pal.hairline, lineWidth: 1))
    }

    private func applyKeepAwake() {
        UIApplication.shared.isIdleTimerDisabled =
            engine.isRunning && settings.keepScreenAwake
    }

    private func extendPhase() {
        HapticManager.shared.light()
        engine.extendCurrentPhase(by: 300)
    }

    private var isFinished: Bool {
        if case .finished = engine.state { return true }
        return false
    }

    private var primaryIcon: String {
        switch engine.state {
        case .focusing, .shortBreak, .longBreak: return "pause.fill"
        default: return "play.fill"
        }
    }

    private func primaryAction() {
        switch engine.state {
        case .idle, .focusReady:
            engine.startFocus()
            if settings.whiteNoiseEnabled { sound.playWhiteNoise() }
        case .breakReady:
            engine.startBreak()
        case .finished:
            engine.reset()
            engine.startFocus()
            if settings.whiteNoiseEnabled { sound.playWhiteNoise() }
        case .focusing, .shortBreak, .longBreak:
            engine.pause()
            sound.pauseWhiteNoise()
        case .paused:
            engine.resume()
            sound.resumeWhiteNoise()
        }
    }

    // MARK: State reactions

    private func onState(_ newState: EngineState) {
        switch newState {
        case .focusing:
            if settings.whiteNoiseEnabled && !sound.isPlaying { sound.playWhiteNoise() }
            if settings.appShieldEnabled { FocusShieldManager.shared.activateShield() }
        case .shortBreak, .longBreak:
            sound.stopWhiteNoise()
            HapticManager.shared.success()
            if settings.completionSoundEnabled { sound.playCompletionSound() }
        case .breakReady:
            HapticManager.shared.success()
            if settings.completionSoundEnabled { sound.playCompletionSound() }
            FocusShieldManager.shared.deactivateShield()
        case .finished:
            FocusShieldManager.shared.deactivateShield()
            HapticManager.shared.success()
            if settings.completionSoundEnabled { sound.playCompletionSound() }
            withAnimation(DS3.Anim.spring) { showCelebration = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(DS3.Anim.smooth) { showCelebration = false }
            }
        default:
            break
        }
    }

    // MARK: Celebration

    @ViewBuilder
    private var celebrationOverlay: some View {
        if showCelebration {
            ZStack {
                (colorScheme == .dark ? SwiftUI.Color.black.opacity(0.88) : SwiftUI.Color.white.opacity(0.92)).ignoresSafeArea()
                VStack(spacing: DS3.S.lg) {
                    ZStack {
                        Circle().fill(DS3.Color.accent.opacity(0.12)).frame(width: 104, height: 104)
                        Circle().stroke(DS3.Color.accent, lineWidth: 2).frame(width: 104, height: 104)
                        Image(systemName: "checkmark")
                            .font(.system(size: 44, weight: .light))
                            .foregroundColor(DS3.Color.accent)
                    }
                    VStack(spacing: DS3.S.xs) {
                        Text("今日目标达成")
                            .font(DS3.Font.title)
                            .foregroundColor(pal.text)
                        Text("\(engine.todayPomodoros) 个番茄 · \(DateUtils.hoursMinutes(from: engine.todayFocusSeconds))")
                            .font(DS3.Font.sub)
                            .monospacedDigit()
                            .foregroundColor(pal.dim)
                    }
                }
                .padding(DS3.S.xxl)
                .background(RoundedRectangle(cornerRadius: DS3.R.lg).fill(pal.surface))
            }
            .transition(.opacity.combined(with: .scale(scale: 0.92)))
        }
    }
}

// MARK: - Ring

struct RingView3: View {
    let progress: Double
    let remaining: Double
    let color: SwiftUI.Color
    let isPaused: Bool
    let side: CGFloat
    var caption: String = ""
    var isRunning: Bool = false

    @State private var breathe = false
    @Environment(\.colorScheme) private var colorScheme

    private var pal: DS3.ScenePalette { .scene(colorScheme) }

    var body: some View {
        let lineWidth: CGFloat = max(9, side * 0.032)

        ZStack {
            Circle()
                .stroke(pal.hairline, lineWidth: lineWidth)
                .frame(width: side, height: side)

            // 进度环：角向渐变 + 外发光
            Circle()
                .trim(from: 0, to: max(0.002, progress))
                .stroke(
                    AngularGradient(colors: [color.opacity(0.55), color, color.opacity(0.9), color],
                                    center: .center),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: side, height: side)
                .rotationEffect(.degrees(-90))
                .glow(color, radius: lineWidth * 1.4, opacity: 0.55)
                .animation(DS3.Anim.gentle, value: color)

            // 端点光点（Apple 活动圆环细节）
            if progress > 0.004 && progress < 0.996 {
                let theta = ((-90 + progress * 360) * Double.pi) / 180
                Circle()
                    .fill(SwiftUI.Color.white)
                    .frame(width: lineWidth * 1.15, height: lineWidth * 1.15)
                    .glow(color, radius: lineWidth * 1.7, opacity: 0.95)
                    .position(x: side / 2 + (side / 2 - lineWidth / 2) * CGFloat(cos(theta)),
                              y: side / 2 + (side / 2 - lineWidth / 2) * CGFloat(sin(theta)))
            }

            VStack(spacing: DS3.S.xs) {
                Text(timeText)
                    .font(side > 320 ? DS3.Font.timerHuge : DS3.Font.timerBig)
                    .monospacedDigit()
                    .kerning(-1)
                    .foregroundStyle(
                        LinearGradient(colors: [pal.text, color.opacity(pal.isDark ? 0.75 : 0.85)],
                                       startPoint: .top, endPoint: .bottom))
                    .numericTransition3()
                    .shadow(color: color.opacity(pal.isDark ? 0.35 : 0.15),
                            radius: pal.isDark ? 16 : 10)
                Text(caption.isEmpty ? statusText : caption)
                    .font(DS3.Font.caption)
                    .kerning(1.5)
                    .foregroundColor(pal.dim)
            }
        }
        .scaleEffect(breathe ? (isPaused ? 1.015 : 1.007) : 1)
        .animation(
            isPaused
                ? Animation.easeInOut(duration: 1.6).repeatForever(autoreverses: true)
                : Animation.easeInOut(duration: 4).repeatForever(autoreverses: true),
            value: breathe)
        .onChange(of: isRunning) { run in
            breathe = run || isPaused
        }
        .onChange(of: isPaused) { paused in
            breathe = paused || isRunning
        }
        .onAppear { breathe = isRunning || isPaused }
    }

    private var timeText: String {
        let s = max(0, Int(remaining.rounded(.up)))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    private var statusText: String {
        if isPaused { return "已暂停" }
        if progress <= 0.001 { return "准备开始" }
        return ""
    }
}

// MARK: - Task picker

private struct TaskPickerSheet3: View {
    @Binding var selectedTask: TaskItem?
    @Environment(\.dismiss) private var dismiss
    @State private var tasks: [TaskItem] = []

    var body: some View {
        NavigationView {
            List {
                ForEach(tasks) { task in
                    Button {
                        selectedTask = task
                        PomodoroEngine.shared.currentTaskId = task.id
                        dismiss()
                    } label: {
                        HStack(spacing: DS3.S.sm) {
                            Circle().fill(Color(hex: task.colorHex)).frame(width: 8, height: 8)
                            Text(task.title).foregroundColor(DS3.Color.text)
                            Spacer()
                            Text("\(task.completedPomodoros)/\(task.estimatedPomodoros)")
                                .font(DS3.Font.caption)
                                .monospacedDigit()
                                .foregroundColor(DS3.Color.textDim)
                            if selectedTask?.id == task.id {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12))
                                    .foregroundColor(DS3.Color.accent)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .hideScrollBackground3()
            .navigationTitle("选择任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.foregroundColor(DS3.Color.textDim)
                }
            }
            .onAppear { tasks = PersistenceController.shared.fetchTasks() }
        }
    }
}

// MARK: - Immersive focus overlay
//
// 专注运行时盖住整个 TabView：黑底 + 圆环 + 最小控制。
// 暂停/结束即自动消失，回到普通界面。

struct ImmersiveFocusView: View {
    @ObservedObject private var engine = PomodoroEngine.shared
    @Environment(\.colorScheme) private var colorScheme

    private var pal: DS3.ScenePalette { .scene(colorScheme) }

    var body: some View {
        ZStack {
            DS3.Color.bg.ignoresSafeArea()
            PhaseTheme3.sceneBackground(for: engine.currentSessionType, scheme: colorScheme)

            VStack(spacing: DS3.S.xl) {
                Spacer()

                TimelineView(.animation) { ctx in
                    GeometryReader { geo in
                        let side = min(geo.size.width, geo.size.height)
                        RingView3(
                            progress: engine.smoothProgress(at: ctx.date),
                            remaining: engine.smoothRemainingSeconds(at: ctx.date),
                            color: PhaseTheme3.theme(for: engine.currentSessionType).color,
                            isPaused: false,
                            side: side,
                            caption: engine.isFreeFocus ? "自由专注" : "",
                            isRunning: true
                        )
                        .frame(width: side, height: side)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    }
                    .frame(height: 340)
                }

                Spacer()

                HStack(spacing: DS3.S.xl) {
                    Button {
                        HapticManager.shared.light()
                        engine.extendCurrentPhase(by: 300)
                    } label: {
                        Text("+5")
                            .font(DS3.Font.headline.monospacedDigit())
                            .foregroundColor(pal.dim)
                            .frame(width: 54, height: 54)
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                    .pressable3()

                    Button {
                        HapticManager.shared.medium()
                        engine.pause()
                    } label: {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(pal.iconOnAccent)
                            .frame(width: 72, height: 72)
                            .background(Circle().fill(PhaseTheme3.theme(for: engine.currentSessionType).color))
                            .glow(PhaseTheme3.theme(for: engine.currentSessionType).color, radius: 16, opacity: 0.45)
                    }
                    .pressable3()

                    Button {
                        HapticManager.shared.light()
                        engine.skip()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 17))
                            .foregroundColor(pal.dim)
                            .frame(width: 54, height: 54)
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                    .pressable3()
                }
                .padding(.bottom, DS3.S.xxl + DS3.S.lg)
            }
        }
        .transition(.opacity)
    }
}


// MARK: - 打断原因

enum InterruptReason: Identifiable, CaseIterable {
    case phone
    case interrupted
    case lowEnergy
    case lostInterest

    var label: String {
        switch self {
        case .phone: return "被手机干扰了"
        case .interrupted: return "被人打断了"
        case .lowEnergy: return "精力跟不上"
        case .lostInterest: return "不想继续这个任务"
        }
    }

    var id: String { label }

    static let all: [InterruptReason] = [.phone, .interrupted, .lowEnergy, .lostInterest]
}


// MARK: - 时长精调面板

struct DurationTuneSheet: View {
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("专注") {
                    Stepper(value: $settings.focusDuration, in: 60...10800, step: 300) {
                        HStack { Text("时长"); Spacer()
                            Text("\(settings.focusDuration / 60) 分钟").monospacedDigit()
                                .foregroundColor(DS3.Color.textDim) }
                    }
                }
                Section("休息") {
                    Stepper(value: $settings.shortBreakDuration, in: 60...3600, step: 60) {
                        HStack { Text("小憩"); Spacer()
                            Text("\(settings.shortBreakDuration / 60) 分钟").monospacedDigit()
                                .foregroundColor(DS3.Color.textDim) }
                    }
                    Stepper(value: $settings.longBreakDuration, in: 60...7200, step: 60) {
                        HStack { Text("长歇"); Spacer()
                            Text("\(settings.longBreakDuration / 60) 分钟").monospacedDigit()
                                .foregroundColor(DS3.Color.textDim) }
                    }
                    Stepper(value: $settings.pomodorosBeforeLongBreak, in: 2...8) {
                        HStack { Text("长歇间隔"); Spacer()
                            Text("每 \(settings.pomodorosBeforeLongBreak) 番茄").monospacedDigit()
                                .foregroundColor(DS3.Color.textDim) }
                    }
                }
            }
            .hideScrollBackground3()
            .navigationTitle("时长")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(DS3.Color.accent)
                }
            }
        }
        .preferredColorScheme(colorScheme)
    }
}
