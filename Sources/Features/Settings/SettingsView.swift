import SwiftUI

/// Settings screen using system Form with dark theme.
struct SettingsView: View {

    @StateObject private var settings = AppSettings.shared
    @State private var exportURL: URL?
    @State private var showingShareSheet = false

    var body: some View {
        NavigationView {
            Form {
                presetSection
                durationSection
                soundSection
                behaviorSection
                focusShieldSection
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
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Presets

    private var presetSection: some View {
        Section("快速预设") {
            ForEach(AppSettings.Preset.allCases, id: \.rawValue) { preset in
                Button(action: {
                    HapticManager.shared.selection()
                    preset.apply(to: settings)
                }) {
                    HStack {
                        Text(preset.rawValue)
                            .font(DS.Font.body)
                            .foregroundColor(DS.Color.textPrimary)
                        Spacer()
                    }
                }
            }
        }
        .listRowBackground(DS.Color.bgSecondary)
    }

    // MARK: - Durations

    private var durationSection: some View {
        Section("时长") {
            Picker("专注", selection: $settings.focusDuration) {
                ForEach([15*60, 20*60, 25*60, 30*60, 40*60, 45*60, 50*60, 60*60, 90*60], id: \.self) {
                    Text("\($0/60) 分钟").tag($0)
                }
            }
            .tint(DS.Color.focus)

            Picker("短休息", selection: $settings.shortBreakDuration) {
                ForEach([3*60, 5*60, 10*60, 15*60], id: \.self) {
                    Text("\($0/60) 分钟").tag($0)
                }
            }
            .tint(DS.Color.shortBreak)

            Picker("长休息", selection: $settings.longBreakDuration) {
                ForEach([10*60, 15*60, 20*60, 30*60], id: \.self) {
                    Text("\($0/60) 分钟").tag($0)
                }
            }
            .tint(DS.Color.longBreak)

            Stepper("长休息前番茄数: \(settings.pomodorosBeforeLongBreak)",
                    value: $settings.pomodorosBeforeLongBreak, in: 1...12)
                .tint(DS.Color.accent)
        }
        .listRowBackground(DS.Color.bgSecondary)
    }

    // MARK: - Sound

    private var soundSection: some View {
        Section {
            Toggle("白噪音", isOn: $settings.whiteNoiseEnabled)
                .tint(DS.Color.accent)

            if settings.whiteNoiseEnabled {
                Picker("类型", selection: $settings.whiteNoiseType) {
                    Text("雨声").tag("rain")
                    Text("海浪").tag("ocean")
                    Text("森林").tag("forest")
                    Text("风扇").tag("fan")
                }

                HStack {
                    Text("音量")
                    Slider(value: $settings.whiteNoiseVolume, in: 0...1)
                        .tint(DS.Color.accent)
                    Text("\(Int(settings.whiteNoiseVolume * 100))")
                        .font(DS.Font.body)
                        .monospacedDigit()
                        .foregroundColor(DS.Color.textMuted)
                        .frame(width: 28, alignment: .trailing)
                }
            }
        } header: {
            Label("声音", systemImage: "speaker.wave.2")
        }
        .listRowBackground(DS.Color.bgSecondary)
    }

    // MARK: - Behavior

    private var behaviorSection: some View {
        Section("行为") {
            Toggle("自动开始休息", isOn: $settings.autoStartBreaks)
                .tint(DS.Color.accent)
            Toggle("自动开始专注", isOn: $settings.autoStartFocus)
                .tint(DS.Color.accent)
            Toggle("触感反馈", isOn: $settings.hapticsEnabled)
                .tint(DS.Color.accent)
            Toggle("完成提醒音", isOn: $settings.completionSoundEnabled)
                .tint(DS.Color.accent)
        }
        .listRowBackground(DS.Color.bgSecondary)
    }

    // MARK: - Focus shield

    private var focusShieldSection: some View {
        Section {
            Toggle("App 屏蔽", isOn: $settings.appShieldEnabled)
                .tint(DS.Color.accent)

            if settings.appShieldEnabled {
                NavigationLink {
                    AppShieldPickerView()
                } label: {
                    HStack {
                        Text("屏蔽列表")
                        Spacer()
                        Text("\(settings.shieldedBundleIds.count)")
                            .foregroundColor(DS.Color.textMuted)
                    }
                }
            }
        } header: {
            Label("专注模式", systemImage: "shield")
        }
        .listRowBackground(DS.Color.bgSecondary)
    }

    // MARK: - Data

    private var dataSection: some View {
        Section("数据") {
            Button(action: exportData) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("导出数据")
                }
                .foregroundColor(DS.Color.textPrimary)
            }

            Button(role: .destructive, action: {}) {
                HStack {
                    Image(systemName: "trash")
                    Text("清除所有数据")
                }
            }
        }
        .listRowBackground(DS.Color.bgSecondary)
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("关于") {
            HStack {
                Text("版本")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(DS.Color.textMuted)
            }
            HStack {
                Text("最低系统")
                Spacer()
                Text("iOS 15.0")
                    .foregroundColor(DS.Color.textMuted)
            }
            Link(destination: URL(string: "https://github.com/opa334/TrollStore")!) {
                HStack {
                    Image(systemName: "link")
                    Text("TrollStore")
                }
            }
        }
        .listRowBackground(DS.Color.bgSecondary)
    }

    private func exportData() {
        do {
            exportURL = try PersistenceController.shared.exportToURL()
            showingShareSheet = true
        } catch {
            NSLog("[FocusFlip] Export error: \(error.localizedDescription)")
        }
    }
}

// MARK: - App shield picker

private struct AppShieldPickerView: View {
    @StateObject private var settings = AppSettings.shared
    @State private var installedApps: [InstalledApp] = []

    var body: some View {
        List {
            ForEach(installedApps) { app in
                Toggle(isOn: Binding(
                    get: { settings.shieldedBundleIds.contains(app.bundleId) },
                    set: { isOn in
                        if isOn {
                            settings.shieldedBundleIds.append(app.bundleId)
                        } else {
                            settings.shieldedBundleIds.removeAll { $0 == app.bundleId }
                        }
                    }
                )) {
                    HStack(spacing: DS.S.sm) {
                        Image(systemName: "app")
                            .foregroundColor(DS.Color.accent)
                        VStack(alignment: .leading) {
                            Text(app.name)
                                .font(DS.Font.body)
                            Text(app.bundleId)
                                .font(DS.Font.micro)
                                .foregroundColor(DS.Color.textMuted)
                        }
                    }
                }
                .tint(DS.Color.accent)
            }
        }
        .hideScrollBackground()
        .background(DS.Color.bgPrimary.ignoresSafeArea())
        .navigationTitle("屏蔽的 App")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            installedApps = FocusShieldManager.shared.listInstalledApps()
        }
    }
}

// MARK: - Share sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
