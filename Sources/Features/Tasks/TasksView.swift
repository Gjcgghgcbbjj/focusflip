import SwiftUI

/// Task list screen with card-based design.
struct TasksView: View {

    @State private var tasks: [TaskItem] = []
    @State private var showingAddSheet = false
    @State private var editingTask: TaskItem?

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: DS.S.sm) {
                    if tasks.isEmpty {
                        emptyState
                            .padding(.top, DS.S.xxl)
                    } else {
                        ForEach(tasks) { task in
                            TaskCard(task: task)
                                .onTapGesture { editingTask = task }
                                .contextMenu {
                                    Button(action: { editingTask = task }) {
                                        Label("编辑", systemImage: "pencil")
                                    }
                                    Button(role: .destructive, action: { delete(task) }) {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
                .padding(.horizontal, DS.S.md)
                .padding(.bottom, DS.S.xxxl)
            }
            .background(DS.Color.bgPrimary.ignoresSafeArea())
            .navigationTitle("任务")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(DS.Color.accent)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                TaskEditSheet(task: nil) { reload() }
            }
            .sheet(item: $editingTask) { task in
                TaskEditSheet(task: task) { reload() }
            }
            .onAppear { reload() }
        }
            }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: DS.S.md) {
            Image(systemName: "checklist")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(DS.Color.textMuted)
            Text("还没有任务")
                .font(DS.Font.headline)
                .foregroundColor(DS.Color.textSecondary)
            Text("创建任务来追踪你的番茄进度")
                .font(DS.Font.caption)
                .foregroundColor(DS.Color.textMuted)
            Button(action: { showingAddSheet = true }) {
                Text("新建任务")
                    .font(DS.Font.captionBold)
                    .foregroundColor(DS.Color.bgPrimary)
                    .padding(.horizontal, DS.S.lg)
                    .padding(.vertical, DS.S.sm + 2)
                    .background(Capsule().fill(DS.Color.accent))
            }
            .pressable()
            .padding(.top, DS.S.xs)
        }
    }

    private func reload() {
        tasks = PersistenceController.shared.fetchTasks()
    }

    private func delete(_ task: TaskItem) {
        let ctx = PersistenceController.shared.viewContext
        ctx.delete(task)
        PersistenceController.shared.save()
        reload()
    }
}

// MARK: - Task card

private struct TaskCard: View {
    let task: TaskItem

    var body: some View {
        HStack(spacing: DS.S.md) {
            // Left accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: task.colorHex))
                .frame(width: 3)

            VStack(alignment: .leading, spacing: DS.S.xs) {
                Text(task.title)
                    .font(DS.Font.body)
                    .foregroundColor(DS.Color.textPrimary)
                    .strikethrough(task.completed, color: DS.Color.textMuted)

                if !task.note.isEmpty {
                    Text(task.note)
                        .font(DS.Font.caption)
                        .foregroundColor(DS.Color.textMuted)
                        .lineLimit(1)
                }

                // Progress
                HStack(spacing: DS.S.sm) {
                    ProgressView(value: task.progress)
                        .tint(Color(hex: task.colorHex))
                        .frame(height: 3)

                    Text("\(task.completedPomodoros)/\(task.estimatedPomodoros)")
                        .font(DS.Font.micro)
                        .foregroundColor(DS.Color.textMuted)
                        .monospacedDigit()
                }
            }

            Spacer()

            if task.isDone {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color(hex: task.colorHex))
                    .font(.system(size: 20))
            }
        }
        .card()
        .background(
            RoundedRectangle(cornerRadius: DS.R.lg)
                .fill(DS.Color.bgSecondary)
        )
    }
}

// MARK: - Edit sheet

private struct TaskEditSheet: View {
    let task: TaskItem?
    let onDone: () -> Void

    @Environment(\.dismiss) var dismiss
    @State private var title = ""
    @State private var note = ""
    @State private var estimatedPomodoros = 1
    @State private var colorHex = "#f38ba8"

    private let colors = ["#f38ba8", "#a6e3a1", "#89b4fa", "#cba6f7",
                          "#f9e2af", "#94e2d5", "#fab387", "#eba0ac"]

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("任务名称", text: $title)
                        .font(DS.Font.body)
                    TextField("备注（可选）", text: $note)
                        .font(DS.Font.body)
                }

                Section("预估番茄数") {
                    Stepper(value: $estimatedPomodoros, in: 1...20) {
                        HStack {
                            Image(systemName: "timer")
                                .foregroundColor(DS.Color.textMuted)
                            Text("\(estimatedPomodoros) 个")
                                .font(DS.Font.body)
                        }
                    }
                }

                Section("颜色") {
                    HStack(spacing: DS.S.sm) {
                        ForEach(colors, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle()
                                        .stroke(DS.Color.textPrimary,
                                                lineWidth: colorHex == hex ? 2 : 0)
                                )
                                .onTapGesture { colorHex = hex }
                        }
                    }
                }
            }
            .hideScrollBackground()
            .background(DS.Color.bgPrimary.ignoresSafeArea())
            .navigationTitle(task == nil ? "新建任务" : "编辑任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundColor(DS.Color.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .font(DS.Font.captionBold)
                        .foregroundColor(DS.Color.accent)
                        .disabled(title.isEmpty)
                }
            }
            .onAppear { loadTask() }
        }
            }

    private func loadTask() {
        guard let t = task else { return }
        title = t.title
        note = t.note
        estimatedPomodoros = Int(t.estimatedPomodoros)
        colorHex = t.colorHex
    }

    private func save() {
        let ctx = PersistenceController.shared.viewContext
        let target: TaskItem
        if let task = task {
            target = task
        } else {
            target = TaskItem(context: ctx)
            target.id = UUID()
            target.createdAt = Date()
            target.sortOrder = Int32(PersistenceController.shared.fetchTasks().count)
        }
        target.title = title
        target.note = note
        target.estimatedPomodoros = Int32(estimatedPomodoros)
        target.colorHex = colorHex
        PersistenceController.shared.save()
        onDone()
        dismiss()
    }
}
