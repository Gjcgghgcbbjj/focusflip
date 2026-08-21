import SwiftUI

/// 习惯打卡 — 每日习惯 + 连续天数 + 本周进度。
struct HabitsView3: View {

    @State private var habits: [HabitItem] = []
    @State private var showingAdd = false
    @State private var checked: [UUID: Bool] = [:]
    @State private var streaks: [UUID: Int] = [:]
    @State private var weekCounts: [UUID: Int] = [:]

    var body: some View {
        NavigationView {
            Group {
                if habits.isEmpty {
                    empty
                } else {
                    list
                }
            }
            .background(DS3.Color.bg.ignoresSafeArea())
            .navigationTitle("习惯")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingAdd = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 19, weight: .medium))
                            .foregroundColor(DS3.Color.accent)
                    }
                }
            }
            .sheet(isPresented: $showingAdd) { HabitEditSheet { reload() } }
            .onAppear { reload() }
        }
    }

    private var list: some View {
        List {
            ForEach(habits) { habit in
                HabitRow(
                    habit: habit,
                    checked: checked[habit.id] ?? false,
                    streak: streaks[habit.id] ?? 0,
                    weekCount: weekCounts[habit.id] ?? 0
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: DS3.S.md,
                                          bottom: 4, trailing: DS3.S.md))
                .contentShape(Rectangle())
                .onTapGesture { toggle(habit) }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        PersistenceController.shared.deleteHabit(habit)
                        HapticManager.shared.light()
                        reload()
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .hideScrollBackground3()
    }

    private var empty: some View {
        VStack(spacing: DS3.S.md) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(DS3.Color.textDim)
            Text("还没有习惯").font(DS3.Font.title).foregroundColor(DS3.Color.text)
            Text("每天打卡的小目标，比如阅读、运动")
                .font(DS3.Font.sub).foregroundColor(DS3.Color.textDim)
            Button { showingAdd = true } label: {
                Text("新建习惯")
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

    private func reload() {
        habits = PersistenceController.shared.fetchHabits()
        let p = PersistenceController.shared
        for h in habits {
            checked[h.id] = p.habitCheckedToday(h)
            streaks[h.id] = p.habitStreak(h)
            weekCounts[h.id] = p.habitChecksThisWeek(h)
        }
    }

    private func toggle(_ habit: HabitItem) {
        let nowChecked = PersistenceController.shared.toggleHabitToday(habit)
        HapticManager.shared.selection()
        if nowChecked { HapticManager.shared.success() }
        reload()
    }
}

// MARK: - Row

private struct HabitRow: View {
    let habit: HabitItem
    let checked: Bool
    let streak: Int
    let weekCount: Int

    var body: some View {
        HStack(spacing: DS3.S.md) {
            // 打卡圈
            ZStack {
                Circle()
                    .stroke(checked ? Color(hex: habit.colorHex) : DS3.Color.hairline,
                            lineWidth: 2)
                if checked {
                    Circle().fill(Color(hex: habit.colorHex)).padding(5)
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: DS3.S.xs) {
                Text(habit.name)
                    .font(DS3.Font.body.weight(.medium))
                    .foregroundColor(checked ? DS3.Color.textDim : DS3.Color.text)
                    .strikethrough(checked)
                HStack(spacing: DS3.S.sm) {
                    Label("\(streak)", systemImage: "flame.fill")
                        .font(DS3.Font.micro).monospacedDigit()
                        .foregroundColor(streak > 0 ? DS3.Color.warn : DS3.Color.textDim)
                    Text("本周 \(weekCount)/7")
                        .font(DS3.Font.micro).monospacedDigit()
                        .foregroundColor(DS3.Color.textDim)
                }
            }

            Spacer(minLength: 0)
        }
        .card3(inset: DS3.S.md)
    }
}

// MARK: - Edit sheet

struct HabitEditSheet: View {
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var colorHex = "#30D158"

    private let palette = ["#FF4D4A", "#FF9F0A", "#30D158", "#64D2FF",
                           "#BF5AF2", "#FF2D55", "#FFD60A", "#0A84FF"]

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("习惯名称（如：阅读 30 分钟）", text: $name)
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
            .navigationTitle("新建习惯")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.foregroundColor(DS3.Color.textDim)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(DS3.Color.accent)
                        .disabled(name.isEmpty)
                }
            }
        }
    }

    private func save() {
        let ctx = PersistenceController.shared.viewContext
        let habit = HabitItem(context: ctx)
        habit.id = UUID()
        habit.name = name
        habit.colorHex = colorHex
        habit.createdAt = Date()
        habit.archived = false
        habit.sortOrder = Int32(PersistenceController.shared.fetchHabits().count)
        PersistenceController.shared.save()
        onDone()
        dismiss()
    }
}
