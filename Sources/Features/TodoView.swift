import SwiftUI
import CoreData

/// 任务页 —— 大卡片清单。
/// 身份：诚实的长期任务总清单（无"今日"外衣）；
/// 联动：每张卡可直接开始专注，当前任务色即首页场景色。
struct TodoView: View {

    @ObservedObject private var engine = FocusEngine.shared
    @ObservedObject private var router = AppRouter.shared

    @State private var tasks: [TaskEntity] = []
    @State private var editing: TaskEntity?
    @State private var showAdd = false
    @State private var showDone = false
    @State private var showClearDone = false
    @State private var todaySecondsByTask: [UUID: Int] = [:]
    @State private var todayCountByTask: [UUID: Int] = [:]
    @State private var totalSecondsByTask: [UUID: Int] = [:]
    // 拖拽排序已撤（iOS15 List editMode+swipeActions 崩溃族，PR#2 真机闪退主嫌）；
    // sortOrder 字段与 Store.setOrder 保留，拿到崩溃日志或升基线再做

    private var active: [TaskEntity] { tasks.filter { !$0.isDone } }
    private var done: [TaskEntity] { tasks.filter { $0.isDone } }

    private var currentTask: TaskEntity? {
        guard let id = engine.currentTaskID else { return nil }
        return tasks.first { $0.id == id && $0.managedObjectContext != nil }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 0) {
                    if currentTask != nil || engine.isRunning || engine.isPaused {
                        currentLine
                            .padding(.horizontal, 16)
                            .padding(.top, 6)
                            .padding(.bottom, 2)
                    }

                    if !active.isEmpty {
                        sectionHeader("\(active.count) 项待办")
                        ForEach(active) { t in
                            card(t)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 5)
                                .transition(Self.cardTransition)
                        }
                    }

