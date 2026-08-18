import SwiftUI
import UniformTypeIdentifiers

/// Settings screen — clean grouped form with preset cards.
///
/// 对标 Be Focused / Focus Keeper 设置页：
/// - 预设方案快捷切换（卡片选择器）
/// - 自定义时长
/// - 声音/震动/行为/屏蔽/备份分组
struct SettingsView: View {

    @ObservedObject private var settings = AppSettings.shared
    @State private var exportURL: URL?
    @State private var showingShareSheet = false
    @State private var showingImporter = false
    @State private var showingClearConfirm = false
    @State private var showingShieldPicker = false

    var body: some View {
        NavigationView {
            Form {
                presetSection
                durationSection
                goalSection
                soundSection
                behaviorSection
                shieldSection
                dataSection
                aboutSection
            }
            .hideScrollBackground()
            .background(DS.Color.bgPrimary.ignoresSafeArea())
            .navigationTitle("设置")
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
            .fileImporter(isPresented: $showingImporter,
                          allowedContentTypes: [.json]) { result in
                handleImport(result)
            }
            .confirmationDialog("确认清除所有数据？此操作不可撤销。",
                                isPresented: $showingClearConfirm,
                                titleVisibility: .visible) {
                Button("清除全部数据", role: .destructive) {
                    PersistenceController.shared.clearAllData()
                }
                Button("取消", role: .cancel) {}
            }
        }
    }

    // MARK: - Preset

    private var presetSection: some View {
        Section("预设方案") {
            ForEach(AppSettings.Preset.allCases, id: \.rawValue) { preset in
                Button {
                    HapticManager.shared.light()
                    preset.apply(to: settings)
                } label: {
                    HStack {
                        Text(preset.rawValue)
                            .font(DS.Font.body)
                            .foregroundColor(DS.Color.textPrimary)
                        Spacer()
                        if isPresetActive(preset) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13))
                                .foregroundColor(DS.Color.accent)
                        }
                    }
                }
            }
        }
    }

    private func isPresetActive(_ preset: AppSettings.Preset) -> Bool {
        switch preset {
        case .classic:
            return settings.focusDuration == 25*60 && settings.shortBreakDuration == 5*60
        case .long:
            return settings.focusDuration == 50*60 && settings.shortBreakDuration == 10*60
        case .short:
            return settings.focusDuration == 15*60 && settings.shortBreakDuration == 3*60
        case .ninety:
            return settings.focusDuration == 90*60
        }
    }

    // MARK: - Duration

    private var durationSection: some View {
        Section("时长（分钟）") {
            StepperRow(title: "专注", value: Binding(
                get: { settings.focusDuration / 60 },
                set: { settings.focusDuration = $0 * 60 }
            ), range: 1...180, suffix: "分钟")

            StepperRow(title: "短休息", value: Binding(
                get: { settings.shortBreakDuration / 60 },
                set: { settings.shortBreakDuration = $0 * 60 }
            ), range: 1...60, suffix: "分钟")

            StepperRow(title: "长休息", value: Binding(
                get: { settings.longBreakDuration / 60 },
                set: { settings.longBreakDuration = $0 * 60 }
            ), range: 1...120, suffix: "分钟")

            StepperRow(title: "长休间隔", value: $settings.pomodorosBeforeLongBreak,
                       range: 2...8, suffix: "番茄")
        }
    }

    // MARK: - Daily goal

    private var goalSection: some View {
        Section("每日目标") {
            StepperRow(title: "目标番茄数", value: $settings.dailyGoalPomodoros,
                       range: 1...24, suffix: "个")
        }
    }

    // MARK: - Sound

    private var soundSection: some View {
        Section("声音") {
            ToggleRow(title: "白噪音", icon: "waveform", isOn: $settings.whiteNoiseEnabled)

            if settings.whiteNoiseEnabled {
                Picker("白噪音类型", selection: $settings.whiteNoiseType) {
                    Text("雨声").tag("rain")
                    Text("海浪").tag("ocean")
                    Text("森林").tag("forest")
                    Text("风扇").tag("fan")
                }

                VStack(alignment: .leading, spacing: DS.S.xs) {
                    HStack {
                        Text("音量")
                            .font(DS.Font.body)
                        Spacer()
                        Text("\(Int(settings.whiteNoiseVolume * 100))%")
                            .font(DS.Font.caption)
                            .foregroundColor(DS.Color.textMuted)
                            .monospacedDigit()
                    }
                    Slider(value: $settings.whiteNoiseVolume, in: 0...1)
                        .tint(DS.Color.accent)
                }
            }

            ToggleRow(title: "完成提示音", icon: "bell", isOn: $settings.completionSoundEnabled)

            if settings.completionSoundEnabled {
                Picker("完成音类型", selection: $settings.completionSoundType) {
                    Text("铃声").tag("bell")
                    Text("风铃").tag("chime")
                    Text("电子音").tag("digital")
                    Text("轻柔音").tag("gentle")
                }
            }
        }
    }

    // MARK: - Behavior

    private var behaviorSection: some View {
        Section("行为") {
            ToggleRow(title: "自动开始休息", icon: "arrow.forward.circle",
                      isOn: $settings.autoStartBreaks)
            ToggleRow(title: "自动开始专注", icon: "play.circle",
                      isOn: $settings.autoStartFocus)
            ToggleRow(title: "震动反馈", icon: "iphone.radiowaves.left.and.right",
                      isOn: $settings.hapticsEnabled)
            ToggleRow(title: "通知提醒", icon: "bell.badge",
                      isOn: $settings.notificationsEnabled)
        }
    }

    // MARK: - Shield

    private var shieldSection: some View {
        Section("App 屏蔽") {
            ToggleRow(title: "专注时隐藏其他 App", icon: "eye.slash",
                      isOn: $settings.appShieldEnabled)

            if settings.appShieldEnabled {
                Button("选择要隐藏的 App") {
                    showingShieldPicker = true
                }
                .foregroundColor(DS.Color.accent)

                if !settings.shieldedBundleIds.isEmpty {
                    Text("已屏蔽 \(settings.shieldedBundleIds.count) 个 App")
                        .font(DS.Font.caption)
                        .foregroundColor(DS.Color.textMuted)
                }
            }
        }
        .sheet(isPresented: $showingShieldPicker) {
            ShieldPickerSheet()
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        Section("数据") {
            Button {
                exportData()
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(DS.Color.accent)
                    Text("导出数据")
                        .foregroundColor(DS.Color.textPrimary)
                }
            }

            Button {
                showingImporter = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundColor(DS.Color.accent)
                    Text("导入数据")
                        .foregroundColor(DS.Color.textPrimary)
                }
            }

            Button(role: .destructive) {
                showingClearConfirm = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("清除全部数据")
                }
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("关于") {
            HStack {
                Text("版本")
                Spacer()
                Text(appVersion)
                    .foregroundColor(DS.Color.textMuted)
                    .monospacedDigit()
            }
            HStack {
                Text("FocusFlip")
                Spacer()
                Text("专注，翻转生活")
                    .font(DS.Font.caption)
                    .foregroundColor(DS.Color.textMuted)
            }
        }
    }

    private var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0.0"
    }

    // MARK: - Actions

    private func exportData() {
        do {
            let url = try PersistenceController.shared.exportToURL()
            exportURL = url
            showingShareSheet = true
        } catch {
            NSLog("[FocusFlip] Export error: \(error.localizedDescription)")
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                try PersistenceController.shared.importJSON(from: url)
                HapticManager.shared.success()
            } catch {
                NSLog("[FocusFlip] Import error: \(error.localizedDescription)")
            }
        case .failure:
            break
        }
    }
}

