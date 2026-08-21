import SwiftUI

/// 日期倒计时管理（高考/生日/DDL……）
struct CountdownSheet: View {

    @Environment(\.dismiss) private var dismiss
    @State private var items: [CountdownEntity] = []

    // 新建
    @State private var newTitle = ""
    @State private var newDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
    @State private var showAdd = false

    private let colors = ["#5865F2", "#E5573F", "#2FA84F", "#1E88C7", "#9C27B0"]

    var body: some View {
        NavigationView {
            List {
                ForEach(items) { c in
                    row(c)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Store.shared.deleteCountdown(c); reload()
                            } label: { Label("删除", systemImage: "trash") }
                        }
                }

                Section {
                    if showAdd {
                        HStack {
                            TextField("名称（如：高考）", text: $newTitle)
                            DatePicker("", selection: $newDate,
                                       displayedComponents: .date)
                                .labelsHidden()
                        }
                        Button("保存") { add() }
                            .disabled(newTitle.isEmpty)
                    } else {
                        Button {
                            showAdd = true; Haptic.tick()
                        } label: {
                            Label("添加倒计时", systemImage: "plus.circle.fill")
                        }
                    }
                }
            }
            .navigationTitle("日期倒计时")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .onAppear(perform: reload)
        }
    }

    private func row(_ c: CountdownEntity) -> some View {
        let days = Self.daysLeft(c.targetDate)
        return HStack(spacing: 12) {
            Circle().fill(Color(hex: c.colorHex)).frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 2) {
                Text(c.title).font(.system(size: 15))
            }
            VStack(spacing: 5) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(hex: c.colorHex).opacity(0.15))
                        let span = max(1, c.targetDate.timeIntervalSince(c.createdAt) / 86400)
                        let used = min(1, max(0,
                            (Date().timeIntervalSince(c.createdAt)) / (span * 86400)))
                        Capsule().fill(Color(hex: c.colorHex))
                            .frame(width: geo.size.width * CGFloat(days >= 0 ? used : 1))
                    }
                }
                .frame(height: 4)
                Text(Self.dateText(c.targetDate))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(spacing: 0) {
                Text("\(days)")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(days <= 30 ? Color(hex: "#E5573F") : Color(hex: "#5865F2"))
                Text(days >= 0 ? "天" : "天前")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .frame(minWidth: 52)
        }
        .padding(.vertical, 3)
    }

    static func daysLeft(_ date: Date) -> Int {
        let cal = Calendar.current
        let target = cal.startOfDay(for: date)
        let today = cal.startOfDay(for: Date())
        return cal.dateComponents([.day], from: today, to: target).day ?? 0
    }

    static func dateText(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy年M月d日"
        return f.string(from: date)
    }

    private func add() {
        let name = newTitle.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        Store.shared.addCountdown(title: name, date: newDate,
                                  colorHex: colors[items.count % colors.count])
        newTitle = ""; showAdd = false; reload(); Haptic.tick()
    }

    private func reload() { items = Store.shared.countdowns() }
}
