import SwiftUI

/// 目标 —— 日期倒计时的独立家（高考/DDL/纪念日）
struct TargetView: View {

    @State private var items: [CountdownEntity] = []
    @State private var showManager = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    if items.isEmpty {
                        emptyState
                    }
                    ForEach(items) { c in
                        bigCard(c)
                            .swipeActionsHint
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("目标")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Haptic.tick()
                        showManager = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .medium))
                    }
                }
            }
            .sheet(isPresented: $showManager) {
                CountdownSheet()
            }
            .onAppear(perform: reload)
            .onChange(of: showManager) { open in
                if !open { reload() }
            }
        }
    }

    // MARK: 大卡片（可滑动删除）

    private func bigCard(_ c: CountdownEntity) -> some View {
        let days = CountdownSheet.daysLeft(c.targetDate)
        let base = Color(hex: c.colorHex)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(c.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                    Text(CountdownSheet.dateText(c.targetDate))
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.75))
                }
                Spacer()
                VStack(spacing: 0) {
                    Text("\(days)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(days <= 30 ? Color(hex: "#FFE08A") : .white)
                    Text(days >= 0 ? (days == 0 ? "就是今天" : "天") : "天前")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.8))
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.25))
                    let span = max(1, c.targetDate.timeIntervalSince(c.createdAt) / 86400)
                    let used = min(1, max(0,
                        Date().timeIntervalSince(c.createdAt) / (span * 86400)))
                    Capsule().fill(Color.white)
                        .frame(width: geo.size.width * CGFloat(max(0.04, used)))
                }
            }
            .frame(height: 5)
            .padding(.top, 16)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [base.opacity(0.95), Palette.deepVariant(base)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .shadow(color: base.opacity(0.32), radius: 10, y: 6)
        .contextMenu {
            Button(role: .destructive) {
                withAnimation { Store.shared.deleteCountdown(c) }
                Haptic.tick()
                reload()
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    private var swipeActionsHint: some View { EmptyView() }

    // MARK: 空态

    private var emptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color(hex: "#5865F2").opacity(0.18), lineWidth: 2)
                    .frame(width: 74, height: 74)
                Image(systemName: "flag.checkered")
                    .font(.system(size: 24))
                    .foregroundColor(Color(hex: "#5865F2").opacity(0.55))
            }
            .padding(.top, 26)
            Text("有一个在倒数的日子\n会让人踏实很多")
                .font(.system(size: 15, weight: .medium), )
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            Text("高考 · 考试 · 生日 · DDL")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Button {
                Haptic.tick()
                showManager = true
            } label: {
                Label("添加目标", systemImage: "plus.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(Color(hex: "#5865F2")))
                    .shadow(color: Color(hex: "#5865F2").opacity(0.35), radius: 10, y: 4)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 30)
    }

    private func reload() { items = Store.shared.countdowns() }
}
