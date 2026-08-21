import SwiftUI
import CoreData

/// 设置 —— 全部分组可折叠（默认收起）
struct SettingsView: View {

    @ObservedObject private var prefs = Prefs.shared
    @ObservedObject private var engine = FocusEngine.shared
    @ObservedObject private var sound = SoundPlayer.shared

    @State private var expanded: Set<String> = []
    @State private var shareURL: URL?

    var body: some View {
        NavigationView {
            Form {
                group("行为", icon: "switch.2") {
                    Toggle("休息自动开始", isOn: $prefs.autoStartBreaks)
                    Toggle("专注自动接续", isOn: $prefs.autoStartFocus)
                    Toggle("专注时保持屏幕常亮", isOn: $prefs.keepAwake)
                    footerText("阶段结束后自动进入下一阶段。")
                }
                group("声音", icon: "speaker.wave.2") {
                    Picker("环境音", selection: $prefs.soundType) {
                        ForEach(SoundPlayer.ambientTypes, id: \.id) { t in
                            Text(t.name).tag(t.id)
                        }
                    }
                    .onChange(of: prefs.soundType) { t in
                        if sound.isPlaying {
                            if t != "none" { playPreview() } else { sound.stopAmbient() }
                        }
                    }

                    HStack {
                        Image(systemName: "speaker.fill")
                            .font(.caption).foregroundColor(.secondary)
                        Slider(value: $prefs.soundVolume, in: 0...1)
                            .onChange(of: prefs.soundVolume) { v in sound.applyVolume(v) }
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.caption).foregroundColor(.secondary)
                    }

                    HStack {
                        Toggle("专注时自动播放", isOn: $prefs.soundAutoPlay)
                        Button { playPreview() } label: {
                            Text(sound.isPlaying ? "停止" : "试听")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "#5865F2"))
                        }
                        .buttonStyle(.borderless)
                    }

                    Picker("完成提示音", selection: $prefs.toneType) {
                        ForEach(SoundPlayer.tones, id: \.id) { t in
                            Text(t.name).tag(t.id)
                        }
                    }
                    Button { SoundPlayer.shared.playTone(prefs.toneType) } label: {
                        Text("试听提示音").foregroundColor(Color(hex: "#5865F2"))
                    }
                    footerText("环境音开始专注时响起，结束自动停止。")
                }
                group("时长", icon: "timer") {
                    minutesRow("默认专注", $prefs.focusMinutes, 1...180, 5)
                    minutesRow("小憩", $prefs.shortMinutes, 1...60, 1)
                    minutesRow("长歇", $prefs.longMinutes, 1...120, 5)
                    Stepper(value: $prefs.longEvery, in: 2...8) {
                        HStack { Text("长歇间隔"); Spacer()
                            Text("每 \(prefs.longEvery) 个番茄").monospacedDigit()
                                .foregroundColor(.secondary) }
                    }
                    footerText("计时页的时长条可快速切换常用值。")
                }
                group("数据", icon: "externaldrive") {
                    Button { exportCSV() } label: {
                        Label("导出全部记录 (CSV)", systemImage: "square.and.arrow.up")
                            .foregroundColor(Color(hex: "#5865F2"))
                    }
                    footerText("导出所有专注记录，表格软件可直接打开。")
                }
                group("关于", icon: "info.circle") {
                    HStack { Text("版本"); Spacer()
                        Text(appVersion).foregroundColor(.secondary) }
                    footerText("Flow 风格的极简专注计时器 · 个人自用")
                }
            }
            .navigationTitle("设置")
            .sheet(isPresented: Binding(
                get: { shareURL != nil },
                set: { if !$0 { shareURL = nil } })) {
                if let url = shareURL { ShareSheet(items: [url]) }
            }
        }
    }

    // MARK: 可折叠分组

    @ViewBuilder
    private func group<Content: View>(_ title: String, icon: String,
                                      @ViewBuilder content: () -> Content) -> some View {
        let isOpen = expanded.contains(title)
        Section {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    if isOpen { expanded.remove(title) } else { expanded.insert(title) }
                }
                Haptic.tick()
            } label: {
                HStack(spacing: 11) {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#5865F2"))
                        .frame(width: 20)
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .rotationEffect(.degrees(isOpen ? 0 : -90))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 3)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isOpen {
                content()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func footerText(_ s: String) -> some View {
        Text(s)
            .font(.footnote)
            .foregroundColor(.secondary)
            .padding(.top, 2)
    }

    // MARK: 声音试听

    private func playPreview() {
        if sound.isPlaying {
            sound.stopAmbient()
        } else if prefs.soundType != "none" {
            sound.startAmbient(type: prefs.soundType, volume: prefs.soundVolume)
        }
    }

    // MARK: 时长行

    private func minutesRow(_ title: String, _ value: Binding<Int>,
                            _ range: ClosedRange<Int>, _ step: Int) -> some View {
        Stepper(value: value, in: range, step: step) {
            HStack { Text(title); Spacer()
                Text("\(value.wrappedValue) 分钟").monospacedDigit()
                    .foregroundColor(.secondary) }
        }
    }

    // MARK: CSV

    private func exportCSV() {
        if let url = Store.shared.exportCSV() {
            shareURL = url
            Haptic.tick()
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
        let csv = "\u{FEFF}" + rows.joined(separator: "\n")   // BOM 兼容中文 Excel
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
