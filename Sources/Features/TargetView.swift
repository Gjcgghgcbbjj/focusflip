import SwiftUI

/// 目标 —— 日期倒计时的独立家（高考/DDL/纪念日）
struct TargetView: View {

    @State private var items: [CountdownEntity] = []
    @State private var showManager = false
    @State private var editing: CountdownEntity?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    if items.isEmpty {
                        emptyState
                    }
                    ForEach(items) { c in
                        countdownCard(c)
                            .onTapGesture {
                                Haptic.light()
                                editing = c
                            }
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
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color(hex: "#5865F2"))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                }
            }
            .sheet(isPresented: $showManager) {
                CountdownSheet()
            }
            .sheet(item: $editing) { c in
                EditCountdownSheet(target: c) { reload() }
                    .background(SheetDetents())
            }
            .onAppear(perform: reload)
            .onChange(of: showManager) { open in
                if !open { reload() }
            }
        }
    }

    // MARK: 大卡片（可滑动删除）

    /// 形态分级: 已过期=灰卡 / ≤7天=英雄卡+火焰徽章 / >30天=横条卡 / 其余=英雄卡
    @ViewBuilder
    private func countdownCard(_ c: CountdownEntity) -> some View {
        let days = CountdownSheet.daysLeft(c.targetDate)
        if days < 0 { pastCard(c, days: days) }
        else if days > 30 { slimCard(c, days: days) }
        else { bigCard(c, urgent: days <= 7) }
    }

    private func pastCard(_ c: CountdownEntity, days: Int) -> AnyView {
        guard safe(c) else { return AnyView(EmptyView()) }
        return AnyView(HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(c.title).font(DS.F.bodySb).foregroundColor(.secondary)
                Text(CountdownSheet.dateText(c.targetDate))
                    .font(DS.F.caption).foregroundColor(.secondary.opacity(0.7))
            }
            Spacer()
            VStack(spacing: 0) {
                Text("\(abs(days))").font(DS.F.title2).monospacedDigit()
                    .foregroundColor(.secondary)
                Text("天前").font(DS.F.caption).foregroundColor(.secondary.opacity(0.7))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: DS.R.card, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground)))
        .opacity(0.75)
        )
    }

    private func slimCard(_ c: CountdownEntity, days: Int) -> AnyView {
        guard safe(c) else { return AnyView(EmptyView()) }
        let base = Color(hex: c.colorHex)
        return AnyView(HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(base.opacity(0.18))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "flag")
                        .font(.system(size: 15))
                        .foregroundColor(base))
            VStack(alignment: .leading, spacing: 3) {
                Text(c.title).font(DS.F.bodySb)
                Text(CountdownSheet.dateText(c.targetDate))
                    .font(DS.F.caption).foregroundColor(.secondary)
            }
            Spacer()
            VStack(spacing: 0) {
                Text("\(days)").font(DS.F.numberM).monospacedDigit()
                    .foregroundColor(base)
                Text("天").font(DS.F.caption).foregroundColor(.secondary)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: DS.R.card, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground)))
        )
    }

    private func safe(_ c: CountdownEntity) -> Bool { c.managedObjectContext != nil }

    private func bigCard(_ c: CountdownEntity, urgent: Bool) -> AnyView {
        guard safe(c) else { return AnyView(EmptyView()) }
        let days = CountdownSheet.daysLeft(c.targetDate)
        let base = Color(hex: c.colorHex)

        return AnyView(ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
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
                    RollText(value: max(0, days),
                             font: .system(size: 44, weight: .bold, design: .rounded),
                             color: urgent && days <= 7 ? .white : Color(hex: "#FFE08A"))
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

            if urgent {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill").font(.system(size: 10))
                    Text("最后\(days)天").font(DS.F.caption)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.white.opacity(0.22)))
                .padding(10)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: DS.R.card, style: .continuous)
                .fill(LinearGradient(colors: [base.opacity(0.95), Palette.deepVariant(base)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .shadow(color: base.opacity(urgent ? 0.45 : 0.28), radius: urgent ? 14 : 10, y: 6)
        .contextMenu {
            Button(role: .destructive) {
                let title = c.title; let date = c.targetDate; let hex = c.colorHex
                var tx = Transaction(); tx.disablesAnimations = true
                withTransaction(tx) { Store.shared.deleteCountdown(c) }
                Haptic.medium()
                ToastCenter.shared.show("已删除「\(title)」") {
                    _ = Store.shared.addCountdown(title: title, date: date, colorHex: hex)
                    reload()
                }
                DispatchQueue.main.async { reload() }
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
        )
    }

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

    private func reload() {
        items = Store.shared.countdowns().sorted {
            CountdownSheet.daysLeft($0.targetDate) < CountdownSheet.daysLeft($1.targetDate)
        }
    }
}

/// 编辑已有目标（点卡片进入）
struct EditCountdownSheet: View {
    let target: CountdownEntity
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var date = Date()
    @State private var colorHex = "#5865F2"
    @State private var loaded = false
    @State private var confirmDelete = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.S.lg) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("名称").font(DS.F.microCaps).kerning(1.5).foregroundColor(.secondary)
                        TextField("如：高考", text: $title)
                            .font(DS.F.headline)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: DS.R.composer,
                                                         style: .continuous)
                                .fill(Color(.tertiarySystemGroupedBackground)))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("目标日期").font(DS.F.microCaps).kerning(1.5).foregroundColor(.secondary)
                        DatePicker("", selection: $date, displayedComponents: .date)
                            .labelsHidden()
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("颜色").font(DS.F.microCaps).kerning(1.5).foregroundColor(.secondary)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12),
                                                 count: 8), spacing: 12) {
                            ForEach(CountdownSheet.palette, id: \.self) { hex in
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 32, height: 32)
                                    .overlay(Circle().stroke(Color.primary.opacity(0.08), lineWidth: 1))
                                    .overlay(
                                        colorHex == hex ?
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 13, weight: .heavy))
                                                .foregroundColor(.white) : nil)
                                    .onTapGesture { colorHex = hex; Haptic.tick() }
                            }
                        }
                    }

                    Button {
                        saveAndClose()
                    } label: {
                        Text("保存修改")
                            .font(DS.F.bodySb)
                            .foregroundColor(title.trimmingCharacters(in: .whitespaces).isEmpty
                                             ? .secondary : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Capsule().fill(
                                title.trimmingCharacters(in: .whitespaces).isEmpty
                                ? Color(.tertiarySystemGroupedBackground)
                                : Color(hex: colorHex)))
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)

                    Button(role: .destructive) { confirmDelete = true } label: {
                        Label("删除此目标", systemImage: "trash")
                            .font(DS.F.subheadSb)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                    }
                    .confirmationDialog("删除「\(title)」？", isPresented: $confirmDelete,
                                        titleVisibility: .visible) {
                        Button("删除", role: .destructive) {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                Store.shared.deleteCountdown(target)
                                onDone()
                            }
                        }
                        Button("取消", role: .cancel) {}
                    }
                }
                .padding(DS.S.xl)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("编辑目标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                title = target.title
                date = target.targetDate
                colorHex = target.colorHex
            }
        }
    }

    private func saveAndClose() {
        target.title = title.trimmingCharacters(in: .whitespaces)
        target.targetDate = date
        target.colorHex = colorHex
        Store.shared.save()
        Haptic.success()
        dismiss()
        onDone()
    }
}
