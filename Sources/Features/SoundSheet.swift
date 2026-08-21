import SwiftUI

/// 声音面板（主屏 waveform 按钮进入）
struct SoundSheet: View {

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var prefs = Prefs.shared
    @ObservedObject private var sound = SoundPlayer.shared

    var body: some View {
        NavigationView {
            Form {
                Section("环境音") {
                    Picker("音效", selection: $prefs.soundType) {
                        ForEach(SoundPlayer.ambientTypes, id: \.id) { t in
                            Text(t.name).tag(t.id)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    .onChange(of: prefs.soundType) { t in
                        if sound.isPlaying || (prefs.soundAutoPlay && engine.isRunning) {
                            if t != "none" { preview() } else { sound.stopAmbient() }
                        }
                    }

                    HStack {
                        Image(systemName: "speaker.fill").font(.caption).foregroundColor(.secondary)
                        Slider(value: $prefs.soundVolume, in: 0...1)
                            .onChange(of: prefs.soundVolume) { v in
                                sound.applyVolume(v)
                            }
                        Image(systemName: "speaker.wave.3.fill").font(.caption).foregroundColor(.secondary)
                    }

                    Toggle("专注时自动播放", isOn: $prefs.soundAutoPlay)

                    Button {
                        preview()
                    } label: {
                        Label(sound.isPlaying ? "停止试听" : "试听",
                              systemImage: sound.isPlaying ? "stop.circle" : "play.circle")
                    }
                }

                Section("完成提示音") {
                    Picker("提示音", selection: $prefs.toneType) {
                        ForEach(SoundPlayer.tones, id: \.id) { t in
                            Text(t.name).tag(t.id)
                        }
                    }
                    Button {
                        SoundPlayer.shared.playTone(prefs.toneType)
                    } label: {
                        Label("试听", systemImage: "play.circle")
                    }
                }
            }
            .navigationTitle("声音")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }.font(.system(size: 17, weight: .semibold))
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        // 离开面板：若非运行态则收掉试听
                        if !engine.isRunning { sound.stopAmbient() }
                        dismiss()
                    }
                }
            }
            .onDisappear {
                if !engine.isRunning { sound.stopAmbient() }
            }
        }
    }

    private var engine: FocusEngine { FocusEngine.shared }

    private func preview() {
        if sound.isPlaying && prefs.soundType != "none" {
            sound.stopAmbient()
        } else {
            sound.startAmbient(type: prefs.soundType, volume: prefs.soundVolume)
        }
    }
}
