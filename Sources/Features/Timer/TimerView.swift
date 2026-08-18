import SwiftUI

/// Main timer screen — immersive ring + clean controls.
///
/// 对标 Be Focused / Flow：
/// - 大圆环居中，背景近黑
/// - 阶段语义色（红=专注 / 绿=短休 / 紫=长休）
/// - 底部三按钮：重置 / 播放-暂停 / 跳过
/// - 顶部：轮次进度圆点（视觉暗示，不用文字）
/// - 今日卡：番茄数 + 专注时长 + 目标进度
struct TimerView: View {

    @ObservedObject private var engine = PomodoroEngine.shared
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var soundPlayer = SoundPlayer.shared

    @State private var showTaskPicker = false
    @State private var selectedTask: TaskItem?
    @State private var showCelebration = false

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                topBar
                    .padding(.top, DS.S.xxxl)

                Spacer()

                cycleDots
                    .padding(.bottom, DS.S.lg)

                timerRing
                    .padding(.horizontal, DS.S.xl)

                Spacer()

                todayBar
                    .padding(.bottom, DS.S.md)

                taskChip
                    .padding(.bottom, DS.S.lg)

                controls
                    .padding(.bottom, DS.S.xxxl)
            }
        }
        .onAppear {
            NotificationService.shared.requestPermission()
            engine.refreshTodayStats()
        }
        .onReceive(engine.$state) { handleStateChange($0) }
        .overlay {
            if showCelebration {
                CelebrationOverlay(
                    pomodoros: engine.todayPomodoros,
                    minutes: engine.todayFocusSeconds / 60
                )
                .transition(.scale(scale: 0.7).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showTaskPicker) {
            TaskPickerSheet(selectedTask: $selectedTask)
        }
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            DS.Color.bgPrimary.ignoresSafeArea()

            // Subtle phase accent glow from top
            phaseTheme.gradient[0]
                .ignoresSafeArea()
                .blur(radius: 140)
                .offset(y: -240)
        }
        .animation(DS.Anim.slow, value: engine.currentSessionType)
    }

    private var phaseTheme: PhaseTheme {
        PhaseTheme.theme(for: engine.currentSessionType)
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: DS.S.xxs) {
                HStack(spacing: DS.S.xs) {
                    Image(systemName: phaseTheme.icon)
                        .font(.system(size: 13, weight: .semibold))
                    Text(phaseTheme.label)
                        .font(DS.Font.captionBold)
                }
                .foregroundColor(phaseTheme.color)

                Text("\(engine.completedFocusCount) 番茄完成")
                    .font(DS.Font.micro)
                    .foregroundColor(DS.Color.textMuted)
            }

            Spacer()

            if settings.whiteNoiseEnabled {
                Button(action: { soundPlayer.toggleWhiteNoise() }) {
                    Image(systemName: soundPlayer.isPlaying ? "waveform" : "waveform.slash")
                        .font(.system(size: 15))
                        .foregroundColor(DS.Color.textSecondary)
                        .frame(width: 36, height: 36)
                }
                .pressable()
            }
        }
        .padding(.horizontal, DS.S.xl)
    }

    // MARK: - Cycle progress dots

    /// Visual cycle indicator: dots representing pomodoros before long break.
    private var cycleDots: some View {
        HStack(spacing: DS.S.sm) {
            ForEach(0..<settings.pomodorosBeforeLongBreak, id: \.self) { index in
                Circle()
                    .fill(index < completedInCycle ? phaseTheme.color : DS.Color.textPrimary.opacity(0.12))
                    .frame(width: 7, height: 7)
                    .animation(DS.Anim.standard, value: engine.completedFocusCount)
            }
        }
    }

    private var completedInCycle: Int {
        engine.completedFocusCount % settings.pomodorosBeforeLongBreak
    }

    // MARK: - Timer ring

    private var timerRing: some View {
        TimelineView(.animation) { context in
            ringView(progress: engine.smoothProgress(at: context.date))
        }
    }

    private func ringView(progress: Double) -> some View {
        let ringSize: CGFloat = 264
        let lineWidth: CGFloat = 5

        return ZStack {
            // Track
            Circle()
                .stroke(DS.Color.textPrimary.opacity(0.06), lineWidth: lineWidth)
                .frame(width: ringSize, height: ringSize)

            // Progress arc
            Circle()
                .trim(from: 0, to: max(0.001, progress))
                .stroke(
                    phaseTheme.color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: ringSize, height: ringSize)
                .rotationEffect(.degrees(-90))

            // Center
            VStack(spacing: DS.S.xs) {
                Text(timeString)
                    .font(DS.Font.timerDisplay)
                    .monospacedDigit()
                    .foregroundColor(DS.Color.textPrimary)
                    .numericTextTransition()

                Text(statusLabel)
                    .font(DS.Font.caption)
                    .foregroundColor(DS.Color.textMuted)
            }
        }
    }

    private var timeString: String {
        let s = max(0, engine.remainingSeconds)
        let m = s / 60
        let sec = s % 60
        return String(format: "%02d:%02d", m, sec)
    }

    private var statusLabel: String {
        switch engine.state {
        case .idle, .focusReady:
            return "准备开始"
        case .focusing:
            return "专注中"
        case .shortBreak, .longBreak:
            return "休息中"
        case .paused:
            return "已暂停"
        case .breakReady:
            return "休息时间"
        case .finished:
            return "今日目标达成 🎉"
        }
    }

    // MARK: - Today bar

    private var todayBar: some View {
        let goal = settings.dailyGoalPomodoros
        let progress = engine.dailyGoalProgress

        return HStack(spacing: DS.S.sm) {
            Image(systemName: "flame.fill")
                .font(.system(size: 11))
                .foregroundColor(DS.Color.warning)

            Text("\(engine.todayPomodoros)/\(goal)")
                .font(DS.Font.captionBold)
                .foregroundColor(DS.Color.textSecondary)
                .monospacedDigit()

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(DS.Color.textPrimary.opacity(0.08))
                    Capsule()
                        .fill(phaseTheme.color)
                        .frame(width: max(4, geo.size.width * progress))
                        .animation(DS.Anim.standard, value: progress)
                }
            }
            .frame(width: 100, height: 4)

            Text(DateUtils.hoursMinutes(from: engine.todayFocusSeconds))
                .font(DS.Font.micro)
                .foregroundColor(DS.Color.textMuted)
                .monospacedDigit()
        }
        .padding(.horizontal, DS.S.md)
        .padding(.vertical, DS.S.sm)
        .background(
            Capsule().fill(DS.Color.bgSecondary)
        )
    }

    // MARK: - Task chip

    private var taskChip: some View {
        Group {
            if let task = selectedTask {
                Button(action: { showTaskPicker = true }) {
                    HStack(spacing: DS.S.sm) {
                        Circle()
                            .fill(Color(hex: task.colorHex))
                            .frame(width: 6, height: 6)
                        Text(task.title)
                            .font(DS.Font.caption)
                            .foregroundColor(DS.Color.textPrimary)
                        Text("\(task.completedPomodoros)/\(task.estimatedPomodoros)")
                            .font(DS.Font.micro)
                            .foregroundColor(DS.Color.textMuted)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, DS.S.md)
                    .padding(.vertical, DS.S.sm)
                    .background(Capsule().fill(DS.Color.bgSecondary))
                }
                .pressable()
            } else {
                Button(action: { showTaskPicker = true }) {
                    HStack(spacing: DS.S.xxs) {
                        Image(systemName: "plus")
                            .font(.system(size: 10))
                        Text("关联任务")
                            .font(DS.Font.caption)
                    }
                    .foregroundColor(DS.Color.textMuted)
                    .padding(.horizontal, DS.S.md)
                    .padding(.vertical, DS.S.sm)
                    .background(
                        Capsule().stroke(DS.Color.textPrimary.opacity(0.08), lineWidth: 1)
                    )
                }
                .pressable()
            }
        }
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: DS.S.xxxl) {
            Button(action: {
                HapticManager.shared.light()
                engine.reset()
                soundPlayer.stopWhiteNoise()
            }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 16))
                    .foregroundColor(DS.Color.textSecondary)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(DS.Color.bgSecondary))
            }
            .pressable()

            Button(action: {
                HapticManager.shared.medium()
                mainButtonAction()
            }) {
                Image(systemName: mainButtonIcon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(DS.Color.bgPrimary)
                    .frame(width: 72, height: 72)
                    .background(Circle().fill(phaseTheme.color))
            }
            .pressable()

            Button(action: {
                HapticManager.shared.light()
                engine.skip()
            }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 16))
                    .foregroundColor(DS.Color.textSecondary)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(DS.Color.bgSecondary))
            }
            .pressable()
        }
    }

    private var mainButtonIcon: String {
        switch engine.state {
        case .idle, .breakReady, .focusReady:
            return "play.fill"
        case .finished:
            return "arrow.counterclockwise.circle.fill"
        case .focusing, .shortBreak, .longBreak:
            return "pause.fill"
        case .paused:
            return "play.fill"
        }
    }

    private func mainButtonAction() {
        switch engine.state {
        case .idle, .focusReady:
            engine.startFocus()
            if settings.whiteNoiseEnabled { soundPlayer.playWhiteNoise() }
        case .breakReady:
            engine.startBreak()
        case .finished:
            engine.reset()
            engine.startFocus()
            if settings.whiteNoiseEnabled { soundPlayer.playWhiteNoise() }
        case .focusing, .shortBreak, .longBreak:
            engine.pause()
            if settings.whiteNoiseEnabled { soundPlayer.pauseWhiteNoise() }
        case .paused:
            engine.resume()
            if settings.whiteNoiseEnabled { soundPlayer.resumeWhiteNoise() }
        }
    }

    // MARK: - State changes

    private func handleStateChange(_ newState: EngineState) {
        switch newState {
        case .focusing:
            if settings.whiteNoiseEnabled && !soundPlayer.isPlaying {
                soundPlayer.playWhiteNoise()
            }
            if settings.appShieldEnabled { FocusShieldManager.shared.activateShield() }
        case .shortBreak, .longBreak:
            soundPlayer.stopWhiteNoise()
            HapticManager.shared.success()
            if settings.completionSoundEnabled { soundPlayer.playCompletionSound() }
        case .breakReady:
            HapticManager.shared.success()
            if settings.completionSoundEnabled { soundPlayer.playCompletionSound() }
            FocusShieldManager.shared.deactivateShield()
        case .finished:
            FocusShieldManager.shared.deactivateShield()
            HapticManager.shared.success()
            if settings.completionSoundEnabled { soundPlayer.playCompletionSound() }
            triggerCelebration()
        default:
            break
        }
    }

    private func triggerCelebration() {
        withAnimation(DS.Anim.bouncy) { showCelebration = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            withAnimation(DS.Anim.standard) { showCelebration = false }
        }
    }
}

