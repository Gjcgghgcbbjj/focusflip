import SwiftUI

// MARK: - Design System v2.0
//
// 对标 Be Focused / Focus Keeper / Flow：
// 极简专业风、纯净背景、语义化阶段色、等宽数字、无装饰干扰。

struct DS {

    // MARK: - Spacing
    enum S {
        static let xxxs: CGFloat = 2
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 6
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
        static let huge: CGFloat = 48
    }

    // MARK: - Radius
    enum R {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let pill: CGFloat = 999
    }

    // MARK: - Color tokens (adaptive dark/light via UIColor init)
    //
    // 对标 Flow 的纯黑背景 + Be Focused 的语义色。
    // Dark: 近黑底 + 柔和高对比文字
    // Light: 纯白底 + 深色文字

    enum Color {
        // Backgrounds
        static let bgPrimary = adaptive(dark: "#0A0A0C", light: "#FFFFFF")
        static let bgSecondary = adaptive(dark: "#16161A", light: "#F5F5F7")
        static let bgTertiary = adaptive(dark: "#1E1E24", light: "#EBEBEF")

        // Text
        static let textPrimary = adaptive(dark: "#F5F5F7", light: "#1A1A1E")
        static let textSecondary = adaptive(dark: "#98989F", light: "#6E6E76")
        static let textMuted = adaptive(dark: "#5C5C64", light: "#A0A0A8")

        // Semantic phase colors (对标 Be Focused: 红=专注 绿=短休 紫=长休)
        // focus 色可从设置中自定义（themeColorHex），其余固定语义色。
        static var focus: SwiftUI.Color {
            let hex = AppSettings.shared.themeColorHex
            // 保证六位 hex
            guard hex.count == 7, hex.hasPrefix("#") else {
                return adaptive(dark: "#FF4D4A", light: "#FF3B30")
            }
            return SwiftUI.Color(UIColor(hex: hex))
        }
        static let shortBreak = adaptive(dark: "#32D74B", light: "#34C759")  // 短休-绿
        static let longBreak = adaptive(dark: "#BF5AF2", light: "#AF52DE")  // 长休-紫

        // UI accents
        static var accent: SwiftUI.Color { focus }  // 跟随专注色（可自定义）
        static let warning = adaptive(dark: "#FFD60A", light: "#FF9500")
        static let success = shortBreak
        static var danger: SwiftUI.Color { focus }

        // Separators
        static let separator = adaptive(dark: "#FFFFFF0D", light: "#0000000D")

        // Heatmap scale
        static func heatLevel(_ level: Int) -> SwiftUI.Color {
            switch level {
            case 0:     return textPrimary.opacity(0.06)
            case 1:     return focus.opacity(0.20)
            case 2:     return focus.opacity(0.40)
            case 3:     return focus.opacity(0.60)
            case 4:     return focus.opacity(0.80)
            default:    return focus
            }
        }
    }

    // MARK: - Typography
    enum Font {
        // Timer display — ultra-light, large, monospaced
        static let timerDisplay = SwiftUI.Font.system(size: 64, weight: .ultraLight, design: .rounded)
        // Headlines
        static let largeTitle = SwiftUI.Font.system(size: 34, weight: .bold, design: .rounded)
        static let title = SwiftUI.Font.system(size: 28, weight: .bold, design: .rounded)
        static let title2 = SwiftUI.Font.system(size: 22, weight: .semibold, design: .rounded)
        static let headline = SwiftUI.Font.system(size: 17, weight: .semibold)
        static let body = SwiftUI.Font.system(size: 16, weight: .regular)
        static let callout = SwiftUI.Font.system(size: 15, weight: .regular)
        static let caption = SwiftUI.Font.system(size: 13, weight: .regular)
        static let captionBold = SwiftUI.Font.system(size: 13, weight: .semibold)
        static let micro = SwiftUI.Font.system(size: 11, weight: .regular)
        static let microBold = SwiftUI.Font.system(size: 11, weight: .semibold)
        // Stats numbers
        static let statLarge = SwiftUI.Font.system(size: 40, weight: .ultraLight, design: .rounded)
        static let statMedium = SwiftUI.Font.system(size: 24, weight: .semibold, design: .rounded)
    }

    // MARK: - Animation
    enum Anim {
        static let instant: Animation = .easeInOut(duration: 0.15)
        static let fast: Animation = .easeInOut(duration: 0.2)
        static let standard: Animation = .easeInOut(duration: 0.3)
        static let slow: Animation = .easeInOut(duration: 0.5)
        static let bouncy: Animation = .spring(response: 0.4, dampingFraction: 0.7)
        static let ring: Animation = .linear(duration: 1.0)
    }

    // MARK: - UIColor bridge for UIKit appearance
    enum UIColorToken {
        static let bgPrimary = uiColor(dark: "#0A0A0C", light: "#FFFFFF")
        static let textPrimary = uiColor(dark: "#F5F5F7", light: "#1A1A1E")
    }

    // MARK: - Helpers

    /// Adaptive color from hex strings for dark/light mode.
    static func adaptive(dark: String, light: String) -> SwiftUI.Color {
        SwiftUI.Color(uiColor(dark: dark, light: light))
    }

    static func uiColor(dark: String, light: String) -> UIColor {
        UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(hex: dark)
                : UIColor(hex: light)
        }
    }
}

// Hex init extensions moved to DesignSystem3.swift (single definition).

// MARK: - Phase Theme
//
// 每个阶段一套色板：主色 + 渐变背景 + 图标 + 标签。
// 对标 Flow 的沉浸式阶段切换。

struct PhaseTheme {
    let color: SwiftUI.Color
    let gradient: [SwiftUI.Color]
    let icon: String
    let label: String

    static func theme(for type: SessionType) -> PhaseTheme {
        switch type {
        case .focus:
            return PhaseTheme(
                color: DS.Color.focus,
                gradient: [DS.Color.focus.opacity(0.15), .clear],
                icon: "brain.head.profile",
                label: "专注"
            )
        case .shortBreak:
            return PhaseTheme(
                color: DS.Color.shortBreak,
                gradient: [DS.Color.shortBreak.opacity(0.15), .clear],
                icon: "cup.and.saucer",
                label: "短休息"
            )
        case .longBreak:
            return PhaseTheme(
                color: DS.Color.longBreak,
                gradient: [DS.Color.longBreak.opacity(0.15), .clear],
                icon: "leaf",
                label: "长休息"
            )
        }
    }
}

// MARK: - View modifiers

extension View {
    /// Card background with consistent corner radius and color.
    func card(padding: CGFloat = DS.S.lg) -> some View {
        self.padding(padding)
            .background(
                RoundedRectangle(cornerRadius: DS.R.lg)
                    .fill(DS.Color.bgSecondary)
            )
    }

    /// Press animation: scale down slightly on press.
    func pressable() -> some View {
        self.buttonStyle(PressableStyle())
    }

    /// Apply numeric text transition on iOS 16+.
    @ViewBuilder
    func numericTextTransition() -> some View {
        if #available(iOS 16.0, *) {
            self.contentTransition(.numericText())
        } else {
            self
        }
    }

    /// Hide scroll view background on iOS 16+.
    @ViewBuilder
    func hideScrollBackground() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}

// MARK: - Pressable button style

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(DS.Anim.fast, value: configuration.isPressed)
    }
}
