import SwiftUI
import UniformTypeIdentifiers

/// FocusFlip 3.0 — 设置页。
struct SettingsView3: View {

    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var sound = SoundPlayer.shared

    @State private var exportURL: URL?
    @State private var showShare = false
    @State private var showImporter = false
    @State private var showClearConfirm = false
    @State private var showShieldPicker = false
    @State private var showExporter = false

    var body: some View {
        NavigationView {
            Form {
                presets
                durations
                goal
                soundSection
                behavior
                appearance
                shield
                data
                about
            }
            .hideScrollBackground3()
            .background(DS3.Color.bg.ignoresSafeArea())
            .navigationTitle("设置")
            .tint(DS3.Color.accent)
            .sheet(isPresented: $showShare) {
                if let url = exportURL { ShareSheet(items: [url]) }
            }
            .sheet(isPresented: $showExporter) {
                if let url = exportURL { DocumentExporter(url: url) }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { importResult($0) }
            .confirmationDialog("确认清除所有数据？此操作不可撤销。",
                                isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("清除全部数据", role: .destructive) {
                    PersistenceController.shared.clearAllData()
                    HapticManager.shared.warning()
                }
                Button("取消", role: .cancel) {}
            }
        }
    }

    // MARK: Presets

    private var presets: some View {
        Section("预设方案") {
            ForEach(AppSettings.Preset.allCases, id: \.rawValue) { p in
                Button {
                    HapticManager.shared.selection()
                    p.apply(to: settings)
                } label: {
                    HStack {
                        Text(p.rawValue).foregroundColor(DS3.Color.text)
                        Spacer()
                        if isActive(p) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(DS3.Color.accent)
                        }
                    }
                }
            }
        }
    }

    private func isActive(_ p: AppSettings.Preset) -> Bool {
        settings.focusDuration == p.focus &&
        settings.shortBreakDuration == p.short &&
        settings.longBreakDuration == p.long &&
        settings.pomodorosBeforeLongBreak == p.longEvery
    }

    // MARK: Durations

    private var durations: some View {
        Section("时长（分钟）") {
            step("专注", Binding(
                get: { settings.focusDuration / 60 },
                set: { settings.focusDuration = $0 * 60 }), 1...180)
            step("小憩", Binding(
                get: { settings.shortBreakDuration / 60 },
                set: { settings.shortBreakDuration = $0 * 60 }), 1...60)
            step("长歇", Binding(
                get: { settings.longBreakDuration / 60 },
                set: { settings.longBreakDuration = $0 * 60 }), 1...120)
            Stepper(value: $settings.pomodorosBeforeLongBreak, in: 2...8) {
                row("长歇间隔", "\(settings.pomodorosBeforeLongBreak) 番茄")
            }
        }
    }

    // MARK: Goal

    private var goal: some View {
        Section("每日目标") {
            Stepper(value: $settings.dailyGoalPomodoros, in: 1...24) {
                row("目标番茄数", "\(settings.dailyGoalPomodoros) 个")
            }
        }
    }

    // MARK: Sound

