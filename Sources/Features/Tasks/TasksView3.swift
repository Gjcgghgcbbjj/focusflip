import SwiftUI

/// FocusFlip 3.0 — 任务页。
/// List + 左滑完成/右滑删除 + 点击编辑 + 手动标记可逆。
struct TasksView3: View {

    @State private var tasks: [TaskItem] = []
    @State private var showingAdd = false
    @State private var editing: TaskItem?

    var body: some View {
        NavigationView {
            Group {
                if tasks.isEmpty {
                    empty
                } else {
                    list
                }
            }
            .background(DS3.Color.bg.ignoresSafeArea())
            .navigationTitle("任务")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingAdd = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 19, weight: .medium))
                            .foregroundColor(DS3.Color.accent)
                    }
                }
            }
            .sheet(isPresented: $showingAdd) { TaskEditSheet3(task: nil) { reload() } }
            .sheet(item: $editing) { t in TaskEditSheet3(task: t) { reload() } }
            .onAppear { reload() }
        }
    }

    private var list: some View {
        List {
            ForEach(tasks) { task in
                TaskRow3(task: task)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: DS3.S.md,
                                              bottom: 4, trailing: DS3.S.md))
                    .contentShape(Rectangle())
                    .onTapGesture { editing = task }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) { delete(task) } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            toggleDone(task)
                        } label: {
                            Label(task.completed ? "未完成" : "完成",
                                  systemImage: task.completed ? "circle" : "checkmark.circle.fill")
                        }
                        .tint(task.completed ? DS3.Color.textDim : DS3.Color.shortBreak)
                    }
            }
        }
        .listStyle(.plain)
        .hideScrollBackground3()
    }

    private var empty: some View {
        VStack(spacing: DS3.S.md) {
            Image(systemName: "checklist")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(DS3.Color.textDim)
            Text("还没有任务").font(DS3.Font.title).foregroundColor(DS3.Color.text)
            Text("创建任务来追踪你的番茄进度")
                .font(DS3.Font.sub).foregroundColor(DS3.Color.textDim)
            Button { showingAdd = true } label: {
                Text("新建任务")
                    .font(DS3.Font.headline)
                    .foregroundColor(DS3.Color.bg)
                    .padding(.horizontal, DS3.S.lg)
                    .padding(.vertical, DS3.S.sm + 4)
                    .background(Capsule().fill(DS3.Color.accent))
            }
            .pressable3()
            .padding(.top, DS3.S.xs)
        }
    }

    private func reload() { tasks = PersistenceController.shared.fetchTasks() }

    private func delete(_ task: TaskItem) {
        PersistenceController.shared.viewContext.delete(task)
        PersistenceController.shared.save()
        HapticManager.shared.light()
        reload()
    }

    private func toggleDone(_ task: TaskItem) {
        task.completed.toggle()
        PersistenceController.shared.save()
        HapticManager.shared.selection()
        reload()
    }
}

// MARK: - Row

private struct TaskRow3: View {
    let task: TaskItem

    var body: some View {
        HStack(spacing: DS3.S.md) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: task.colorHex))
                .frame(width: 3, height: 44)

            VStack(alignment: .leading, spacing: DS3.S.xs) {
                Text(task.title)
                    .font(DS3.Font.body.weight(.medium))
                    .foregroundColor(task.completed ? DS3.Color.textDim : DS3.Color.text)
                    .strikethrough(task.completed)

                if !task.note.isEmpty {
                    Text(task.note)
                        .font(DS3.Font.caption)
                        .foregroundColor(DS3.Color.textDim)
                        .lineLimit(1)
                }

                HStack(spacing: DS3.S.sm) {
                    ProgressView(value: task.progress)
                        .tint(Color(hex: task.colorHex))
                        .frame(height: 3)
                    Text("\(task.completedPomodoros)/\(task.estimatedPomodoros)")
                        .font(DS3.Font.micro)
                        .monospacedDigit()
                        .foregroundColor(DS3.Color.textDim)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: task.completed ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundColor(task.completed ? Color(hex: task.colorHex) : DS3.Color.hairline)
        }
        .card3(inset: DS3.S.md)
    }
}

// MARK: - Edit sheet

struct TaskEditSheet3: View {
    let task: TaskItem?
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var note = ""
    @State private var estimate = 1
    @State private var colorHex = "#FF4D4A"

    private let palette = ["#FF4D4A", "#FF9F0A", "#30D158", "#64D2FF",
                           "#BF5AF2", "#FF2D55", "#FFD60A", "#0A84FF"]

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("任务名称", text: $title)
                    TextField("备注（可选）", text: $note)
                }
                Section("预估番茄") {
                    Stepper(value: $estimate, in: 1...20) {
                        Text("\(estimate) 个").monospacedDigit()
                    }
                }
                Section("颜色") {
                    HStack(spacing: DS3.S.sm) {
                        ForEach(palette, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle().stroke(DS3.Color.text,
                                                    lineWidth: colorHex == hex ? 2 : 0)
                                )
                                .onTapGesture { colorHex = hex; HapticManager.shared.selection() }
                        }
                    }
                }
            }
            .hideScrollBackground3()
            .navigationTitle(task == nil ? "新建任务" : "编辑任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.foregroundColor(DS3.Color.textDim)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(DS3.Color.accent)
                        .disabled(title.isEmpty)
                }
            }
            .onAppear { load() }
        }
    }

    private func load() {
        guard let t = task else { return }
        title = t.title
        note = t.note
        estimate = Int(t.estimatedPomodoros)
        colorHex = t.colorHex
    }

    private func save() {
        let ctx = PersistenceController.shared.viewContext
        let target: TaskItem
        if let t = task {
            target = t
        } else {
            target = TaskItem(context: ctx)
            target.id = UUID()
            target.createdAt = Date()
            target.sortOrder = Int32(PersistenceController.shared.fetchTasks().count)
        }
        target.title = title
        target.note = note
        target.estimatedPomodoros = Int32(estimate)
        target.colorHex = colorHex
        PersistenceController.shared.save()
        onDone()
        dismiss()
    }
}
