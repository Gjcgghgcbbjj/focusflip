import SwiftUI
import CoreData
import UniformTypeIdentifiers

/// 设置 —— 统计页同款卡片家族（R.card 卡 + 图标块分组头 + 自定义行控件）
struct SettingsView: View {

    @ObservedObject private var prefs = Prefs.shared
    @ObservedObject private var engine = FocusEngine.shared
    @ObservedObject private var sound = SoundPlayer.shared

    @State private var expanded: Set<String> = []
    @State private var shareURL: URL?
    @State private var showImporter = false
    @State private var importToast: String?
    @State private var exportSummary: Backup.Summary?
    @State private var showExportConfirm = false
    @State private var importSummary: Backup.Summary?
    @State private var importData: Data?
    @State private var showImportConfirm = false
    @State private var csvRecordCount = 0
    @State private var showCSVConfirm = false

    var body: some View {
        NavigationView {
            settingsList
        }
    }

    private var settingsList: some View {
        ScrollView {
            VStack(spacing: DS.S.md) {
                behaviorCard
                soundCard
                durationCard
                dataCard
                aboutCard
            }
            .padding(.horizontal, DS.S.xl)
            .padding(.top, DS.S.sm)
            .padding(.bottom, DS.S.xl)
        }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)
            .confirmationDialog("导出 JSON 备份？", isPresented: $showExportConfirm,
                                titleVisibility: .visible, presenting: exportSummary) { summary in
                Button("生成备份") {
                    Haptic.light()
                    exportBackup()
                }
                Button("取消", role: .cancel) {}
            } message: { summary in
                Text("将包含任务 \(summary.tasks)、目标 \(summary.countdowns)、记录 \(summary.sessions)。")
            }
            .confirmationDialog("导入 JSON 备份？", isPresented: $showImportConfirm,
                                titleVisibility: .visible, presenting: importSummary) { summary in
                Button("合并导入", role: .destructive) {
                    confirmImport()
                }
                Button("取消", role: .cancel) {}
            } message: { summary in
                Text("将导入任务 \(summary.tasks)、目标 \(summary.countdowns)、记录 \(summary.sessions)；冲突项按 ID 去重合并。")
            }
            .confirmationDialog("导出 CSV 记录？", isPresented: $showCSVConfirm,
                                titleVisibility: .visible) {
                Button("生成 CSV") {
                    Haptic.light()
                    exportCSV()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("预计导出 \(csvRecordCount) 条专注记录。")
            }
            .sheet(isPresented: Binding(
                get: { shareURL != nil },
                set: { if !$0 { shareURL = nil } })) {
                if let url = shareURL { ShareSheet(items: [url]) }
            }
            .fileImporter(isPresented: $showImporter,
                          allowedContentTypes: [.json],
                          allowsMultipleSelection: false) { result in
                if case .success(let urls) = result, let url = urls.first {
                    prepareImport(from: url)
                }
            }
        }

    @ViewBuilder private var behaviorCard: some View {
        groupCard("行为", icon: "switch.2") {
            toggleRow("休息自动开始", $prefs.autoStartBreaks)
            divider
            toggleRow("专注自动接续", $prefs.autoStartFocus)
            divider
            toggleRow("专注时保持屏幕常亮", $prefs.keepAwake)
            divider
            toggleRow("计时中隐藏底部标签栏", $prefs.immersive)
            divider
            stepperRow("每日番茄目标", $prefs.dailyGoal, 0...20, 1, unit: "个")
            divider
            toggleRow("自由倒计时计入统计", $prefs.countdownCounts)
        } footer: { Text("阶段结束后自动进入下一阶段。每日目标 0 = 不设目标，达成时专注页与结算卡会提醒你。") }
    }

    @ViewBuilder private var soundCard: some View {
        groupCard("声音", icon: "speaker.wave.2") {
            menuRow("环境音", selection: $prefs.soundType,
                    items: SoundPlayer.ambientTypes.map { ($0.id, $0.name) })
            divider
            sliderRow(value: $prefs.soundVolume) { v in sound.applyVolume(v) }
            divider
            autoPlayRow
            divider
            toneRow
            divider
            actionRow(title: sound.isPlaying ? "停止试听" : "试听环境音",
                      system: sound.isPlaying ? "stop.fill" : "play.fill",
                      tint: sound.isPlaying ? Color(hex: "#E5573F") : nil) {
                playPreview()
            }
        } footer: { Text("环境音开始专注时响起，结束自动停止。") }
    }

    @ViewBuilder private var durationCard: some View {
        groupCard("时长", icon: "timer") {
            stepperRow("默认专注", $prefs.focusMinutes, 1...180, 5)
            divider
            stepperRow("小憩", $prefs.shortMinutes, 1...60, 1)
            divider
            stepperRow("长歇", $prefs.longMinutes, 1...120, 5)
            divider
            stepperRow("长歇间隔", $prefs.longEvery, 2...8, 1, unit: "个")
        } footer: { Text("计时页的时长条可快速切换常用值。") }
    }

