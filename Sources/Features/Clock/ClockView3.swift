import SwiftUI

/// 桌面翻页时钟 — 全屏极简时钟，适合充电/工作台常亮显示。
/// 点击任意处或下滑退出；打开期间保持屏幕常亮。
struct ClockView3: View {

    @Environment(\.dismiss) private var dismiss
    @State private var now = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            DS3.Color.bg.ignoresSafeArea()

            VStack(spacing: DS3.S.md) {
                Spacer()

                Text(timeText)
                    .font(.system(size: 96, weight: .thin, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(DS3.Color.text)
                    .numericTransition3()
                    .animation(DS3.Anim.smooth, value: minuteValue)

                Text(dateLine)
                    .font(DS3.Font.headline)
                    .foregroundColor(DS3.Color.textDim)

                Spacer()
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .onReceive(timer) { now = $0 }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
    }

    private var minuteValue: Int {
        Calendar.current.component(.minute, from: now)
    }

    private var timeText: String {
        let c = Calendar.current
        let h = c.component(.hour, from: now)
        let m = c.component(.minute, from: now)
        return String(format: "%02d:%02d", h, m)
    }

    private var dateLine: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "zh_CN")
        df.dateFormat = "M月d日 EEEE"
        return df.string(from: now)
    }
}
