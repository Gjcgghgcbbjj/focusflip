import SwiftUI

// MARK: - Design System 3.0 — "Calm Focus"
//
// 设计哲学：
// - 纯黑/纯白底，唯一强调色来自用户选择的主题色
// - 大留白，元素少而精
// - 数字是主角：SF Pro Rounded 超细体
// - 动效克制：只在状态切换时有意义地动

enum DS3 {

    // MARK: Spacing (4pt grid)
    enum S {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: Radius
    enum R {
        static let sm: CGFloat = 10
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let pill: CGFloat = 999
    }

    // MARK: Colors
    enum Color {
        // 纯底色：dark 近黑 / light 纯白
        static let bg = adaptive(dark: "#000000", light: "#FFFFFF")
        // 卡片：dark 极浅灰阶 / light 浅灰
        static let surface = adaptive(dark: "#1C1C1E", light: "#F2F2F7")
        // 主文字
        static let text = adaptive(dark: "#FFFFFF", light: "#000000")
        // 次级文字
        static let textDim = adaptive(dark: "#8E8E93", light: "#8E8E93")
        // 分隔
        static let hairline = adaptive(dark: "#38383A", light: "#E5E5EA")

        // 强调色：用户主题色（动态读取设置）
        static var accent: SwiftUI.Color { AppSettings.shared.accentColor }

        // 阶段色：专注=主题色；短休=绿；长休=青蓝
        static var focus: SwiftUI.Color { accent }
        static let shortBreak = adaptive(dark: "#30D158", light: "#34C759")
        static let longBreak = adaptive(dark: "#64D2FF", light: "#32ADE6")

        // 语义
        static let warn = adaptive(dark: "#FFD60A", light: "#FF9500")
        static let danger = adaptive(dark: "#FF453A", light: "#FF3B30")
    }

    // MARK: Font
    enum Font {
        static let timerHuge = SwiftUI.Font.system(size: 88, weight: .thin, design: .rounded)
        static let timerBig = SwiftUI.Font.system(size: 64, weight: .thin, design: .rounded)
        static let numXL = SwiftUI.Font.system(size: 40, weight: .light, design: .rounded)
        static let numL = SwiftUI.Font.system(size: 28, weight: .semibold, design: .rounded)
        static let title = SwiftUI.Font.system(size: 22, weight: .semibold, design: .rounded)
        static let headline = SwiftUI.Font.system(size: 17, weight: .semibold)
        static let body = SwiftUI.Font.system(size: 16, weight: .regular)
        static let sub = SwiftUI.Font.system(size: 14, weight: .regular)
        static let caption = SwiftUI.Font.system(size: 12, weight: .regular)
        static let micro = SwiftUI.Font.system(size: 10, weight: .medium)
    }

    // MARK: Animation
    enum Anim {
        static let quick: Animation = .easeOut(duration: 0.18)
        static let smooth: Animation = .easeInOut(duration: 0.35)
        static let gentle: Animation = .easeInOut(duration: 0.6)
        static let spring: Animation = .spring(response: 0.45, dampingFraction: 0.75)
    }

    // MARK: Helpers

    static func adaptive(dark: String, light: String) -> SwiftUI.Color {
        SwiftUI.Color(UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(hex: dark)
                : UIColor(hex: light)
        })
    }
}

// MARK: - Hex support

extension UIColor {
    convenience init(hex: String) {
        var c = hex.replacingOccurrences(of: "#", with: "")
        if c.count == 6 { c = "FF" + c }   // -> AARRGGBB
        var v: UInt64 = 0
        Scanner(string: c).scanHexInt64(&v)
        self.init(
            red: CGFloat((v >> 16) & 0xFF) / 255,
            green: CGFloat((v >> 8) & 0xFF) / 255,
            blue: CGFloat(v & 0xFF) / 255,
            alpha: CGFloat(v & 0xFF) / 255
        )
    }
}

extension SwiftUI.Color {
    init(hex: String) {
        self.init(UIColor(hex: hex))
    }
}

// MARK: - Phase theme (v3)

struct PhaseTheme3 {
    let color: SwiftUI.Color
    let icon: String
    let label: String

    static func theme(for type: SessionType) -> PhaseTheme3 {
        switch type {
        case .focus:
            return .init(color: DS3.Color.focus, icon: "brain.head.profile", label: "专注")
        case .shortBreak:
            return .init(color: DS3.Color.shortBreak, icon: "cup.and.saucer", label: "小憩")
        case .longBreak:
            return .init(color: DS3.Color.longBreak, icon: "leaf", label: "长歇")
        }
    }
}

// MARK: - View helpers

extension View {
    /// Surface card used across screens.
    func card3(inset: CGFloat = DS3.S.md) -> some View {
        padding(inset)
            .background(RoundedRectangle(cornerRadius: DS3.R.md).fill(DS3.Color.surface))
    }

    @ViewBuilder
    func hideScrollBackground3() -> some View {
        if #available(iOS 16.0, *) {
            scrollContentBackground(.hidden)
        } else {
            self
        }
    }

    @ViewBuilder
    func numericTransition3() -> some View {
        if #available(iOS 16.0, *) {
            contentTransition(.numericText())
        } else {
            self
        }
    }

    func pressable3() -> some View {
        buttonStyle(PressStyle3())
    }
}

struct PressStyle3: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(DS3.Anim.quick, value: configuration.isPressed)
    }
}
