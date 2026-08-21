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

    @State private var showTaskPicker = false
    @State private var selectedTask: TaskItem?
    @State private var showCelebration = false

    var body: some View {
        ZStack {
            DS3.Color.bg.ignoresSafeArea()

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
                if engine.isRunning {
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
                    .foregroundColor(DS3.Color.textDim)
            }

            Spacer()

            if settings.whiteNoiseEnabled {
                Button {
                    sound.toggleWhiteNoise()
                } label: {
                    Image(systemName: sound.isPlaying ? "waveform" : "waveform.slash")
                        .font(.system(size: 16))
                        .foregroundColor(DS3.Color.textDim)
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
                    side: side
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
                .foregroundColor(DS3.Color.text)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(DS3.Color.hairline)
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
                .foregroundColor(DS3.Color.textDim)
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
                        .foregroundColor(DS3.Color.textDim)
                } else {
                    Image(systemName: "plus").font(.system(size: 10))
                    Text("关联任务").font(DS3.Font.caption)
                }
            }
            .foregroundColor(selectedTask == nil ? DS3.Color.textDim : DS3.Color.text)
            .padding(.horizontal, DS3.S.md)
            .padding(.vertical, DS3.S.sm + 2)
            .background(Capsule().stroke(DS3.Color.hairline, lineWidth: 1))
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
                    .foregroundColor(DS3.Color.textDim)
                    .frame(width: 54, height: 54)
                    .background(Circle().fill(DS3.Color.surface))
            }
            .pressable3()

            // 主按钮
            Button {
                HapticManager.shared.medium()
                primaryAction()
            } label: {
                Image(systemName: primaryIcon)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundColor(isFinished ? DS3.Color.text : DS3.Color.bg)
                    .frame(width: 78, height: 78)
                    .background(
                        Circle().fill(isFinished ? DS3.Color.surface : theme.color)
                    )
            }
            .pressable3()

            // 跳过
            Button {
                HapticManager.shared.light()
                engine.skip()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 17))
                    .foregroundColor(DS3.Color.textDim)
                    .frame(width: 54, height: 54)
                    .background(Circle().fill(DS3.Color.surface))
            }
            .pressable3()
        }
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
                DS3.Color.bg.opacity(0.85).ignoresSafeArea()
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
                            .foregroundColor(DS3.Color.text)
                        Text("\(engine.todayPomodoros) 个番茄 · \(DateUtils.hoursMinutes(from: engine.todayFocusSeconds))")
                            .font(DS3.Font.sub)
                            .monospacedDigit()
                            .foregroundColor(DS3.Color.textDim)
                    }
                }
                .padding(DS3.S.xxl)
                .background(RoundedRectangle(cornerRadius: DS3.R.lg).fill(DS3.Color.surface))
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

    @State private var breathe = false

    var body: some View {
        let lineWidth: CGFloat = max(6, side * 0.022)

        ZStack {
            Circle()
                .stroke(DS3.Color.hairline.opacity(0.5), lineWidth: lineWidth)
                .frame(width: side, height: side)

            Circle()
                .trim(from: 0, to: max(0.002, progress))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: side, height: side)
                .rotationEffect(.degrees(-90))

            VStack(spacing: DS3.S.xs) {
                Text(timeText)
                    .font(side > 320 ? DS3.Font.timerHuge : DS3.Font.timerBig)
                    .monospacedDigit()
                    .foregroundColor(DS3.Color.text)
                    .numericTransition3()
                Text(statusText)
                    .font(DS3.Font.caption)
                    .foregroundColor(DS3.Color.textDim)
            }
        }
        .scaleEffect(isPaused && breathe ? 1.015 : 1)
        .animation(isPaused ? Animation.easeInOut(duration: 1.6).repeatForever(autoreverses: true) : .default,
                   value: breathe)
        .onChange(of: isPaused) { paused in
            breathe = paused
        }
        .onAppear { breathe = isPaused }
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

    var body: some View {
        ZStack {
            DS3.Color.bg.ignoresSafeArea()

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
                            side: side
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
                            .foregroundColor(DS3.Color.textDim)
                            .frame(width: 54, height: 54)
                            .background(Circle().fill(DS3.Color.surface))
                    }
                    .pressable3()

                    Button {
                        HapticManager.shared.medium()
                        engine.pause()
                    } label: {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(DS3.Color.bg)
                            .frame(width: 72, height: 72)
                            .background(Circle().fill(PhaseTheme3.theme(for: engine.currentSessionType).color))
                    }
                    .pressable3()

                    Button {
                        HapticManager.shared.light()
                        engine.skip()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 17))
                            .foregroundColor(DS3.Color.textDim)
                            .frame(width: 54, height: 54)
                            .background(Circle().fill(DS3.Color.surface))
                    }
                    .pressable3()
                }
                .padding(.bottom, DS3.S.xxl + DS3.S.lg)
            }
        }
        .transition(.opacity)
    }
}