                    if !done.isEmpty {
                        doneToggle
                            .padding(.horizontal, 20)
                            .padding(.top, active.isEmpty ? 14 : 8)
                        if showDone {
                            ForEach(done) { t in
                                card(t)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 5)
                                    .transition(Self.cardTransition)
                            }
                        }
                    }

                    if active.isEmpty && done.isEmpty {
                        grandEmpty
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                    }
                }
                .padding(.bottom, 24)
            }
            .background(DS.canvas.ignoresSafeArea())
            .navigationTitle("任务")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Haptic.light()
                        showAdd = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .accessibilityIdentifier("todo.add")
                }
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
                    withAnimation(DS.Motion.soft) {
                        done.forEach { Store.shared.deleteTask($0) }
                        tasks = Store.shared.tasks()
                    }
                    refreshTotals()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("任务的专注记录会保留。")
            }
            .onAppear(perform: reload)
            .sheet(item: $editing) { t in
                TaskEditSheet(task: t) { withAnimation(DS.Motion.soft) { reload() } }
                    .onDisappear { reload() }
            }
            .sheet(isPresented: $showAdd) {
                AddTaskSheet { _ in
                    withAnimation(DS.Motion.soft) { reload() }
                }
            }
        }
    }

    // MARK: 当前投入（一行条，点击回专注页）

    private var currentLine: some View {
        let task = currentTask
        let tint = Color(hex: task?.colorHex ?? "#5865F2")
        let seconds = task.flatMap { todaySecondsByTask[$0.id] } ?? 0

        return Button {
            Haptic.light()
            router.showFocus()
        } label: {
            HStack(spacing: DS.S.sm + 2) {
                Circle().fill(tint).frame(width: 8, height: 8)
                Text(task?.name ?? "选择一个任务开始")
                    .font(DS.F.subheadSb)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                if seconds > 0 {
                    Text("今天 \(Self.durationText(seconds))")
                        .font(DS.F.caption)
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(engine.isRunning ? "进行中 ›"
                     : engine.isPaused ? "已暂停 ›" : "去专注 ›")
                    .font(DS.F.caption)
                    .foregroundColor(DS.accent)
            }
            .padding(.horizontal, DS.S.md + 2)
            .padding(.vertical, 11)
            .hubSurface(.standard)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: 大卡片（自定义滑动，动画与模拟器同源）

    static let cardTransition = AnyTransition.asymmetric(
        insertion: .scale(scale: 0.92).combined(with: .opacity).combined(with: .offset(y: 14)),
        removal: .move(edge: .leading).combined(with: .opacity))

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(DS.F.subheadSb)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 6)
    }

    @ViewBuilder
    private func card(_ t: TaskEntity) -> some View {
        if t.managedObjectContext == nil {
            EmptyView()
        } else {
            SwipeableCard(
                canSetCurrent: !t.isDone,
                onSetCurrent: { setCurrent(t) },
                onDelete: { delete(t) }
            ) {
                cardBody(t)
            }
        }
    }

    private func cardBody(_ t: TaskEntity) -> some View {
        let isActive = engine.currentTaskID == t.id
        let tint = Color(hex: t.colorHex)
        let todaySec = todaySecondsByTask[t.id] ?? 0
        let totalSec = totalSecondsByTask[t.id] ?? 0

        return Button {
            Haptic.light()
            editing = t
        } label: {
            HStack(spacing: DS.S.md) {
                // 色圈即完成勾选（点切 done）
                Button { toggleDone(t) } label: {
                    RoundedRectangle(cornerRadius: DS.R.tile, style: .continuous)
                        .fill(tint.opacity(t.isDone ? 0.07 : 0.13))
                        .frame(width: 46, height: 46)
                        .overlay(
                            Image(systemName: t.isDone ? "checkmark" : "timer")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(t.isDone ? tint.opacity(0.5) : tint)
                        )
                }
                .buttonStyle(PressStyle())
                .accessibilityLabel(t.isDone ? "标记未完成" : "标记完成")

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(t.name)
                            .font(DS.F.headline)
                            .strikethrough(t.isDone, color: .secondary)
                            .foregroundColor(t.isDone ? .secondary : .primary)
                            .lineLimit(2)
                        if isActive && !t.isDone {
                            Text("当前")
                                .font(DS.F.microCaps)
                                .foregroundColor(tint)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(tint.opacity(0.10)))
                        }
                    }

                    Text(Self.metaLine(today: todaySec,
                                       total: totalSec, isDone: t.isDone))
                        .font(DS.F.caption)
                        .monospacedDigit()
                        .foregroundColor(.secondary.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

                Spacer(minLength: DS.S.sm)

                if !t.isDone {
                    Button { quickStart(t) } label: {
                        Image(systemName: engine.isRunning && isActive
                              ? "arrow.right.circle.fill" : "play.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(tint)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(tint.opacity(0.12)))
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityLabel("开始这个任务")
                }
            }
            .padding(14)
            .hubSurface(.standard)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("task.card.\(t.name)")
        .contextMenu {
            Button { Haptic.light(); editing = t } label: {
                Label("编辑", systemImage: "pencil")
            }
            if !t.isDone {
                Button { setCurrent(t) } label: {
                    Label("设为当前", systemImage: "timer")
                }
                Button { quickStart(t) } label: {
                    Label("设为当前并开始", systemImage: "play.fill")
                }
            }
            Button(role: .destructive) { delete(t) } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    private func toggleDone(_ t: TaskEntity) {
        guard t.managedObjectContext != nil else { return }
        let willDone = !t.isDone
        withAnimation(DS.Motion.soft) {
            Store.shared.setDone(t, willDone)
            tasks = Store.shared.tasks()
        }
        if willDone { showDone = true; Haptic.light() } else { Haptic.tick() }
        refreshTotals()
        engine.refreshToday()
    }

    private func quickStart(_ t: TaskEntity) {
        if engine.isRunning || engine.isPaused {
            Haptic.light()
            router.showFocus()
            return
        }
        Haptic.medium()
        if engine.currentTaskID != t.id { engine.select(taskID: t.id) }
        engine.startFocus()
        router.showFocus()
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
        let order = t.sortOrder

        // 动画化移除：先改存储，再在同一动画块里刷新 @State（卡片平滑收起）
        withAnimation(DS.Motion.soft) {
            Store.shared.deleteTask(t)
            if wasCurrent { engine.select(taskID: nil) }
            tasks = Store.shared.tasks()
        }
        refreshTotals()
        engine.refreshToday()

        Haptic.warning()
        ToastCenter.shared.show("已删除「\(name)」") {
            // 撤销还原：位置(sortOrder) + 完成态 + 当前任务，一样不少
            if let restored = Store.shared.addTaskRaw(name: name, colorHex: hex) {
                restored.sortOrder = order
                if wasDone { Store.shared.setDone(restored, true) }
                Store.shared.save()
                if wasCurrent { engine.select(taskID: restored.id) }
                withAnimation(DS.Motion.soft) { reload() }
            }
        }
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: 空态

    private var grandEmpty: some View {
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
            Text("点右上角 ＋ 添加第一个任务")
                .font(DS.F.subhead)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.S.card)
        .hubCard(.standard)
    }

    // MARK: 数据

    private func reload() {
        tasks = Store.shared.tasks()
        refreshTotals()
        engine.refreshToday()
    }

    /// 一次 fetch 取全量完成会话，按任务聚合（替代旧的每行一查 N+1）
    private func refreshTotals() {
        let request: NSFetchRequest<SessionEntity> = SessionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "phaseRaw == %@ AND completed == YES",
                                        Phase.focus.rawValue)
        let sessions = (try? Store.shared.context.fetch(request)) ?? []
        let startOfDay = Calendar.current.startOfDay(for: Date())

        var todaySeconds: [UUID: Int] = [:]
        var todayCounts: [UUID: Int] = [:]
        var totals: [UUID: Int] = [:]
        for s in sessions {
            guard let id = s.taskId else { continue }
            let d = max(0, Int(s.durationSeconds))
            totals[id, default: 0] += d
            if s.startDate >= startOfDay {
                todaySeconds[id, default: 0] += d
                todayCounts[id, default: 0] += 1
            }
        }
        todaySecondsByTask = todaySeconds
        todayCountByTask = todayCounts
        totalSecondsByTask = totals
    }

    static func nextColorHex() -> String {
        let palette = ["#5865F2", "#E5573F", "#2FA84F", "#1E88C7",
                       "#9C27B0", "#F08A24", "#2AA198", "#D81B60"]
        let count = (try? Store.shared.context.count(for: TaskEntity.fetchRequest())) ?? 0
        return palette[count % palette.count]
    }

    static func durationText(_ seconds: Int) -> String {
        let total = max(0, seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes) 分钟"
    }

    static func metaLine(today: Int, total: Int, isDone: Bool) -> String {
        var parts: [String] = []
        if today > 0 { parts.append("今天 \(durationText(today))") }
        if total > 60 { parts.append("累计 \(durationText(total))") }
        if parts.isEmpty { parts.append(isDone ? "已完成" : "还没投入过") }
        return parts.joined(separator: " · ")
    }
}

// MARK: - 新任务（精致添加页）

struct AddTaskSheet: View {
    var onAdd: (TaskEntity) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var colorHex: String = TodoView.nextColorHex()
    @State private var appear = false
    @FocusState private var nameFocused: Bool

    private let palette = ["#5865F2", "#E5573F", "#2FA84F", "#1E88C7",
                           "#9C27B0", "#F08A24", "#2AA198", "#D81B60"]

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // 输入区：大字、无框、聚焦即写
                    HStack(spacing: DS.S.md) {
                        Circle()
                            .fill(Color(hex: colorHex))
                            .frame(width: 10, height: 10)
                        TextField("想到什么就记下来…", text: $name)
                            .font(.system(size: 22, weight: .semibold))
                            .focused($nameFocused)
                            .submitLabel(.done)
                            .onSubmit(add)
                    }
                    .padding(.vertical, 18)

                    Divider().opacity(0.5)

                    Text("颜色")
                        .font(DS.F.microCaps)
                        .kerning(1.2)
                        .foregroundColor(.secondary)
                        .padding(.top, 20)

                    HStack(spacing: 13) {
                        ForEach(palette, id: \.self) { hex in
                            colorDot(hex)
                        }
                    }
                    .padding(.top, 12)

                    Text("预览")
                        .font(DS.F.microCaps)
                        .kerning(1.2)
                        .foregroundColor(.secondary)
                        .padding(.top, 24)

                    previewCard
                        .opacity(appear ? 1 : 0)
                        .offset(y: appear ? 0 : 8)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, DS.S.screen)
                .padding(.top, 6)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("新任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加", action: add)
                        .font(.system(size: 17, weight: .semibold))
                        .disabled(trimmedName.isEmpty)
                }
            }
            .background(SheetDetents(largeOnly: true))
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { appear = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    nameFocused = true
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func colorDot(_ hex: String) -> some View {
        let selected = colorHex == hex
        return Button {
            Haptic.tick()
            withAnimation(DS.Motion.quick) { colorHex = hex }
        } label: {
            ZStack {
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 30, height: 30)
                if selected {
                    Circle()
                        .stroke(Color.primary.opacity(0.65), lineWidth: 2)
                        .frame(width: 38, height: 38)
                }
            }
            .frame(width: 40, height: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// 即时预览：所见即所得的任务卡
    private var previewCard: some View {
        HStack(spacing: DS.S.md) {
            RoundedRectangle(cornerRadius: DS.R.tile, style: .continuous)
                .fill(Color(hex: colorHex).opacity(0.13))
                .frame(width: 46, height: 46)
                .overlay(
                    Image(systemName: "timer")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(Color(hex: colorHex))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(trimmedName.isEmpty ? "任务名" : trimmedName)
                    .font(DS.F.headline)
                    .foregroundColor(trimmedName.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
                Text("还没投入过")
                    .font(DS.F.caption)
                    .foregroundColor(.secondary.opacity(0.85))
            }

            Spacer(minLength: DS.S.sm)

            Image(systemName: "play.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color(hex: colorHex))
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color(hex: colorHex).opacity(0.12)))
        }
        .padding(14)
        .hubSurface(.standard)
        .padding(.top, 12)
    }

    private func add() {
        guard !trimmedName.isEmpty else { return }
        guard let t = Store.shared.addTaskRaw(name: trimmedName, colorHex: colorHex) else { return }
        Haptic.success()
        onAdd(t)
        dismiss()
    }
}

// MARK: - 任务编辑（沿用）

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
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        task.name = trimmed.isEmpty ? task.name : trimmed
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
                        // 血泪#8：实体可能已被别的路径删除，访问即崩
                        guard task.managedObjectContext != nil else { onDone(); return }
                        let name = task.name, hex = task.colorHex, order = task.sortOrder
                        Store.shared.deleteTask(task)
                        onDone()   // 父页动画化刷新（接线处已包 withAnimation）
                        ToastCenter.shared.show("已删除「\(name)」") {
                            if let restored = Store.shared.addTaskRaw(name: name, colorHex: hex) {
                                restored.sortOrder = order
                                Store.shared.save()
                                onDone()
                            }
                        }
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

// MARK: - 可滑动卡片（左滑删除 / 右滑设当前，动画与 docs/animation-mockup.html 同源）

private struct SwipeableCard<Content: View>: View {
    var canSetCurrent: Bool
    var onSetCurrent: () -> Void
    var onDelete: () -> Void
    @ViewBuilder var content: () -> Content

    @State private var offset: CGFloat = 0
    private let revealWidth: CGFloat = 128          // 部分露出时按钮停留位

    var body: some View {
        ZStack {
            // 背后动作层：右缘删除、左缘设当前
            // 未露出时对辅助功能隐藏（否则 XCUITest/VoiceOver 会命中被盖住的按钮）
            HStack(spacing: 0) {
                if canSetCurrent {
                    actionButton(tint: DS.accent, icon: "timer",
                                 title: "设为当前", role: .current)
                        .accessibilityHidden(offset < 40)
                }
                Spacer(minLength: 0)
                actionButton(tint: DS.danger, icon: "trash",
                             title: "删除", role: .delete)
                    .accessibilityHidden(offset > -40)
            }
            // 前景卡：UIKit 平移手势承载（竖向让路滚动、横向 1:1 跟手、原生速度）
            SwipePanContainer(canSetCurrent: canSetCurrent,
                              offset: $offset,
                              onDelete: onDelete,
                              onSetCurrent: onSetCurrent) {
                content()
                    // VoiceOver 用户不靠滑动：自定义动作直达
                    .accessibilityAction(named: Text("删除")) { onDelete() }
                    .accessibilityAction(named: Text(canSetCurrent ? "设为当前" : "当前")) {
                        if canSetCurrent { onSetCurrent() }
                    }
            }
        }
    }

    private enum ActionRole { case `delete`, current }

    private func actionButton(tint: Color, icon: String, title: String,
                              role: ActionRole) -> some View {
        Button {
            switch role {
            case .delete:
                Haptic.warning()
                onDelete()
            case .current:
                Haptic.medium()
                withAnimation(DS.Motion.quick) { offset = 0 }
                onSetCurrent()
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                Text(title).font(DS.F.microCaps)
            }
            .foregroundColor(.white)
            .frame(width: revealWidth - 12)
            .frame(maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: DS.R.card, style: .continuous)
                .fill(tint))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    /// 拖拽判定与动画全部在 SwipePanCoordinator（UIKit 原生速度/弹簧）
}

// MARK: - UIKit 平移手势容器：竖向让路滚动、横向 1:1 跟手、原生速度采样
// 拖动中直接变换 layer（零 SwiftUI 逐帧开销）；offset 只在结束/露出时回写驱动动作层 a11y

// MARK: - UIKit 平移手势容器：竖向让路滚动、横向 1:1 跟手、原生速度采样
// 拖动中直接变换 layer（零 SwiftUI 逐帧开销）；offset 只在结束/露出时回写驱动动作层 a11y

private class SwipePanBase: NSObject, UIGestureRecognizerDelegate {
    var canSetCurrent = true
    var onDelete: () -> Void = {}
    var onSetCurrent: () -> Void = {}
    var onOffsetSettle: (CGFloat) -> Void = { _ in }
    weak var transformView: UIView?
    private var lastZone = 0

    @objc func pan(_ g: UIPanGestureRecognizer) {
        guard let view = transformView else { return }
        let w = max(view.bounds.width, 1)
        switch g.state {
        case .began:
            lastZone = 0
        case .changed:
            var dx = g.translation(in: view).x
            let limit = w * 0.55
            if abs(dx) > limit { dx = (dx > 0 ? 1 : -1) * (limit + (abs(dx) - limit) * 0.25) }
            view.transform = CGAffineTransform(translationX: dx, y: 0)
            // 越过动作阈值的瞬间给轻触感（iOS 原生滑动习惯）
            let zone = dx < -w * 0.4 ? -1 : (canSetCurrent && dx > w * 0.4 ? 1 : 0)
            if zone != lastZone {
                lastZone = zone
                if zone != 0 { Haptic.light() }
            }
        case .ended, .cancelled, .failed:
            decide(dx: g.translation(in: view).x,
                   vx: g.velocity(in: view).x, width: w, view: view)
        default:
            break
        }
    }

    private func decide(dx: CGFloat, vx: CGFloat, width: CGFloat, view: UIView) {
        let fullLeft = dx < -width * 0.4 || vx < -450      // 位移或甩速任一达标
        let fullRight = dx > width * 0.4 || vx > 450
        if fullLeft {
            Haptic.warning()
            onOffsetSettle(-9999)
            UIView.animate(withDuration: 0.2, delay: 0,
                           options: [.beginFromCurrentState, .curveEaseIn]) {
                view.transform = CGAffineTransform(
                    translationX: -UIScreen.main.bounds.width, y: 0)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { [self] in onDelete() }
        } else if fullRight && canSetCurrent {
            Haptic.medium()
            spring(view: view, to: 0)
            onOffsetSettle(0)
            onSetCurrent()
        } else if dx < -56 {
            spring(view: view, to: -128)
            onOffsetSettle(-128)
        } else {
            spring(view: view, to: 0)
            onOffsetSettle(0)
        }
    }

    /// DS.Motion.quick 的 UIKit 对应：damping .78 / 约 0.3s
    func spring(view: UIView, to x: CGFloat) {
        UIView.animate(withDuration: 0.3, delay: 0,
                       usingSpringWithDamping: 0.78, initialSpringVelocity: 0,
                       options: [.beginFromCurrentState, .allowUserInteraction],
                       animations: {
                           view.transform = CGAffineTransform(translationX: x, y: 0)
                       },
                       completion: nil)
    }

    // 竖向速度为主时拒绝开始 → 滚动列表完全不受影响
    func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
        guard let pan = g as? UIPanGestureRecognizer, let view = g.view else { return true }
        let v = pan.velocity(in: view)
        return abs(v.x) > abs(v.y)      // 横向才接管；竖向交还给 ScrollView
    }
    func gestureRecognizer(_ g: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith o: UIGestureRecognizer) -> Bool { false }
}

private final class SwipePanCoordinator<Content: View>: SwipePanBase {
    var host: UIHostingController<Content>?
}

private struct SwipePanContainer<Content: View>: UIViewControllerRepresentable {
    var canSetCurrent: Bool
    @Binding var offset: CGFloat
    var onDelete: () -> Void
    var onSetCurrent: () -> Void
    @ViewBuilder var content: () -> Content

    func makeCoordinator() -> SwipePanCoordinator<Content> { SwipePanCoordinator() }

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        let container = UIView()
        container.backgroundColor = .clear
        vc.view = container
        let host = UIHostingController(rootView: content())
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: container.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
        context.coordinator.host = host
        context.coordinator.transformView = container
        let pan = UIPanGestureRecognizer(target: context.coordinator,
                                         action: #selector(SwipePanBase.pan(_:)))
        pan.delegate = context.coordinator
        pan.cancelsTouchesInView = true
        container.addGestureRecognizer(pan)
        sync(coordinator: context.coordinator)
        return vc
    }

    func updateUIViewController(_ vc: UIViewController, context: Context) {
        context.coordinator.host?.rootView = content()
        sync(coordinator: context.coordinator)
    }

    private func sync(coordinator: SwipePanCoordinator<Content>) {
        coordinator.canSetCurrent = canSetCurrent
        coordinator.onDelete = onDelete
        coordinator.onSetCurrent = onSetCurrent
        coordinator.onOffsetSettle = { [self] value in
            if value != -9999 { offset = value }
        }
    }
}
