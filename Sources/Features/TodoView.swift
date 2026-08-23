import SwiftUI
import CoreData

/// 任务页 —— Today 锚点 + Things 式安静列表。
struct TodoView: View {

    @ObservedObject private var engine = FocusEngine.shared
    @ObservedObject private var router = AppRouter.shared

    @State private var tasks: [TaskEntity] = []
    @State private var newText = ""
    @FocusState private var addFocused: Bool
    @State private var editing: TaskEntity?
    @State private var showDone = false
    @State private var showClearDone = false
    @State private var todaySecondsByTask: [UUID: Int] = [:]
    @State private var todayCountByTask: [UUID: Int] = [:]

    private var active: [TaskEntity] { tasks.filter { !$0.isDone } }
    private var done: [TaskEntity] { tasks.filter { $0.isDone } }

    private var currentTask: TaskEntity? {
        guard let id = engine.currentTaskID else { return nil }
        return tasks.first { $0.id == id && $0.managedObjectContext != nil }
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    progressHeader
                    todayFocusCard
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))

                Section {
                    addFieldRow
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))

                if active.isEmpty && done.isEmpty {
                    grandEmpty
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 16, trailing: 16))
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
                            Haptic.warning()
                            showClearDone = true
                        }
                        .font(DS.F.subheadSb)
                        .foregroundColor(.secondary)
                    }
                }
            }
            .confirmationDialog("清空已完成任务？", isPresented: $showClearDone,
                                titleVisibility: .visible) {
                Button("清空 \(done.count) 个已完成", role: .destructive) {
                    var tx = Transaction(); tx.disablesAnimations = true
                    withTransaction(tx) {
                        done.forEach { Store.shared.deleteTask($0) }
                    }
                    DispatchQueue.main.async { reload() }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("任务的专注记录会保留。")
            }
            .onAppear(perform: reload)
            .sheet(item: $editing) { t in
                TaskEditSheet(task: t) { reload() }
                    .onDisappear { reload() }
            }
        }
    }

    // MARK: 今日概览

    private var progressHeader: some View {
        let total = tasks.count
        let fraction = total > 0 ? Double(done.count) / Double(total) : 0

        return VStack(alignment: .leading, spacing: DS.S.md) {
            Text(Self.dateLine)
                .font(DS.F.microCaps)
                .kerning(1.2)
                .foregroundColor(.secondary)

            HStack(alignment: .firstTextBaseline) {
                Text(active.isEmpty && !tasks.isEmpty ? "全部完成" : "\(active.count) 项待办")
                    .font(DS.F.title2)
                Spacer()
                if total > 0 {
                    Text("\(Int(fraction * 100))%")
                        .font(DS.F.subheadSb)
                        .monospacedDigit()
                        .foregroundColor(fraction >= 1 ? DS.success : DS.accent)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.07))
                    Capsule()
                        .fill(fraction >= 1 ? AnyShapeStyle(DS.success) : AnyShapeStyle(DS.accent))
                        .frame(width: max(0, geo.size.width * CGFloat(fraction)))
                        .animation(DS.Motion.soft, value: fraction)
                }
            }
            .frame(height: 5)
        }
        .padding(DS.S.card)
        .hubSurface(.hero)
    }

    private var todayFocusCard: some View {
        let task = currentTask
        let hex = task?.colorHex ?? "#5865F2"
        let color = Color(hex: hex)
        let taskSeconds = task.flatMap { todaySecondsByTask[$0.id] } ?? 0
        let taskCount = task.flatMap { todayCountByTask[$0.id] } ?? 0
        let allSeconds = todaySecondsByTask.values.reduce(0, +)
        let title = task?.name ?? "选择一个任务开始"
        let subtitle = task == nil
            ? "今天已专注 \(Self.durationText(allSeconds)) · \(engine.todayPomodoros) 个番茄"
            : "今天 \(Self.durationText(taskSeconds)) · \(taskCount) 个番茄"

        return VStack(alignment: .leading, spacing: DS.S.lg) {
            HStack(spacing: DS.S.xs) {
                Image(systemName: "target")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(DS.accent)
                Text("当前投入")
                    .font(DS.F.microCaps)
                    .kerning(1.2)
                    .foregroundColor(.secondary)
                Spacer()
                if engine.isRunning || engine.isPaused {
                    Label(engine.isRunning ? "进行中" : "已暂停",
                          systemImage: engine.isRunning ? "circle.fill" : "pause.circle")
                        .font(DS.F.caption)
                        .foregroundColor(engine.isRunning ? DS.success : .secondary)
                }
            }

            HStack(spacing: DS.S.md) {
                RoundedRectangle(cornerRadius: DS.R.tile, style: .continuous)
                    .fill(color.opacity(0.13))
                    .frame(width: 46, height: 46)
                    .overlay(
                        Image(systemName: "timer")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(color)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(DS.F.headline)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(DS.F.subhead)
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: DS.S.sm)
            }

            Button(action: startCurrentTask) {
                HStack(spacing: DS.S.sm) {
                    Image(systemName: actionIcon)
                    Text(actionTitle)
                }
                .font(DS.F.bodySb)
                .foregroundColor(actionTitle == "回到专注" ? DS.accent : .white)
                .frame(maxWidth: .infinity, minHeight: DS.H.touchMin)
                .background(
                    Capsule().fill(actionTitle == "回到专注"
                                   ? AnyShapeStyle(DS.accent.opacity(0.11))
                                   : AnyShapeStyle(DS.accent))
                )
            }
            .buttonStyle(PressStyle())
        }
        .padding(DS.S.card)
        .hubSurface(.hero)
    }

    private var actionTitle: String {
        if engine.isRunning { return "回到专注" }
        if engine.isPaused { return "继续专注" }
        if case .prepared(let phase) = engine.state, phase != .focus { return "开始休息" }
        return "开始专注"
    }

    private var actionIcon: String {
        if engine.isRunning { return "arrow.right.circle" }
        if engine.isPaused { return "play.fill" }
        return "play.fill"
    }

    private func startCurrentTask() {
        switch engine.state {
        case .running:
            Haptic.light()
        case .paused:
            Haptic.medium()
            engine.resume()
        case .prepared(let phase):
            Haptic.medium()
            if phase != .focus { engine.startPreparedPhase() } else { engine.startFocus() }
        default:
            Haptic.medium()
            engine.startFocus()
        }
        router.showFocus()
    }

    // MARK: 行

    private func row(_ t: TaskEntity) -> AnyView {
        if t.managedObjectContext == nil { return AnyView(EmptyView().frame(height: 0)) }
        let isActive = engine.currentTaskID == t.id
        let tint = Color(hex: t.colorHex)

        return AnyView(AnyView(HStack(spacing: DS.S.md) {
            Button {
                var tx = Transaction(); tx.disablesAnimations = true
                withTransaction(tx) { Store.shared.setDone(t, !t.isDone) }
                if !t.isDone {
                    showDone = true
                    Haptic.light()
                } else {
                    Haptic.tick()
                }
                DispatchQueue.main.async { reload() }
            } label: {
                ZStack {
                    Circle()
                        .stroke(tint.opacity(t.isDone ? 1 : 0.55), lineWidth: 2)
                        .frame(width: 28, height: 28)

                    if t.isDone {
                        Circle()
                            .fill(tint)
                            .frame(width: 28, height: 28)
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundColor(.white)
                            .transition(.scale(scale: 0.5).combined(with: .opacity))
                    }
                }
                .scaleEffect(t.isDone ? 1.05 : 1)
                .animation(.spring(response: 0.30, dampingFraction: 0.58), value: t.isDone)
                .frame(width: DS.H.touchMin, height: DS.H.touchMin)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text(t.name)
                .font(DS.F.headline)
                .strikethrough(t.isDone, color: .secondary)
                .foregroundColor(t.isDone ? .secondary : .primary)
                .lineLimit(1)

            Spacer(minLength: DS.S.sm)

            if isActive {
                Text("当前")
                    .font(DS.F.microCaps)
                    .foregroundColor(tint)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(tint.opacity(0.10)))
            }

            if let total = Self.totalText(t.id) {
                Text(total)
                    .font(DS.F.caption.monospacedDigit())
                    .foregroundColor(.secondary.opacity(0.68))
            }
        }
        .padding(.horizontal, DS.S.md)
        .padding(.vertical, DS.S.sm + 3)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptic.light()
            editing = t
        }
        .contextMenu {
            Button { Haptic.light(); editing = t } label: {
                Label("编辑", systemImage: "pencil")
            }
            if !t.isDone {
                Button { setCurrent(t) } label: {
                    Label("设为当前", systemImage: "timer")
                }
            }
            Button(role: .destructive) { delete(t) } label: {
                Label("删除", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if !t.isDone {
                Button { setCurrent(t) } label: {
                    Label("设为当前", systemImage: "timer")
                }
                .tint(DS.accent)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { delete(t) } label: {
                Label("删除", systemImage: "trash")
            }
        }
        )
        .hubSurface(.standard)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16)))
    }

    private func setCurrent(_ t: TaskEntity) {
        Haptic.medium()
        engine.select(taskID: t.id)
        reload()
    }

    private func delete(_ t: TaskEntity) {
        guard t.managedObjectContext != nil else { return }
        let name = t.name
        let hex = t.colorHex
        let wasDone = t.isDone
        let wasCurrent = engine.currentTaskID == t.id

        var tx = Transaction(); tx.disablesAnimations = true
        withTransaction(tx) {
            Store.shared.deleteTask(t)
            if wasCurrent { engine.select(taskID: nil) }
        }

        Haptic.warning()
        ToastCenter.shared.show("已删除「\(name)」") {
            if let restored = Store.shared.addTaskRaw(name: name, colorHex: hex), wasDone {
                Store.shared.setDone(restored, true)
            }
            reload()
        }
        DispatchQueue.main.async { reload() }
    }

    private var doneToggle: some View {
        Button {
            Haptic.light()
            withAnimation(DS.Motion.soft) { showDone.toggle() }
        } label: {
            HStack(spacing: DS.S.xs) {
                Text("已完成 · \(done.count)")
                    .font(DS.F.subheadSb)
                    .foregroundColor(.secondary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .rotationEffect(.degrees(showDone ? 0 : -90))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.vertical, DS.S.sm)
        }
        .buttonStyle(.plain)
    }

    // MARK: 快速添加

    private var addFieldRow: some View {
        HStack(spacing: DS.S.md) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 19))
                .foregroundStyle(
                    LinearGradient(colors: [Color(hex: "#6A79FF"), DS.accentDeep],
                                   startPoint: .topLeading, endPoint: .bottomTrailing))

            Circle()
                .fill(Color(hex: Self.nextColorHex()))
                .frame(width: 8, height: 8)

            TextField("想到什么就记下来…", text: $newText)
                .font(DS.F.bodyMd)
                .focused($addFocused)
                .submitLabel(.done)
                .onSubmit(add)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        addFocused = true
                    }
                }

            if !newText.isEmpty {
                Button {
                    newText = ""
                    Haptic.light()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
            }

            if newText.trimmingCharacters(in: .whitespaces).isEmpty {
                Text("回车")
                    .font(DS.F.caption)
                    .foregroundColor(.secondary.opacity(0.62))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .overlay(Capsule().stroke(Color.secondary.opacity(0.24), lineWidth: 1))
            } else {
                Button(action: add) {
                    Text("添加")
                        .font(DS.F.subheadSb)
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 30)
                        .background(Capsule().fill(DS.accent))
                }
                .buttonStyle(PressStyle())
            }
        }
        .padding(.horizontal, DS.S.md + 2)
        .padding(.vertical, DS.S.sm + 3)
        .background(
            RoundedRectangle(cornerRadius: DS.R.composer, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func add() {
        let name = newText.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        withAnimation(DS.Motion.soft) {
            Store.shared.addTask(name: name)
        }
        newText = ""
        Haptic.light()
        addFocused = true
        reload()
    }

    static func nextColorHex() -> String {
        let palette = ["#5865F2", "#E5573F", "#2FA84F", "#1E88C7",
                       "#9C27B0", "#F08A24", "#2AA198", "#D81B60"]
        let count = (try? Store.shared.context.count(for: TaskEntity.fetchRequest())) ?? 0
        return palette[count % palette.count]
    }

    // MARK: 空态

    private var grandEmpty: some View {
        Section {
            VStack(spacing: DS.S.md) {
                ZStack {
                    Circle()
                        .fill(DS.accent.opacity(0.07))
                        .frame(width: 76, height: 76)
                    Circle()
                        .stroke(DS.accent.opacity(0.16), lineWidth: 1.5)
                        .frame(width: 76, height: 76)
                    Image(systemName: "checkmark")
                        .font(.system(size: 25, weight: .light))
                        .foregroundColor(DS.accent.opacity(0.62))
                }
                Text("今天想专注点什么？")
                    .font(DS.F.headline)
                Text("在上方输入框直接添加，右滑设为当前")
                    .font(DS.F.subhead)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.S.card)
            .hubCard(.standard)
            .listRowSeparator(.hidden)
        }
    }

    private func reload() {
        tasks = Store.shared.tasks()
        refreshTodayTotals()
        engine.refreshToday()
    }

    private func refreshTodayTotals() {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let request: NSFetchRequest<SessionEntity> = SessionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "phaseRaw == %@ AND startDate >= %@ AND completed == YES",
                                        Phase.focus.rawValue, start as NSDate)
        let sessions = (try? Store.shared.context.fetch(request)) ?? []
        var seconds: [UUID: Int] = [:]
        var counts: [UUID: Int] = [:]

        for session in sessions {
            guard let id = session.taskId else { continue }
            seconds[id, default: 0] += max(0, Int(session.durationSeconds))
            counts[id, default: 0] += 1
        }

        todaySecondsByTask = seconds
        todayCountByTask = counts
    }

    static func durationText(_ seconds: Int) -> String {
        let total = max(0, seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes) 分钟"
    }

    static var dateLine: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: Date()).uppercased()
    }

    static func totalText(_ id: UUID?) -> String? {
        guard let id = id else { return nil }
        let request: NSFetchRequest<SessionEntity> = SessionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "taskId == %@ AND completed == YES", id as CVarArg)
        let seconds = ((try? Store.shared.context.fetch(request)) ?? [])
            .reduce(0) { $0 + Int($1.durationSeconds) }
        guard seconds > 60 else { return nil }
        let hours = seconds / 3600, minutes = (seconds % 3600) / 60
        return hours > 0 ? String(format: "%.1fh", Double(seconds) / 3600) : "\(minutes) 分钟"
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
.background(SheetDetents())
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
                        var tx = Transaction(); tx.disablesAnimations = true
                        withTransaction(tx) { Store.shared.deleteTask(task) }
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
