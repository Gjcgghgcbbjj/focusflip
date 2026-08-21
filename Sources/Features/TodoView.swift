import SwiftUI

/// TODO 任务列表（任务即计时配色来源，也是待办）
struct TodoView: View {

    @ObservedObject private var engine = FocusEngine.shared
    @State private var tasks: [TaskEntity] = []
    @State private var newText = ""
    @State private var editing: TaskEntity?

    var body: some View {
        NavigationView {
            List {
                addField

                let active = tasks.filter { !$0.isDone }
                let done = tasks.filter { $0.isDone }
                if active.isEmpty {
                    Section {
                        Text(active.isEmpty && done.isEmpty ? "添加第一个任务吧" : "全部完成 🎉")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                if !active.isEmpty {
                    Section("进行中") { ForEach(active) { row($0) } }
                }
                if !done.isEmpty {
                    Section("已完成") { ForEach(done) { row($0) } }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("任务")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if tasks.contains(where: { $0.isDone }) {
                        Button("清空完成") {
                            tasks.filter { $0.isDone }.forEach { Store.shared.deleteTask($0) }
                            reload()
                        }
                        .font(.system(size: 13))
                    }
                }
            }
            .onAppear(perform: reload)
            .sheet(item: $editing) { t in TaskEditSheet(task: t) { reload() } }
        }
    }

    // MARK: 行

    private func row(_ t: TaskEntity) -> some View {
        HStack(spacing: 12) {
            Button {
                Haptic.tick()
                Store.shared.setDone(t, !t.isDone)
                reload()
            } label: {
                Image(systemName: t.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 21))
                    .foregroundColor(t.isDone ? Color(hex: "#2FA84F") : Color(hex: "#5865F2").opacity(0.55))
            }
            .buttonStyle(.plain)

            Circle().fill(Color(hex: t.colorHex)).frame(width: 8, height: 8)

            Text(t.name)
                .strikethrough(t.isDone, color: .secondary)
                .foregroundColor(t.isDone ? .secondary : .primary)

            Spacer()

            if engine.currentTaskID == t.id {
                Image(systemName: "timer")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#5865F2"))
            }

            Text(Self.totalFor(t.id))
                .font(.system(size: 11).monospacedDigit())
                .foregroundColor(.secondary)

            Button {
                editing = t
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                if engine.currentTaskID == t.id { engine.select(taskID: nil) }
                Store.shared.deleteTask(t); reload()
            } label: { Label("删除", systemImage: "trash") }

            Button {
                Haptic.tick(); engine.select(taskID: t.id); reload()
            } label: { Label("设为当前", systemImage: "timer") }
            .tint(Color(hex: "#5865F2"))
        }
    }

    private var addField: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill").foregroundColor(Color(hex: "#5865F2"))
            TextField("新建任务，回车添加", text: $newText)
                .onSubmit(add)
            Button("添加") { add() }.disabled(newText.isEmpty)
        }
    }

    private func add() {
        let name = newText.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        Store.shared.addTask(name: name)
        newText = ""; reload(); Haptic.tick()
    }

    private func reload() { tasks = Store.shared.tasks() }

    static func totalFor(_ id: UUID?) -> String {
        guard let id else { return "" }
        let req: NSFetchRequest<SessionEntity> = SessionEntity.fetchRequest()
        req.predicate = NSPredicate(format: "taskId == %@ AND completed == YES", id as CVarArg)
        let secs = ((try? Store.shared.context.fetch(req)) ?? [])
            .reduce(0) { $0 + Int($1.durationSeconds) }
        guard secs > 0 else { return "" }
        let h = secs / 3600, m = (secs % 3600) / 60
        return h > 0 ? String(format: "%.1fh", Double(secs) / 3600) : "\(m)m"
    }
}

/// 任务编辑
struct TaskEditSheet: View {
    let task: TaskEntity
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var colorHex = "#5865F2"

    private let palette = ["#5865F2", "#E5573F", "#2FA84F", "#1E88C7",
                           "#9C27B0", "#E8912D", "#2AA198", "#D81B60"]

    var body: some View {
        NavigationView {
            Form {
                Section("名称") {
                    TextField("任务名", text: $name)
                }
                Section("颜色") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 10) {
                        ForEach(palette, id: \.self) { hex in
                            Button {
                                colorHex = hex; Haptic.tick()
                            } label: {
                                ZStack {
                                    Circle().fill(Color(hex: hex)).frame(width: 30, height: 30)
                                    if colorHex == hex {
                                        Circle().stroke(Color.primary, lineWidth: 2).frame(width: 36, height: 36)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("编辑任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        task.name = name.isEmpty ? task.name : name
                        task.colorHex = colorHex
                        Store.shared.save()
                        onDone(); dismiss()
                    }.font(.system(size: 17, weight: .semibold))
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .onAppear { name = task.name; colorHex = task.colorHex }
        }
    }
}