    private var soundSection: some View {
        Section("声音") {
            Toggle("白噪音", isOn: $settings.whiteNoiseEnabled)

            if settings.whiteNoiseEnabled {
                Picker("主音效", selection: $settings.whiteNoiseType) {
                    Text("雨声").tag("rain")
                    Text("海浪").tag("ocean")
                    Text("森林").tag("forest")
                    Text("风扇").tag("fan")
                    Text("白噪音").tag("white")
                    Text("粉噪音").tag("pink")
                    Text("棕噪音").tag("brown")
                }
                Picker("叠加音效", selection: $settings.whiteNoiseLayerType) {
                    Text("无").tag("none")
                    Text("雨声").tag("rain")
                    Text("海浪").tag("ocean")
                    Text("森林").tag("forest")
                    Text("风扇").tag("fan")
                    Text("白噪音").tag("white")
                    Text("粉噪音").tag("pink")
                    Text("棕噪音").tag("brown")
                }
                Button {
                    sound.playWhiteNoise()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        sound.stopWhiteNoise()
                    }
                } label: {
                    Label("试听", systemImage: "play.circle")
                }
                VStack(alignment: .leading, spacing: DS3.S.xs) {
                    HStack {
                        Text("音量")
                        Spacer()
                        Text("\(Int(settings.whiteNoiseVolume * 100))%")
                            .font(DS3.Font.caption).monospacedDigit()
                            .foregroundColor(DS3.Color.textDim)
                    }
                    Slider(value: $settings.whiteNoiseVolume, in: 0...1)
                }
            }

            Toggle("完成提示音", isOn: $settings.completionSoundEnabled)

            if settings.completionSoundEnabled {
                Picker("类型", selection: $settings.completionSoundType) {
                    Text("铃声").tag("bell")
                    Text("风铃").tag("chime")
                    Text("电子音").tag("digital")
                    Text("轻柔音").tag("gentle")
                }
                Button {
                    sound.playCompletionSound()
                } label: {
                    Label("试听", systemImage: "play.circle")
                }
            }
        }
    }

    // MARK: Behavior

    private var behavior: some View {
        Section("行为") {
            Toggle("自动开始休息", isOn: $settings.autoStartBreaks)
            Toggle("自动开始专注", isOn: $settings.autoStartFocus)
            Toggle("休息活动建议", isOn: $settings.breakSuggestionEnabled)
            Toggle("专注时屏幕常亮", isOn: $settings.keepScreenAwake)
            Toggle("沉浸模式（专注时全屏）", isOn: $settings.immersiveMode)
            Toggle("震动反馈", isOn: $settings.hapticsEnabled)
            Toggle("通知提醒", isOn: $settings.notificationsEnabled)
        }
    }

    // MARK: Appearance

    private var appearance: some View {
        Section("外观") {
            HStack {
                Text("专注色")
                Spacer()
                HStack(spacing: DS3.S.sm) {
                    ForEach(AppSettings.themeColors, id: \.hex) { c in
                        Circle()
                            .fill(Color(hex: c.hex))
                            .frame(width: 26, height: 26)
                            .overlay(
                                Circle().stroke(DS3.Color.text,
                                                lineWidth: settings.themeColorHex == c.hex ? 2 : 0)
                                    .opacity(settings.themeColorHex == c.hex ? 1 : 0)
                            )
                            .onTapGesture {
                                settings.themeColorHex = c.hex
                                HapticManager.shared.selection()
                            }
                    }
                }
            }
        }
    }

    // MARK: Shield

    private var shield: some View {
        Section("App 屏蔽") {
            Toggle("专注时隐藏其他 App", isOn: $settings.appShieldEnabled)
            if settings.appShieldEnabled {
                Button("选择要隐藏的 App") { showShieldPicker = true }
                if !settings.shieldedBundleIds.isEmpty {
                    Text("已屏蔽 \(settings.shieldedBundleIds.count) 个 App")
                        .font(DS3.Font.caption)
                        .foregroundColor(DS3.Color.textDim)
                }
            }
        }
        .sheet(isPresented: $showShieldPicker) { ShieldPickerSheet3() }
    }

    // MARK: Data

    private var data: some View {
        Section {
            Button {
                exportURL = try? PersistenceController.shared.exportToURL()
                if exportURL != nil { showShare = true }
            } label: {
                Label("导出数据", systemImage: "square.and.arrow.up")
            }
            Button {
                if exportURL == nil {
                    exportURL = try? PersistenceController.shared.exportToURL()
                }
                if exportURL != nil { showExporter = true }
            } label: {
                Label("备份到文件 App…", systemImage: "externaldrive")
            }
            Button {
                if let url = try? PersistenceController.shared.exportCSV() {
                    exportURL = url
                    showShare = true
                }
            } label: {
                Label("导出 CSV（表格明细）", systemImage: "tablecells")
            }
            Button {
                showImporter = true
            } label: {
                Label("导入数据", systemImage: "square.and.arrow.down")
            }
            Button(role: .destructive) {
                showClearConfirm = true
            } label: {
                Label("清除全部数据", systemImage: "trash")
            }
        } header: {
            Text("数据")
        } footer: {
            Text("进入后台时自动备份到沙盒（保留最近 7 天）\(PersistenceController.shared.lastBackupLabel.map { "，最近：\($0)" } ?? "，尚未备份")。删除 App 会清空沙盒，重要数据请定期「备份到文件 App」。")
        }
    }

    // MARK: About

    private var about: some View {
        Section("关于") {
            HStack {
                Text("版本")
                Spacer()
                Text(appVersion).foregroundColor(DS3.Color.textDim).monospacedDigit()
            }
        }
    }

    private var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "3.0.0"
    }

    // MARK: Helpers

    private func step(_ title: String, _ value: Binding<Int>, _ range: ClosedRange<Int>) -> some View {
        Stepper(value: value, in: range) {
            row(title, "\(value.wrappedValue) 分钟")
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundColor(DS3.Color.textDim).monospacedDigit()
        }
    }

    private func importResult(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        do {
            try PersistenceController.shared.importJSON(from: url)
            HapticManager.shared.success()
        } catch {
            NSLog("[FocusFlip] Import error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Shield picker

private struct ShieldPickerSheet3: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = AppSettings.shared
    @State private var apps: [InstalledApp] = []

    var body: some View {
        NavigationView {
            List {
                if apps.isEmpty {
                    VStack(spacing: DS3.S.sm) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 26))
                            .foregroundColor(DS3.Color.warn)
                        Text("无法读取已安装 App 列表")
                            .foregroundColor(DS3.Color.text)
                        Text("需要 TrollStore 安装并提供相关权限")
                            .font(DS3.Font.caption)
                            .foregroundColor(DS3.Color.textDim)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS3.S.xl)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(apps) { app in
                        HStack {
                            Text(app.name).foregroundColor(DS3.Color.text)
                            Spacer()
                            Image(systemName: settings.shieldedBundleIds.contains(app.bundleId)
                                  ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(settings.shieldedBundleIds.contains(app.bundleId)
                                                 ? DS3.Color.accent : DS3.Color.textDim)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { toggle(app.bundleId) }
                    }
                }
            }
            .listStyle(.plain)
            .hideScrollBackground3()
            .navigationTitle("选择要隐藏的 App")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }.font(.system(size: 17, weight: .semibold))
                }
            }
            .onAppear { apps = FocusShieldManager.shared.listInstalledApps() }
        }
    }

    private func toggle(_ id: String) {
        if let i = settings.shieldedBundleIds.firstIndex(of: id) {
            settings.shieldedBundleIds.remove(at: i)
        } else {
            settings.shieldedBundleIds.append(id)
        }
        HapticManager.shared.selection()
    }
}

// MARK: - Share sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}


// MARK: - Files exporter (save backup into Files / iCloud Drive)

struct DocumentExporter: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        UIDocumentPickerViewController(forExporting: [url], asCopy: true)
    }

    func updateUIViewController(_ vc: UIDocumentPickerViewController, context: Context) {}
}