// MARK: - Celebration

private struct CelebrationOverlay: View {
    let pomodoros: Int
    let minutes: Int

    var body: some View {
        ZStack {
            DS.Color.bgPrimary.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: DS.S.xl) {
                ZStack {
                    Circle()
                        .fill(DS.Color.focus.opacity(0.12))
                        .frame(width: 100, height: 100)
                    Circle()
                        .stroke(DS.Color.focus, lineWidth: 2)
                        .frame(width: 100, height: 100)
                    Image(systemName: "checkmark")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundColor(DS.Color.focus)
                }

                VStack(spacing: DS.S.xs) {
                    Text("今日目标达成！")
                        .font(DS.Font.title2)
                        .foregroundColor(DS.Color.textPrimary)
                    Text("\(pomodoros) 个番茄 · \(DateUtils.hoursMinutes(from: minutes * 60))")
                        .font(DS.Font.caption)
                        .foregroundColor(DS.Color.textMuted)
                        .monospacedDigit()
                }
            }
            .padding(DS.S.xxxl)
            .background(
                RoundedRectangle(cornerRadius: DS.R.xl)
                    .fill(DS.Color.bgSecondary)
            )
        }
    }
}

// MARK: - Task picker

private struct TaskPickerSheet: View {
    @Binding var selectedTask: TaskItem?
    @Environment(\.dismiss) var dismiss
    @State private var tasks: [TaskItem] = []

