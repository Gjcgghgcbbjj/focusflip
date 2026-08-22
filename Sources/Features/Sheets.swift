import SwiftUI

/// 任务选择（Flow：选任务 = 选颜色 = 选整个界面）
struct TaskPickerSheet: View {

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var engine = FocusEngine.shared

    @State private var tasks: [TaskEntity] = []
    @State private var newTaskName = ""

    var body: some View {
        NavigationView {
            .background(SheetDetents())

            List {
                // 不关联任务
                row(id: nil, name: "不关联任务", colorHex: "#5865F2")

                ForEach(tasks) { t in
                    row(id: t.id, name: t.name, colorHex: t.colorHex)
                }

            }
            .listStyle(.plain)
            .navigationTitle("选择任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Text("新建与管理请到「任务」标签页")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)
            }
            .onAppear(perform: reload)
        }
    }

    private func row(id: UUID?, name: String, colorHex: String) -> some View {
        let selected = engine.currentTaskID == id
        return Button {
            Haptic.tick()
            engine.select(taskID: id)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Circle().fill(Color(hex: colorHex)).frame(width: 10, height: 10)
                Text(name).foregroundColor(.primary)
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(hex: colorHex))
                }
            }
        }
    }

    private func reload() { tasks = Store.shared.tasks() }
}

/// 时长精调（chips 尾部 ··· 进入）
struct DurationTuneSheet: View {

    @ObservedObject private var prefs = Prefs.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            .background(SheetDetents())
            Form {
                Section("专注") {
                    minutesRow("时长", $prefs.focusMinutes, range: 1...180, step: 5)
                }
                Section("休息") {
                    minutesRow("小憩", $prefs.shortMinutes, range: 1...60, step: 1)
                    minutesRow("长歇", $prefs.longMinutes, range: 1...120, step: 5)
                    Stepper(value: $prefs.longEvery, in: 2...8) {
                        captionRow("长歇间隔", "每 \(prefs.longEvery) 个番茄")
                    }
                }
            }
            .navigationTitle("时长")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }.font(.system(size: 17, weight: .semibold))
                }
            }
        }
    }

    private func minutesRow(_ title: String, _ value: Binding<Int>,
                            range: ClosedRange<Int>, step: Int) -> some View {
        Stepper(value: value, in: range, step: step) {
            captionRow(title, "\(value.wrappedValue) 分钟")
        }
    }

    private func captionRow(_ title: String, _ detail: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(detail).monospacedDigit().foregroundColor(.secondary)
        }
    }
}
