import SwiftUI

/// Main timer screen: clean numeric display + progress ring + minimal controls.
///
/// Design language: Catppuccin Mocha palette, SF Pro Rounded ultra-light,
/// semantic phase colors, no gratuitous gradients or shadows.
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
                    .padding(.top, DS.S.xxl)

                Spacer()

                timerDisplay
                    .padding(.horizontal, DS.S.lg)

                Spacer()

                todayCard
                    .padding(.bottom, DS.S.md)

                taskChip
                    .padding(.bottom, DS.S.md)

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
                CelebrationOverlay(todayPomodoros: engine.todayPomodoros,
                                   todayMinutes: engine.todayFocusSeconds / 60)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
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

            // Subtle radial accent from top — not a flashy gradient
            phaseTheme.gradient[0]
                .ignoresSafeArea()
                .blur(radius: 120)
                .offset(y: -200)
        }
        .animation(DS.Anim.slow, value: engine.currentSessionType)
    }

    private var phaseTheme: PhaseTheme {
        PhaseTheme.theme(for: engine.currentSessionType)
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: DS.S.xs) {
                HStack(spacing: DS.S.sm) {
                    Image(systemName: phaseTheme.icon)
                        .font(.system(size: 14))
                    Text(phaseTheme.label)
                        .font(DS.Font.captionBold)
                }
                .foregroundColor(phaseTheme.color)

                Text("第 \(engine.currentCycle) 轮 · \(engine.completedFocusCount) 番茄")
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
        .padding(.horizontal, DS.S.lg)
    }

    // MARK: - Timer display (ring + number)

    private var timerDisplay: some View {
        TimelineView(.animation) { context in
            let progress = engine.smoothProgress(at: context.date)
            ringView(progress: progress)
        }
    }

    private func ringView(progress: Double) -> some View {
        let ringSize: CGFloat = 260
        let lineWidth: CGFloat = 6

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

            // Center content
            VStack(spacing: DS.S.sm) {
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
        let s = engine.remainingSeconds
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

    // MARK: - Today card

    private var todayCard: some View {
        let goal = settings.dailyGoalPomodoros
        let progress = engine.dailyGoalProgress

        return HStack(spacing: DS.S.sm) {
            Image(systemName: "flame.fill")
                .font(.system(size: 12))
                .foregroundColor(DS.Color.warning)

            Text("今日 \(engine.todayPomodoros)/\(goal) 番茄")
                .font(DS.Font.caption)
                .foregroundColor(DS.Color.textSecondary)

            // Goal progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(DS.Color.textPrimary.opacity(0.08))
                    Capsule()
                        .fill(DS.Color.focus)
                        .frame(width: max(6, geo.size.width * progress))
                }
            }
            .frame(width: 110, height: 5)

            Text(DateUtils.hoursMinutes(from: engine.todayFocusSeconds))
                .font(DS.Font.micro)
                .foregroundColor(DS.Color.textMuted)
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
                    }
                    .padding(.horizontal, DS.S.md)
                    .padding(.vertical, DS.S.sm)
                    .background(
                        Capsule().fill(DS.Color.bgSecondary)
                    )
                }
                .pressable()
            } else {
                Button(action: { showTaskPicker = true }) {
                    HStack(spacing: DS.S.xs) {
                        Image(systemName: "plus")
                            .font(.system(size: 11))
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
        HStack(spacing: DS.S.xl) {
            // Secondary: reset
            Button(action: {
                HapticManager.shared.light()
                engine.reset()
                soundPlayer.stopWhiteNoise()
            }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 16))
                    .foregroundColor(DS.Color.textSecondary)
                    .frame(width: 52, height: 52)
                    .background(
                        Circle().fill(DS.Color.bgSecondary)
                    )
            }
            .pressable()

            // Primary: play / pause
            Button(action: {
                HapticManager.shared.medium()
                mainButtonAction()
            }) {
                Image(systemName: mainButtonIcon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(DS.Color.bgPrimary)
                    .frame(width: 72, height: 72)
                    .background(
                        Circle().fill(phaseTheme.color)
                    )
            }
            .pressable()

            // Secondary: skip
            Button(action: {
                HapticManager.shared.light()
                engine.skip()
            }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 16))
                    .foregroundColor(DS.Color.textSecondary)
                    .frame(width: 52, height: 52)
                    .background(
                        Circle().fill(DS.Color.bgSecondary)
                    )
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
            // Start a fresh cycle
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
            if settings.whiteNoiseEnabled { soundPlayer.playWhiteNoise() }
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            withAnimation(DS.Anim.standard) { showCelebration = false }
        }
    }
}

// MARK: - Celebration overlay

/// Minimal "daily goal reached" celebration: a soft dark scrim + checkmark card.
private struct CelebrationOverlay: View {
    let todayPomodoros: Int
    let todayMinutes: Int

    var body: some View {
        ZStack {
            DS.Color.bgPrimary.opacity(0.75)
                .ignoresSafeArea()

            VStack(spacing: DS.S.lg) {
                ZStack {
                    Circle()
                        .fill(DS.Color.focus.opacity(0.15))
                        .frame(width: 96, height: 96)
                    Circle()
                        .stroke(DS.Color.focus, lineWidth: 2)
                        .frame(width: 96, height: 96)
                    Image(systemName: "checkmark")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundColor(DS.Color.focus)
                }

                VStack(spacing: DS.S.xs) {
                    Text("今日目标达成！")
                        .font(DS.Font.title2)
                        .foregroundColor(DS.Color.textPrimary)
                    Text("\(todayPomodoros) 个番茄 · \(DateUtils.hoursMinutes(from: todayMinutes * 60))")
                        .font(DS.Font.caption)
                        .foregroundColor(DS.Color.textMuted)
                }
            }
            .padding(DS.S.xxl)
            .background(
                RoundedRectangle(cornerRadius: DS.R.xl)
                    .fill(DS.Color.bgSecondary)
            )
        }
    }
}

// MARK: - Task picker sheet

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
                                    if selectedTask?.id == task.id {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12))
                                            .foregroundColor(phaseAccent)
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

    private var phaseAccent: SwiftUI.Color {
        DS.Color.accent
    }
}
