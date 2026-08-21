import SwiftUI

struct SettingsView: View {

    @ObservedObject private var prefs = Prefs.shared
    @ObservedObject private var engine = FocusEngine.shared
    @State private var showCountdown = false

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("休息自动开始", isOn: $prefs.autoStartBreaks)
                    Toggle("专注自动接续", isOn: $prefs.autoStartFocus)
                    Toggle("专注时保持屏幕常亮", isOn: $prefs.keepAwake)
                } header: { Text("行为") } footer: {
                    Text("开启后阶段结束无需手动点按，自动进入下一阶段。")
                }

                Section("时长") {
                    HStack { Text("默认专注"); Spacer()
                        Text("\(prefs.focusMinutes) 分钟").monospacedDigit().foregroundColor(.secondary) }
                    HStack { Text("小憩"); Spacer()
                        Text("\(prefs.shortMinutes) 分钟").monospacedDigit().foregroundColor(.secondary) }
                    HStack { Text("长歇"); Spacer()
                        Text("\(prefs.longMinutes) 分钟").monospacedDigit().foregroundColor(.secondary) }
                    Text("在计时页的时长条或「···」里调整")
                        .font(.footnote).foregroundColor(.secondary)
                }

                Section {
                    HStack { Text("今日番茄"); Spacer()
                        Text("\(engine.todayPomodoros)").monospacedDigit().foregroundColor(.secondary) }
                } header: { Text("概览") }

                Section {
                    Button {
                        showCountdown = true
                    } label: {
                        HStack {
                            Text("日期倒计时")
                            Spacer()
                            Image(systemName: "calendar.badge.clock")
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                    }
                    .sheet(isPresented: $showCountdown) { CountdownSheet() }

                    HStack { Text("版本"); Spacer()
                        Text(appVersion).foregroundColor(.secondary) }
                } header: { Text("关于") } footer: {
                    Text("Flow 风格的极简专注计时器 · 个人自用")
                }
            }
            .navigationTitle("设置")
        }
    }

    private var appVersion: String {
        let v = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
        let b = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "1"
        return "\(v) (\(b))"
    }
}
