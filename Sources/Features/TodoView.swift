import SwiftUI
import CoreData

/// 任务 —— Things 式优雅版：大标题、彩色勾选圈、可折叠已完成
struct TodoView: View {

    @ObservedObject private var engine = FocusEngine.shared

    @State private var tasks: [TaskEntity] = []
    @State private var newText = ""
    @State private var editing: TaskEntity?
    @State private var showDone = false

    private var active: [TaskEntity] { tasks.filter { !$0.isDone } }
    private var done: [TaskEntity] { tasks.filter { $0.isDone } }

    var body: some View {
        NavigationView {
            List {
                metaHeader

                Section {
                    addFieldRow
                }

                if active.isEmpty && done.isEmpty {
                    grandEmpty
                }

                if !active.isEmpty {
                    Section {
                        ForEach(active) { row($0) }
                    }
                }

                if !done.isEmpty {
                    Section {
                        doneToggle
                        if showDone {
                            ForEach(done) { row($0) }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("任务")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !done.isEmpty {
                        Button("清空") {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                done.forEach { Store.shared.deleteTask($0) }
                            }
                            Haptic.tick()
                            reload()
                        }
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
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

    // MARK: 头部元信息（日期 + 进度）

    private var metaHeader: some View {
        let total = tasks.count
        let frac = total > 0 ? Double(done.count) / Double(total) : 0
        return Section {
            VStack(alignment: .leading, spacing: 10) {
                Text(Self.dateLine)
                    .font(DS.F.microCaps)
                    .kerning(1.2)
                    .foregroundColor(.secondary)

                HStack(alignment: .firstTextBaseline) {
                    Text(active.isEmpty && !tasks.isEmpty ? "全部完成"
                         : "\(active.count) 项待办")
                        .font(DS.F.title2)
                    Spacer()
                    if total > 0 {
                        Text("\(Int(frac * 100))%")
                            .font(.system(size: 13, weight: .semibold))
                            .monospacedDigit()
                            .foregroundColor(frac >= 1 ? Color(hex: "#2FA84F")
                                                       : Color(hex: "#5865F2"))
                    }
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.12))
                        Capsule()
                            .fill(frac >= 1 ? AnyShapeStyle(Color(hex: "#2FA84F"))
                                            : AnyShapeStyle(Color(hex: "#5865F2")))
                            .frame(width: max(0, geo.size.width * CGFloat(frac)))
                            .animation(.spring(response: 0.4, dampingFraction: 0.8),
                                       value: frac)
                    }
                }
                .frame(height: 4)
            }
            .padding(.vertical, 8)
            .listRowSeparator(.hidden)
        }
    }

    private static var dateLine: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 EEEE"
        return f.string(from: Date()).uppercased()
    }

    // MARK: 行

    private func row(_ t: TaskEntity) -> some View {
        let isActive = engine.currentTaskID == t.id
        return HStack(spacing: 13) {
            // 彩色勾选圈（颜色即任务）
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.62)) {
                    Store.shared.setDone(t, !t.isDone)
                }
                t.isDone ? Haptic.success() : Haptic.tick()
                reload()
            } label: {
                ZStack {
                    Circle()
                        .stroke(t.isDone ? Color(hex: t.colorHex)
                                         : Color(hex: t.colorHex).opacity(0.55),
                                lineWidth: 2.4)
                        .frame(width: 28, height: 28)
                    if t.isDone {
                        Circle().fill(Color(hex: t.colorHex))
                            .frame(width: 28, height: 28)
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundColor(.white)
                            .transition(.scale(scale: 0.5).combined(with: .opacity))
                    }
                }
                .scaleEffect(t.isDone ? 1.05 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.55), value: t.isDone)
                .frame(width: DS.H.touchMin, height: DS.H.touchMin)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text(t.name)
                .font(.system(size: 16,
                              weight: t.isDone ? .regular : .medium))
                .strikethrough(t.isDone, color: .secondary)
                .foregroundColor(t.isDone ? .secondary : .primary)
                .lineLimit(1)

            Spacer(minLength: 8)

            if isActive {
                Circle()
                    .fill(Color(hex: t.colorHex))
                    .frame(width: 7, height: 7)
                    .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                    .shadow(color: Color(hex: t.colorHex).opacity(0.6), radius: 4)
                Image(systemName: "timer")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#5865F2"))
            }

            Spacer(minLength: 8)

            if let total = Self.totalText(t.id) {
                Text(total)
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundColor(.secondary.opacity(0.65))
            }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture { editing = t }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.62)) {
                    Store.shared.setDone(t, !t.isDone)
                }
                Haptic.tick()
                reload()
            } label: {
                Label(t.isDone ? "撤销" : "完成",
                      systemImage: t.isDone ? "arrow.uturn.backward" : "checkmark")
            }
            .tint(Color(hex: "#2FA84F"))
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                let wasCurrent = engine.currentTaskID == t.id
                withAnimation { Store.shared.deleteTask(t) }
                if wasCurrent { engine.select(taskID: nil) }
                reload()
            } label: { Label("删除", systemImage: "trash") }

            if !t.isDone {
                Button {
                    Haptic.tick()
                    engine.select(taskID: t.id)
                    reload()
                } label: { Label("设为当前", systemImage: "timer") }
                .tint(Color(hex: "#5865F2"))
            }
        }
    }

    // MARK: 已完成折叠头

    private var doneToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.28)) { showDone.toggle() }
            Haptic.tick()
        } label: {
            HStack(spacing: 6) {
                Text("已完成 · \(done.count)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .rotationEffect(.degrees(showDone ? 0 : -90))
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: 快速添加

    private var addFieldRow: some View {
        HStack(spacing: 11) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 19))
                .foregroundStyle(
                    LinearGradient(colors: [Color(hex: "#6A79FF"), Color(hex: "#4C50E0")],
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
            TextField("想到什么就记下来…", text: $newText)
                .font(.system(size: 15))
                .onSubmit(add)
            if newText.trimmingCharacters(in: .whitespaces).isEmpty {
                Text("回车")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .overlay(Capsule().stroke(Color.secondary.opacity(0.3), lineWidth: 1))
            } else {
                Button {
                    add()
                } label: {
                    Text("添加")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color(hex: "#5865F2")))
                }
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
    }

    private func add() {
        let name = newText.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            Store.shared.addTask(name: name)
        }
        newText = ""; Haptic.tick(); reload()
    }

    // MARK: 大气空态

    private var grandEmpty: some View {
        Section {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(Color(hex: "#5865F2").opacity(0.18), lineWidth: 2)
                        .frame(width: 74, height: 74)
                    Image(systemName: "checkmark")
                        .font(.system(size: 26, weight: .light))
                        .foregroundColor(Color(hex: "#5865F2").opacity(0.55))
                }
                .padding(.top, 18)
                Text("今天想专注点什么？")
                    .font(.system(size: 16, weight: .medium))
                Text("上方输入框直接添加")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 20)
            .listRowSeparator(.hidden)
        }
    }

    private func reload() { tasks = Store.shared.tasks() }

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

/// 任务编辑（沿用）
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
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        Store.shared.deleteTask(task)
                        onDone()
                    }
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