// MARK: - Reusable rows

private struct StepperRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let suffix: String

    var body: some View {
        Stepper(value: $value, in: range) {
            HStack {
                Text(title)
                    .font(DS.Font.body)
                    .foregroundColor(DS.Color.textPrimary)
                Spacer()
                Text("\(value) \(suffix)")
                    .font(DS.Font.caption)
                    .foregroundColor(DS.Color.textMuted)
                    .monospacedDigit()
            }
        }
    }
}

private struct ToggleRow: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: DS.S.md) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(DS.Color.accent)
                .frame(width: 24)
            Text(title)
                .font(DS.Font.body)
                .foregroundColor(DS.Color.textPrimary)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
    }
}

// MARK: - Shield picker

private struct ShieldPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var installedApps: [InstalledApp] = []
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        NavigationView {
            List {
                Section {
                    if installedApps.isEmpty {
                        VStack(spacing: DS.S.sm) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 28))
                                .foregroundColor(DS.Color.warning)
                            Text("无法读取已安装 App 列表")
                                .font(DS.Font.body)
                                .foregroundColor(DS.Color.textSecondary)
                            Text("需要 TrollStore 安装并提供相关权限")
                                .font(DS.Font.caption)
                                .foregroundColor(DS.Color.textMuted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.S.xxl)
                    } else {
                        ForEach(installedApps) { app in
                            HStack {
                                Text(app.name)
                                    .font(DS.Font.body)
                                    .foregroundColor(DS.Color.textPrimary)
                                Spacer()
                                if settings.shieldedBundleIds.contains(app.bundleId) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(DS.Color.accent)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(DS.Color.textMuted)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                toggle(app.bundleId)
                            }
                        }
                    }
                }
            }
            .hideScrollBackground()
            .background(DS.Color.bgPrimary.ignoresSafeArea())
            .navigationTitle("选择要隐藏的 App")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .foregroundColor(DS.Color.accent)
                }
            }
            .onAppear {
                installedApps = FocusShieldManager.shared.listInstalledApps()
            }
        }
    }

    private func toggle(_ bundleId: String) {
        if settings.shieldedBundleIds.contains(bundleId) {
            settings.shieldedBundleIds.removeAll { $0 == bundleId }
        } else {
            settings.shieldedBundleIds.append(bundleId)
        }
    }
}

// MARK: - Share sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