    var body: some View {
        NavigationView {
            List {
                if tasks.isEmpty {
                    Text("还没有任务")
                        .foregroundColor(DS.Color.textMuted)
                        .font(DS.Font.body)
                } else {
                    Section {
                        ForEach(tasks) { task in
                            Button(action: {
                                selectedTask = task
                                PomodoroEngine.shared.currentTaskId = task.id
                                dismiss()
                            }) {
                                HStack(spacing: DS.S.sm) {
                                    Circle()
                                        .fill(Color(hex: task.colorHex))
                                        .frame(width: 8, height: 8)
                                    Text(task.title)
                                        .font(DS.Font.body)
                                        .foregroundColor(DS.Color.textPrimary)
                                    Spacer()
                                    Text("\(task.completedPomodoros)/\(task.estimatedPomodoros)")
                                        .font(DS.Font.micro)
                                        .foregroundColor(DS.Color.textMuted)
                                        .monospacedDigit()
                                    if selectedTask?.id == task.id {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12))
                                            .foregroundColor(DS.Color.accent)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .hideScrollBackground()
            .background(DS.Color.bgPrimary.ignoresSafeArea())
            .navigationTitle("选择任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundColor(DS.Color.textSecondary)
                }
            }
            .onAppear {
                tasks = PersistenceController.shared.fetchTasks()
            }
        }
    }
}
