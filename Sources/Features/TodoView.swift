import SwiftUI
import CoreData

/// TODO 任务列表（精致版）
struct TodoView: View {

    @ObservedObject private var engine = FocusEngine.shared
    private let accent = Color(hex: "#5865F2")

    @State private var tasks: [TaskEntity] = []
    @State private var newText = ""
    @State private var editing: TaskEntity?

    private var active: [TaskEntity] { tasks.filter { !$0.isDone } }
    private var done: [TaskEntity] { tasks.filter { $0.isDone } }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                progressHeader
                list
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !done.isEmpty {
                        Button {
                            Haptic.tick()
                            done.forEach { Store.shared.deleteTask($0) }
                            reload()
                        } label: {
                            Text("清空完成").font(.system(size: 13))
                        }
                    }
                }
            }
            .onAppear(perform: reload)
            .sheet(item: $editing) { t in
                TaskEditSheet(task: t) { reload() }
                    .onDisappear { reload() }
            }
        }
    }

    // MARK: 进度头卡

    private var progressHeader: some View {
        let total = tasks.count
        let dn = done.count
        let frac = total > 0 ? Double(dn) / Double(total) : 0

        return VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(dn)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(accent)
                Text("/ \(total) 已完成")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(frac * 100))%")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(frac >= 1 && total > 0 ? Color(hex: "#2FA84F") : accent)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(accent.opacity(0.12))
                    Capsule().fill(frac >= 1 ? AnyShapeStyle(Color(hex: "#2FA84F"))
                                             : AnyShapeStyle(accent))
                        .frame(width: max(0, geo.size.width * CGFloat(frac)))
                        .animation(.easeInOut(duration: 0.35), value: frac)
                }
            }
            .frame(height: 6)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: 列表

    private var list: some View {
        List {
            if active.isEmpty && done.isEmpty {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "tray")
                            .font(.system(size: 30))
                            .foregroundColor(.secondary.opacity(0.4))
                        Text("添加第一个任务，它会成为计时的配色来源")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 26)
                }
                Section { addFieldRow }
            } else if active.isEmpty {
                Section {
                    Text("全部完成 🎉")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                Section { addFieldRow }
            }
            if !active.isEmpty {
                Section("进行中 · \(active.count)") {
                    addFieldRow
                    ForEach(active) { row($0) }
                }
            }
            if !done.isEmpty {
                Section("已完成 · \(done.count)") {
                    ForEach(done) { row($0) }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var addFieldRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 17))
                .foregroundColor(accent)
            TextField("新建任务，回车快速添加", text: $newText)
                .onSubmit(add)
            if !newText.isEmpty {
                Button("添加") { add() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(accent)
            }
        }
        .padding(.vertical, 2)
    }

    private func add() {
        let name = newText.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        Store.shared.addTask(name: name)
        newText = ""; reload(); Haptic.tick()
    }

    private func reload() { tasks = Store.shared.tasks() }

    // MARK: 行

    private func row(_ t: TaskEntity) -> some View {
        let isActive = engine.currentTaskID == t.id
        return HStack(spacing: 12) {
            Button {
                Haptic.tick()
                Store.shared.setDone(t, !t.isDone)
                reload()
            } label: {
                ZStack {
                    Circle()
                        .stroke(t.isDone ? Color(hex: "#2FA84F") : accent.opacity(0.45),
                                lineWidth: 1.8)
                        .frame(width: 23, height: 23)
                    if t.isDone {
                        Circle().fill(Color(hex: "#2FA84F")).frame(width: 19, height: 19)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            Circle().fill(Color(hex: t.colorHex)).frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 3) {
                Text(t.name)
                    .font(.system(size: 15, weight: t.isDone ? .regular : .medium))
                    .strikethrough(t.isDone, color: .secondary)
                    .foregroundColor(t.isDone ? .secondary : .primary)
                    .lineLimit(1)
                if let total = Self.totalText(t.id) {
                    Text("累计 \(total)")
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundColor(.secondary.opacity(0.75))
                }
            }

            Spacer(minLength: 8)

            if isActive {
                Label("计时中", systemImage: "timer")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(accent)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(accent.opacity(0.12)))
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.4))
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture { editing = t }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                Haptic.tick()
                Store.shared.setDone(t, !t.isDone)
                reload()
            } label: {
                Label(t.isDone ? "撤销" : "完成",
                      systemImage: t.isDone ? "arrow.uturn.backward" : "checkmark")
            }
            .tint(Color(hex: "#2FA84F"))
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                if engine.currentTaskID == t.id { engine.select(taskID: nil) }
                Store.shared.deleteTask(t); reload()
            } label: { Label("删除", systemImage: "trash") }

            if !t.isDone {
                Button {
                    Haptic.tick(); engine.select(taskID: t.id); reload()
                } label: { Label("设为当前", systemImage: "timer") }
                .tint(accent)
            }
        }
    }

    static func totalText(_ id: UUID?) -> String? {
        guard let id else { return nil }
        let req: NSFetchRequest<SessionEntity> = SessionEntity.fetchRequest()
        req.predicate = NSPredicate(format: "taskId == %@ AND completed == YES", id as CVarArg)
        let secs = ((try? Store.shared.context.fetch(req)) ?? [])
            .reduce(0) { $0 + Int($1.durationSeconds) }
        guard secs > 60 else { return nil }
        let h = secs / 3600, m = (secs % 3600) / 60
        return h > 0 ? String(format: "%.1fh", Double(secs) / 3600) : "\(m) 分钟"
    }
}

/// 任务编辑（名称/颜色/状态/删除）
struct TaskEditSheet: View {
    let task: TaskEntity
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var colorHex = "#5865F2"
    @State private var isDone = false
    @State private var confirmDelete = false

    private let palette = ["#5865F2", "#E5573F", "#2FA84F", "#1E88C7",
                           "#9C27B0", "#E8912D", "#2AA198", "#D81B60"]

    var body: some View {
        NavigationView {
            Form {
                Section("名称") {
                    HStack(spacing: 10) {
                        Circle().fill(Color(hex: colorHex)).frame(width: 9, height: 9)
                        TextField("任务名", text: $name)
                    }
                }
                Section("颜色") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8),
                              spacing: 12) {
                        ForEach(palette, id: \.self) { hex in
                            Button {
                                colorHex = hex; Haptic.tick()
                            } label: {
                                ZStack {
                                    Circle().fill(Color(hex: hex)).frame(width: 28, height: 28)
                                    if colorHex == hex {
                                        Circle()
                                            .stroke(Color.primary.opacity(0.7), lineWidth: 2)
                                            .frame(width: 36, height: 36)
                                    }
                                }
                            }
                            .frame(height: 38)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section {
                    Toggle("标记为已完成", isOn: $isDone)
                }
                Section {
                    Button(role: .destructive) { confirmDelete = true } label: {
                        Label("删除任务", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("编辑任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        task.name = name.isEmpty ? task.name : name
                        task.colorHex = colorHex
                        if task.isDone != isDone { Store.shared.setDone(task, isDone) }
                        else { Store.shared.save() }
                        onDone(); dismiss()
                    }.font(.system(size: 17, weight: .semibold))
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .confirmationDialog("删除这个任务？其专注记录会保留",
                                isPresented: $confirmDelete,
                                titleVisibility: .visible) {
                Button("删除", role: .destructive) {
                    Store.shared.deleteTask(task)
                    onDone(); dismiss()
                }
                Button("取消", role: .cancel) {}
            }
            .onAppear {
                name = task.name
                colorHex = task.colorHex
                isDone = task.isDone
            }
        }
    }
}
