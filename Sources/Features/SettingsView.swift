import SwiftUI
import CoreData

/// 设置 —— 统计页同款卡片家族（R.card 卡 + 图标块分组头 + 自定义行控件）
struct SettingsView: View {

    @ObservedObject private var prefs = Prefs.shared
    @ObservedObject private var engine = FocusEngine.shared
    @ObservedObject private var sound = SoundPlayer.shared

    @State private var expanded: Set<String> = []
    @State private var shareURL: URL?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DS.S.md) {
                    groupCard("行为", icon: "switch.2") {
                        toggleRow("休息自动开始", $prefs.autoStartBreaks)
                        divider
                        toggleRow("专注自动接续", $prefs.autoStartFocus)
                        divider
                        toggleRow("专注时保持屏幕常亮", $prefs.keepAwake)
                    } footer: { Text("阶段结束后自动进入下一阶段。") }

                    groupCard("声音", icon: "speaker.wave.2") {
                        menuRow("环境音", selection: $prefs.soundType,
                                items: SoundPlayer.ambientTypes.map { ($0.id, $0.name) })
                        divider
                        sliderRow(value: $prefs.soundVolume) { v in sound.applyVolume(v) }
                        divider
                        HStack {
                            Text("专注时自动播放").font(DS.F.bodyMd)
                            Spacer()
                            Toggle("", isOn: $prefs.soundAutoPlay)
                                .labelsHidden()
                        }
                        .padding(.vertical, 12)
                        divider
                        HStack {
                            Text("完成提示音").font(DS.F.bodyMd)
                            Spacer()
                            menuButton(selection: $prefs.toneType,
                                       items: SoundPlayer.tones.map { ($0.id, $0.name) })
                        }
                        .padding(.vertical, 12)
                        divider
                        actionRow(title: sound.isPlaying ? "停止试听" : "试听环境音",
                                  system: sound.isPlaying ? "stop.fill" : "play.fill",
                                  tint: sound.isPlaying ? Color(hex: "#E5573F") : nil) {
                            playPreview()
                        }
                    } footer: { Text("环境音开始专注时响起，结束自动停止。") }

                    groupCard("时长", icon: "timer") {
                        stepperRow("默认专注", $prefs.focusMinutes, 1...180, 5)
                        divider
                        stepperRow("小憩", $prefs.shortMinutes, 1...60, 1)
                        divider
                        stepperRow("长歇", $prefs.longMinutes, 1...120, 5)
                        divider
                        stepperRow("长歇间隔", $prefs.longEvery, 2...8, 1, unit: "个")
                    } footer: { Text("计时页的时长条可快速切换常用值。") }

                    groupCard("数据", icon: "externaldrive") {
                        actionRow(title: "导出全部记录 (CSV)",
                                  system: "square.and.arrow.up",
                                  tint: DS.accent) { exportCSV() }
                    } footer: { Text("导出所有专注记录，表格软件可直接打开。") }

                    groupCard("关于", icon: "info.circle") {
                        HStack {
                            Text("版本").font(DS.F.bodyMd)
                            Spacer()
                            Text(appVersion).foregroundColor(.secondary).monospacedDigit()
                        }
                        .padding(.vertical, 12)
                    } footer: { Text("Flow 风格的极简专注计时器 · 个人自用") }
                }
                .padding(.horizontal, DS.S.xl)
                .padding(.top, DS.S.sm)
                .padding(.bottom, DS.S.xl)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: Binding(
                get: { shareURL != nil },
                set: { if !$0 { shareURL = nil } })) {
                if let url = shareURL { ShareSheet(items: [url]) }
            }
        }
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
                    withAnimation(.easeInOut(duration: 0.25)) {
                        if isOpen { expanded.remove(title) } else { expanded.insert(title) }
                    }
                    Haptic.tick()
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
                            .font(.system(size: 17, weight: .bold))
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
        .background(
            RoundedRectangle(cornerRadius: DS.R.card, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
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
            .padding(.vertical, 7)
            .background(Capsule().fill(DS.accent.opacity(0.10)))
        }
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
                Text("\(value.wrappedValue)")
                    .font(DS.F.numberM.monospacedDigit())
                    .foregroundColor(.primary)
                    .frame(minWidth: 40)
                + Text(" \(unit)")
                    .font(DS.F.caption).foregroundColor(.secondary)
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
            action(); Haptic.tick()
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

    private func exportCSV() {
        if let url = Store.shared.exportCSV() {
            shareURL = url
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}

/// CSV 导出（Store 扩展）
extension Store {
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
