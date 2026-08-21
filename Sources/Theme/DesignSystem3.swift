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

        // 场景专用固定色（计时页永远电影化，不随主题翻转）
        static let sceneText = SwiftUI.Color(hex: "#FFFFFF")
        static let sceneTextDim = SwiftUI.Color(hex: "#9A9AA2")
        static let sceneHairline = SwiftUI.Color.white.opacity(0.18)
        static let sceneSurface = SwiftUI.Color(hex: "#1C1C1E")
        static let sceneIconOnAccent = SwiftUI.Color(hex: "#0B0B0B")

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

    /// 全屏氛围底色：顶部一抹阶段色，向下沉入纯黑。
    static func ambientBackground(for type: SessionType) -> some View {
        let c = theme(for: type).color
        return ZStack {
            LinearGradient(colors: [c.opacity(0.18), SwiftUI.Color.clear],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [c.opacity(0.12), SwiftUI.Color.clear],
                           center: .top, startRadius: 0, endRadius: 520)
        }
        .ignoresSafeArea()
    }

    /// 全屏沉浸场景：三段深色场 + 双光斑漂移（潮汐式）。
    /// 用 TimelineView 驱动位移——确定性动画，必然生效。
    static func sceneBackground(for type: SessionType) -> some View {
        let c = theme(for: type).color
        return ZStack {
            SwiftUI.Color.black.ignoresSafeArea()
            LinearGradient(stops: [
                .init(color: c.opacity(0.34), location: 0),
                .init(color: c.opacity(0.12), location: 0.45),
                .init(color: SwiftUI.Color.black, location: 1),
            ], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()

            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                let p1 = CGPoint(x: sin(t / 9 * 2 * .pi) * 46,
                                 y: cos(t / 11 * 2 * .pi) * 26)
                let p2 = CGPoint(x: cos(t / 13 * 2 * .pi) * -38,
                                 y: sin(t / 8 * 2 * .pi) * 30)
                ZStack {
                    sceneBlob(c, opacity: 0.38, size: 430)
                        .offset(x: p1.x - 70, y: p1.y - 240)
                    sceneBlob(c, opacity: 0.20, size: 320)
                        .offset(x: p2.x + 110, y: p2.y - 60)
                }
            }

            LinearGradient(colors: [SwiftUI.Color.clear,
                                    SwiftUI.Color.black.opacity(0.45)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }

    private static func sceneBlob(_ c: SwiftUI.Color, opacity: Double, size: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(colors: [c.opacity(opacity),
                                          c.opacity(opacity * 0.4),
                                          SwiftUI.Color.clear],
                                 center: .center, startRadius: 0, endRadius: size / 2))
            .blur(radius: 42)
            .frame(width: size, height: size)
    }
}

// MARK: - 小构件

/// 彩色图标砖（iOS 设置/Ice Cubes 风格）
struct IconTile: View {
    let systemName: String
    let tint: SwiftUI.Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(tint)
            .frame(width: 27, height: 27)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(tint.opacity(0.16))
            )
    }
}

// MARK: - UIKit bridge (for UIAppearance)

extension DS3 {
    enum UIColorToken {
        static let bg = UIColor { tc in
            tc.userInterfaceStyle == .dark ? UIColor(hex: "#000000") : UIColor(hex: "#FFFFFF")
        }
        static let surface = UIColor { tc in
            tc.userInterfaceStyle == .dark ? UIColor(hex: "#1C1C1E") : UIColor(hex: "#F2F2F7")
        }
        static let text = UIColor { tc in
            tc.userInterfaceStyle == .dark ? UIColor(hex: "#FFFFFF") : UIColor(hex: "#000000")
        }
        static let textDim = UIColor(hex: "#8E8E93")
    }
}

// MARK: - View helpers

extension View {
    /// Surface card used across screens (bordered, lifted from bg).
    func card3(inset: CGFloat = DS3.S.md) -> some View {
        padding(inset)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(DS3.Color.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(DS3.Color.hairline.opacity(0.7), lineWidth: 0.5)
                    )
            )
    }

    /// Soft outer glow (for rings / primary buttons).
    func glow(_ color: SwiftUI.Color, radius: CGFloat = 14, opacity: Double = 0.5) -> some View {
        shadow(color: color.opacity(opacity), radius: radius)
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