    @ViewBuilder private var dataCard: some View {
        groupCard("数据", icon: "externaldrive") {
            actionRow(title: "备份全部数据 (JSON)",
                      system: "square.and.arrow.up",
                      tint: DS.accent) { prepareExport() }
            divider
            actionRow(title: "从备份导入…",
                      system: "square.and.arrow.down",
                      tint: DS.accent) {
                Haptic.warning()
                showImporter = true
            }
            divider
            actionRow(title: "导出全部记录 (CSV)",
                      system: "doc.text",
                      tint: nil) { prepareCSVExport() }
        } footer: { Text("JSON 备份含任务/目标/记录，导入前会预览并按 ID 合并。") }
    }

    @ViewBuilder private var aboutCard: some View {
        groupCard("关于", icon: "info.circle") {
            HStack {
                Text("版本").font(DS.F.bodyMd)
                Spacer()
                Text(appVersion).foregroundColor(.secondary).monospacedDigit()
            }
            .padding(.vertical, 12)
        } footer: { Text("Flow 风格的极简专注计时器 · 个人自用") }
    }

    @ViewBuilder private var autoPlayRow: some View {
        HStack {
            Text("专注时自动播放").font(DS.F.bodyMd)
            Spacer()
            Toggle("", isOn: $prefs.soundAutoPlay)
                .labelsHidden()
        }
        .padding(.vertical, 12)
    }

    @ViewBuilder private var toneRow: some View {
        HStack {
            Text("完成提示音").font(DS.F.bodyMd)
            Spacer()
            menuButton(selection: $prefs.toneType,
                       items: SoundPlayer.tones.map { ($0.id, $0.name) })
        }
        .padding(.vertical, 12)
    }

    // MARK: 分组卡（统计卡同款容器）

