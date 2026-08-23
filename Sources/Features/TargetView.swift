import SwiftUI

/// 目标页 —— 紧急度分层的日期卡系统。
struct TargetView: View {

    @State private var items: [CountdownEntity] = []
    @State private var showManager = false
    @State private var editing: CountdownEntity?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 14) {
                    if items.isEmpty { emptyState }

                    ForEach(items) { item in
                        countdownCard(item)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                Haptic.light()
                                editing = item
                            }
                            .contextMenu {
                                Button {
                                    Haptic.light()
                                    editing = item
                                } label: {
                                    Label("编辑", systemImage: "pencil")
                                }
                                Button {
                                    duplicate(item)
                                } label: {
                                    Label("复制目标", systemImage: "doc.on.doc")
                                }
                                Button { postpone(item, days: 1) } label: {
                                    Label("推迟 1 天", systemImage: "calendar.badge.plus")
                                }
                                Button { postpone(item, days: 7) } label: {
                                    Label("推迟 7 天", systemImage: "calendar.badge.plus")
                                }
                                Divider()
                                Button(role: .destructive) { delete(item) } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                            .gesture(cardSwipe(item))
                    }
                }
                .padding(.horizontal, DS.S.screen)
                .padding(.vertical, DS.S.md + 2)
            }
            .background(DS.canvas)
            .navigationTitle("目标")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Haptic.light()
                        showManager = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 23, weight: .medium))
                            .foregroundColor(DS.accent)
                            .frame(width: DS.H.touchMin, height: DS.H.touchMin)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressStyle())
                }
            }
            .sheet(isPresented: $showManager) {
                CountdownSheet()
            }
            .sheet(item: $editing) { item in
                EditCountdownSheet(target: item) { reload() }
                    .background(SheetDetents())
            }
            .onAppear(perform: reload)
            .onChange(of: showManager) { open in
                if !open { reload() }
            }
        }
    }

    // MARK: 卡片分层

    @ViewBuilder
    private func countdownCard(_ item: CountdownEntity) -> some View {
        let days = CountdownSheet.daysLeft(item.targetDate)

        if !safe(item) {
            EmptyView().frame(height: 0)
        } else if days < 0 {
            pastCard(item, days: days)
        } else if days > 30 {
            slimCard(item, days: days)
        } else if days <= 7 {
            heroCard(item, urgent: true)
        } else {
            heroCard(item, urgent: false)
        }
    }

    private func pastCard(_ item: CountdownEntity, days: Int) -> some View {
        HStack(spacing: DS.S.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(DS.F.headline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Text(CountdownSheet.dateText(item.targetDate))
                    .font(DS.F.caption)
                    .foregroundColor(.secondary.opacity(0.72))
            }

            Spacer()

            Text("已过期 \(abs(days)) 天")
                .font(DS.F.microCaps)
                .foregroundColor(DS.danger)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Capsule().fill(DS.danger.opacity(0.10)))
        }
        .padding(DS.S.card)
        .hubSurface(.standard)
        .opacity(0.78)
    }

    private func slimCard(_ item: CountdownEntity, days: Int) -> some View {
        let base = Color(hex: item.colorHex)

        return HStack(spacing: DS.S.md) {
            RoundedRectangle(cornerRadius: DS.R.tile, style: .continuous)
                .fill(base.opacity(0.14))
                .frame(width: 44, height: 44)
                .overlay(Image(systemName: "flag").font(.system(size: 15)).foregroundColor(base))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(DS.F.headline)
                    .lineLimit(1)
                Text(CountdownSheet.dateText(item.targetDate))
                    .font(DS.F.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 0) {
                Text("\(days)")
                    .font(DS.F.numberM)
                    .monospacedDigit()
                    .foregroundColor(base)
                Text("天")
                    .font(DS.F.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(DS.S.card - 2)
        .hubSurface(.standard)
    }

    private func heroCard(_ item: CountdownEntity, urgent: Bool) -> some View {
        let days = CountdownSheet.daysLeft(item.targetDate)
        let base = Color(hex: item.colorHex)
        let span = max(1, item.targetDate.timeIntervalSince(item.createdAt) / 86400)
        let used = min(1, max(0.04, Date().timeIntervalSince(item.createdAt) / (span * 86400)))

        return VStack(alignment: .leading, spacing: DS.S.lg) {
            HStack(alignment: .top, spacing: DS.S.lg) {
                VStack(alignment: .leading, spacing: 6) {
                    if urgent {
                        Label("最后 \(days) 天", systemImage: "flame.fill")
                            .font(DS.F.microCaps)
                            .foregroundColor(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.white.opacity(0.20)))
                    }

                    Text(item.title)
                        .font(DS.F.title2)
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(CountdownSheet.dateText(item.targetDate))
                        .font(DS.F.subhead)
                        .foregroundColor(.white.opacity(0.76))
                }

                Spacer(minLength: DS.S.md)
                progressRing(days: days, progress: used)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.22))
                    Capsule().fill(Color.white)
                        .frame(width: geo.size.width * CGFloat(used))
                }
            }
            .frame(height: 5)
        }
        .padding(DS.S.card + 2)
        .background(
            RoundedRectangle(cornerRadius: DS.R.hero, style: .continuous)
                .fill(LinearGradient(colors: [base.opacity(0.96), Palette.deepVariant(base)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.R.hero, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                )
        )
        .shadow(color: base.opacity(urgent ? 0.30 : 0.20), radius: 24, y: 11)
    }

    private func progressRing(days: Int, progress: Double) -> some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.22), lineWidth: 5)
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(Color.white, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(DS.Motion.soft, value: progress)

            VStack(spacing: 0) {
                Text("\(max(0, days))")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.65)
                Text(days == 0 ? "今天" : "天")
                    .font(DS.F.microCaps)
                    .foregroundColor(.white.opacity(0.78))
            }
            .padding(10)
        }
        .frame(width: 74, height: 74)
    }

    private func cardSwipe(_ item: CountdownEntity) -> some Gesture {
        DragGesture(minimumDistance: 28).onEnded { value in
            let horizontal = abs(value.translation.width)
            guard horizontal > 58,
                  horizontal > abs(value.translation.height) else { return }

            if value.translation.width < 0 {
                delete(item)
            } else {
                postpone(item, days: 7)
            }
        }
    }

    // MARK: 操作

    private func safe(_ item: CountdownEntity) -> Bool { item.managedObjectContext != nil }

    private func duplicate(_ item: CountdownEntity) {
        guard safe(item) else { return }
        _ = Store.shared.addCountdown(title: item.title,
                                      date: item.targetDate,
                                      colorHex: item.colorHex)
        Haptic.light()
        reload()
    }

    private func postpone(_ item: CountdownEntity, days: Int) {
        guard safe(item), days > 0 else { return }
        item.targetDate = Calendar.current.date(byAdding: .day, value: days, to: item.targetDate) ?? item.targetDate
        Store.shared.save()
        Haptic.light()
        reload()
    }

    private func delete(_ item: CountdownEntity) {
        guard safe(item) else { return }
        let title = item.title
        let date = item.targetDate
        let hex = item.colorHex

        var tx = Transaction(); tx.disablesAnimations = true
        withTransaction(tx) { Store.shared.deleteCountdown(item) }

        Haptic.warning()
        ToastCenter.shared.show("已删除「\(title)」") {
            _ = Store.shared.addCountdown(title: title, date: date, colorHex: hex)
            reload()
        }
        DispatchQueue.main.async { reload() }
    }

    // MARK: 空态

    private var emptyState: some View {
        VStack(spacing: DS.S.md) {
            ZStack {
                Circle().fill(DS.accent.opacity(0.07)).frame(width: 78, height: 78)
                Circle().stroke(DS.accent.opacity(0.16), lineWidth: 1.4).frame(width: 78, height: 78)
                Image(systemName: "flag.checkered")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(DS.accent.opacity(0.62))
            }

            Text("有一个在倒数的日子\n会让人踏实很多")
                .font(DS.F.headline)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            Text("高考 · 考试 · 生日 · DDL")
                .font(DS.F.caption)
                .foregroundColor(.secondary)

            Button {
                Haptic.light()
                showManager = true
            } label: {
                Label("添加目标", systemImage: "plus.circle.fill")
                    .font(DS.F.bodySb)
                    .foregroundColor(.white)
                    .padding(.horizontal, 22)
                    .frame(minHeight: DS.H.touchMin)
                    .background(
                        Capsule()
                            .fill(DS.accent)
                            .shadow(color: DS.accent.opacity(0.22), radius: 16, y: 7)
                    )
            }
            .buttonStyle(PressStyle())
            .padding(.top, DS.S.xs)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.S.card)
        .hubCard(.hero)
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
                        if date < Calendar.current.startOfDay(for: Date()) {
                            Text("将显示为已过期")
                                .font(DS.F.caption)
                                .foregroundColor(DS.danger)
                        }
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
                    .buttonStyle(PressStyle())

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
