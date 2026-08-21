import SwiftUI
import CoreData

/// 设置 —— 行为 / 声音(新家) / 时长(完整编辑) / 数据(CSV) / 关于
struct SettingsView: View {

    @ObservedObject private var prefs = Prefs.shared
    @ObservedObject private var engine = FocusEngine.shared
    @ObservedObject private var sound = SoundPlayer.shared

    @State private var shareURL: URL?

    var body: some View {
        NavigationView {
            Form {
                behaviorSection
                soundSection
                durationSection
                dataSection
                aboutSection
            }
            .navigationTitle("设置")
            .sheet(isPresented: Binding(
                get: { shareURL != nil },
                set: { if !$0 { shareURL = nil } })) {
                if let url = shareURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    // MARK: 行为

    private var behaviorSection: some View {
        Section {
            Toggle("休息自动开始", isOn: $prefs.autoStartBreaks)
            Toggle("专注自动接续", isOn: $prefs.autoStartFocus)
            Toggle("专注时保持屏幕常亮", isOn: $prefs.keepAwake)
        } header: {
            Text("行为")
        } footer: {
            Text("阶段结束后自动进入下一阶段，无需手动点按。")
        }
    }

    // MARK: 声音（从主屏小图标迁来的正式家）

    private var soundSection: some View {
        Section {
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
                Button {
                    playPreview()
                } label: {
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
            Button {
                SoundPlayer.shared.playTone(prefs.toneType)
            } label: {
                Text("试听提示音").foregroundColor(Color(hex: "#5865F2"))
            }
        } header: {
            Text("声音")
        } footer: {
            Text("环境音在开始专注时自动响起，结束自动停止。")
        }
        .onDisappear { if !engine.isRunning { sound.stopAmbient() } }
    }

    private func playPreview() {
        if sound.isPlaying {
            sound.stopAmbient()
        } else if prefs.soundType != "none" {
            sound.startAmbient(type: prefs.soundType, volume: prefs.soundVolume)
        }
    }

    // MARK: 时长（完整编辑）

    private var durationSection: some View {
        Section {
            minutesRow("默认专注", $prefs.focusMinutes, 1...180, 5)
            minutesRow("小憩", $prefs.shortMinutes, 1...60, 1)
            minutesRow("长歇", $prefs.longMinutes, 1...120, 5)
            Stepper(value: $prefs.longEvery, in: 2...8) {
                HStack { Text("长歇间隔"); Spacer()
                    Text("每 \(prefs.longEvery) 个番茄").monospacedDigit()
                        .foregroundColor(.secondary) }
            }
        } header: {
            Text("时长")
        } footer: {
            Text("计时页的时长条可快速切换常用值。")
        }
    }

    private func minutesRow(_ title: String, _ value: Binding<Int>,
                            _ range: ClosedRange<Int>, _ step: Int) -> some View {
        Stepper(value: value, in: range, step: step) {
            HStack { Text(title); Spacer()
                Text("\(value.wrappedValue) 分钟").monospacedDigit()
                    .foregroundColor(.secondary) }
        }
    }

    // MARK: 数据

    private var dataSection: some View {
        Section {
            Button {
                exportCSV()
            } label: {
                Label("导出全部记录 (CSV)", systemImage: "square.and.arrow.up")
                    .foregroundColor(Color(hex: "#5865F2"))
            }
        } header: {
            Text("数据")
        } footer: {
            Text("导出所有专注记录，可用表格软件打开。")
        }
    }

    private func exportCSV() {
        if let url = Store.shared.exportCSV() {
            shareURL = url
            Haptic.tick()
        }
    }

    // MARK: 关于

    private var aboutSection: some View {
        Section {
            HStack { Text("版本"); Spacer()
                Text(appVersion).foregroundColor(.secondary) }
        } header: {
            Text("关于")
        } footer: {
            Text("Flow 风格的极简专注计时器 · 个人自用")
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
            let phase = SessionPhaseName(s.phaseRaw)
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
}

private func SessionPhaseName(_ raw: String) -> String {
    switch raw {
    case Phase.focus.rawValue: return "专注"
    case Phase.shortBreak.rawValue: return "小憩"
    case Phase.longBreak.rawValue: return "长歇"
    default: return raw
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
