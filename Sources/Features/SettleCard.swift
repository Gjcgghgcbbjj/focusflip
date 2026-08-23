import SwiftUI

/// 阶段自然完成的全屏结算卡
struct SettleCard: View {
    let info: PhaseCompletion
    let taskColor: Color
    let todayCount: Int
    let startNext: () -> Void
    let later: () -> Void

    @State private var appear = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [taskColor.opacity(0.96), Palette.deepVariant(taskColor)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    Haptic.light()
                    later()
                }

            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.13))
                        .frame(width: 94, height: 94)
                        .overlay(Circle().stroke(Color.white.opacity(0.28), lineWidth: 1.5))
                        .shadow(color: Color.black.opacity(0.12), radius: 22, y: 10)
                    Image(systemName: info.wasFocus ? "checkmark" : "cup.and.saucer.fill")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundColor(.white)
                }
                .scaleEffect(appear ? 1 : 0.5)
                .opacity(appear ? 1 : 0)

                Text(info.wasFocus ? "专注完成" : "休息结束")
                    .font(.system(size: 13, weight: .semibold))
                    .kerning(3)
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.top, 22)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    RollText(value: info.minutes,
                             font: .system(size: 64, weight: .light, design: .rounded),
                             color: .white)
                    Text("分钟")
                        .font(DS.F.bodyMd)
                        .foregroundColor(.white.opacity(0.85))
                }
                .padding(.top, 10)

                if info.wasFocus {
                    Text("今日第 \(todayCount) 个番茄")
                        .font(DS.F.subhead)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.top, 8)
                        .transition(.opacity.combined(with: .scale(scale: 1.03)))
                }

                Spacer()

                if info.nextPrepared {
                    Button(action: startNext) {
                        Text(info.wasFocus ? "开始休息" : "开始专注")
                            .font(DS.F.headline)
                            .foregroundColor(Palette.deepVariant(taskColor))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(
                                Capsule()
                                    .fill(Color.white)
                                    .shadow(color: Color.black.opacity(0.16), radius: 22, y: 10)
                            )
                    }
                    .buttonStyle(PressStyle())

                    Button(action: later) {
                        Text("稍后再说")
                            .font(DS.F.subheadSb)
                            .foregroundColor(.white.opacity(0.78))
                            .frame(maxWidth: .infinity, minHeight: DS.H.touchMin)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressStyle())
                } else {
                    // 已自动开跑下一阶段 → 仅确认收起。
                    Button(action: later) {
                        Text("继续当前阶段")
                            .font(DS.F.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: DS.H.primaryButton)
                            .background(Capsule().fill(Color.white.opacity(0.20)))
                    }
                    .buttonStyle(PressStyle())
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 24)
        }
        .statusBar(hidden: false)
        .gesture(
            DragGesture(minimumDistance: 24).onEnded { value in
                guard value.translation.height < -42 else { return }
                Haptic.light()
                later()
            }
        )
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { appear = true }
            Haptic.success()
        }
    }
}