    @ViewBuilder
    private func groupCard<Content: View, Footer: View>(
        _ title: String, icon: String,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer) -> some View {

        let isOpen = expanded.contains(title)

        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(DS.Motion.soft) {
                        if isOpen { expanded.remove(title) } else { expanded.insert(title) }
                    }
                    Haptic.light()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: icon)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(DS.accent)
                            .frame(width: 30, height: 30)
                            .background(
                                RoundedRectangle(cornerRadius: DS.R.tile, style: .continuous)
                                    .fill(DS.accent.opacity(0.12)))
                        Text(title)
                            .font(DS.F.headline)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .rotationEffect(.degrees(isOpen ? 0 : -90))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())

                if isOpen {
                    VStack(spacing: 0) {
                        content()
                    }
                    .padding(.horizontal, 18)
                    .transition(.opacity.combined(with: .move(edge: .top)))

                    footer()
                        .font(DS.F.caption)
                        .foregroundColor(.secondary.opacity(0.75))
                        .padding(.horizontal, 18)
                        .padding(.top, 10)
                        .padding(.bottom, 14)
                }
            }
        }
        .hubSurface(.standard)
    }

    private var divider: some View {
        Divider().padding(.leading, 60)
    }

    // MARK: 行控件

    private func toggleRow(_ title: String, _ on: Binding<Bool>) -> some View {
        HStack {
            Text(title).font(DS.F.bodyMd)
            Spacer()
            Toggle("", isOn: on).labelsHidden()
        }
        .padding(.vertical, 12)
    }

    private func menuRow(_ title: String, selection: Binding<String>,
                         items: [(String, String)]) -> some View {
        HStack {
            Text(title).font(DS.F.bodyMd)
            Spacer()
            menuButton(selection: selection, items: items)
        }
        .padding(.vertical, 12)
    }

    private func menuButton(selection: Binding<String>,
                            items: [(String, String)]) -> some View {
        Menu {
            Picker("", selection: selection) {
                ForEach(items, id: \.0) { Text($0.1).tag($0.0) }
            }
        } label: {
            let label = items.first { $0.0 == selection.wrappedValue }?.1 ?? "-"
            HStack(spacing: 5) {
                Text(label).font(DS.F.subheadSb)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundColor(DS.accent)
            .padding(.horizontal, 12)
            .frame(minHeight: 30)
            .background(Capsule().fill(DS.accent.opacity(0.10)))
        }
        .buttonStyle(PressStyle())
    }

    private func sliderRow(value: Binding<Double>, onChange: @escaping (Double) -> Void)
        -> some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill")
                .font(.system(size: 10)).foregroundColor(.secondary)
            Slider(value: value, in: 0...1)
                .onChange(of: value.wrappedValue) { onChange($0) }
            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 12)).foregroundColor(.secondary)
        }
        .padding(.vertical, 12)
    }

    private func stepperRow(_ title: String, _ value: Binding<Int>,
                            _ range: ClosedRange<Int>, _ step: Int,
                            unit: String = "分钟") -> some View {
        HStack {
            Text(title).font(DS.F.bodyMd)
            Spacer()
            HStack(spacing: 0) {
                stepBtn("minus") {
                    if value.wrappedValue - step >= range.lowerBound {
                        value.wrappedValue -= step; Haptic.tick()
                    }
                }
                HStack(spacing: 3) {
                    Text("\(value.wrappedValue)")
                        .font(DS.F.numberM.monospacedDigit())
                        .foregroundColor(.primary)
                    Text(unit)
                        .font(DS.F.caption).foregroundColor(.secondary)
                }
                .frame(minWidth: 64)
                stepBtn("plus") {
                    if value.wrappedValue + step <= range.upperBound {
                        value.wrappedValue += step; Haptic.tick()
                    }
                }
            }
            .padding(.vertical, 4)
            .background(Capsule().fill(Color(.tertiarySystemGroupedBackground)))
        }
        .padding(.vertical, 10)
    }

    private func stepBtn(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(DS.accent)
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }

    private func actionRow(title: String, system: String,
                           tint: Color? = nil, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.light()
            action()
        } label: {
            Label(title, systemImage: system)
                .font(DS.F.bodySb)
                .foregroundColor(tint ?? .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }

    // MARK: 声音试听

    private func playPreview() {
        if sound.isPlaying {
            sound.stopAmbient()
        } else if prefs.soundType != "none" {
            sound.startAmbient(type: prefs.soundType, volume: prefs.soundVolume)
        }
    }

    private func exportBackup() {
        if let url = Backup.make() {
            shareURL = url
        }
    }

    private func exportCSV() {
        if let url = Store.shared.exportCSV() {
            shareURL = url
        }
    }

    private func prepareExport() {
        exportSummary = Backup.currentSummary()
        Haptic.light()
        showExportConfirm = true
    }

    private func prepareCSVExport() {
        csvRecordCount = Store.shared.sessionCount()
        showCSVConfirm = true
    }

    private func prepareImport(from url: URL) {
        let secured = url.startAccessingSecurityScopedResource()
        defer { if secured { url.stopAccessingSecurityScopedResource() } }

        do {
            let data = try Data(contentsOf: url)
            guard let summary = Backup.summary(of: data) else { throw NSError(domain: "FocusFlip.Import", code: -1) }
            importData = data
            importSummary = summary
            showImportConfirm = true
        } catch {
            Haptic.warning()
            ToastCenter.shared.show("导入失败：文件格式不正确", undoLabel: "知道了", undo: nil)
        }
    }

    private func confirmImport() {
        guard let data = importData else { return }
        let count = Backup.restore(data: data)
        if count >= 0 {
            Haptic.success()
            ToastCenter.shared.show("已导入 \(count) 条新数据", undoLabel: "知道了", undo: nil)
        } else {
            Haptic.warning()
            ToastCenter.shared.show("导入失败：文件内容不完整", undoLabel: "知道了", undo: nil)
        }
        importData = nil
        importSummary = nil
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}

/// CSV 导出（Store 扩展）
extension Store {
    func sessionCount() -> Int {
        let req: NSFetchRequest<SessionEntity> = SessionEntity.fetchRequest()
        return (try? context.count(for: req)) ?? 0
    }

    func exportCSV() -> URL? {
        let req: NSFetchRequest<SessionEntity> = SessionEntity.fetchRequest()
        req.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: true)]
        let sessions = (try? context.fetch(req)) ?? []
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"

        var rows = ["开始时间,结束时间,阶段,时长(分),是否完成,任务,备注"]
        for s in sessions {
            let taskName = s.taskId.flatMap { Store.shared.task(id: $0) }?.name ?? ""
            let note = (s.note ?? "").replacingOccurrences(of: "\"", with: "\"\"")
            let phase = Self.phaseName(s.phaseRaw)
            rows.append("\(f.string(from: s.startDate)),\(f.string(from: s.endDate)),"
                      + "\(phase),\(Int(s.durationSeconds) / 60),"
                      + "\(s.completed ? "是" : "否"),\"\(taskName)\",\"\(note)\"")
        }
        let csv = "\u{FEFF}" + rows.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("FocusFlip_记录.csv")
        do { try csv.write(to: url, atomically: true, encoding: .utf8); return url }
        catch { NSLog("[FlowSim] csv error: \(error.localizedDescription)"); return nil }
    }

    static func phaseName(_ raw: String) -> String {
        switch raw {
        case Phase.focus.rawValue: return "专注"
        case Phase.shortBreak.rawValue: return "小憩"
        case Phase.longBreak.rawValue: return "长歇"
        default: return raw
        }
    }
}

/// 系统分享面板
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
