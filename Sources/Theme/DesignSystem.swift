import SwiftUI
import Foundation

// MARK: - Design Tokens
//
// Centralized design system inspired by Catppuccin Mocha + iOS 18 conventions.
// Every color, spacing, radius, and font in the app references these tokens
// to ensure visual consistency and eliminate "randomly picked" AI aesthetics.

enum DS {

    // MARK: - Color Palette (Catppuccin Mocha based)

    enum Color {
        // Backgrounds
        static let bgPrimary     = SwiftUI.Color(red: 0.118, green: 0.118, blue: 0.180)  // #1e1e2e
        static let bgSecondary   = SwiftUI.Color(red: 0.192, green: 0.196, blue: 0.267)  // #313244
        static let bgElevated    = SwiftUI.Color(red: 0.243, green: 0.247, blue: 0.314)  // #45475a
        static let bgOverlay     = SwiftUI.Color(red: 0.345, green: 0.353, blue: 0.439)  // #585b70

        // Text
        static let textPrimary   = SwiftUI.Color(red: 0.804, green: 0.839, blue: 0.957)  // #cdd6f4
        static let textSecondary = SwiftUI.Color(red: 0.651, green: 0.678, blue: 0.784)  // #a6adc8
        static let textMuted     = SwiftUI.Color(red: 0.580, green: 0.600, blue: 0.698)  // #9399b2

        // Phase colors (semantic)
        static let focus         = SwiftUI.Color(red: 0.953, green: 0.545, blue: 0.659)  // #f38ba8
        static let shortBreak    = SwiftUI.Color(red: 0.649, green: 0.891, blue: 0.631)  // #a6e3a1
        static let longBreak     = SwiftUI.Color(red: 0.537, green: 0.706, blue: 0.980)  // #89b4fa

        // Accents
        static let accent        = SwiftUI.Color(red: 0.796, green: 0.649, blue: 0.969)  // #cba6f7
        static let warning       = SwiftUI.Color(red: 0.949, green: 0.761, blue: 0.408)  // #f9e2af
        static let danger        = SwiftUI.Color(red: 0.953, green: 0.545, blue: 0.659)  // #f38ba8
    }

    // MARK: - Spacing (4pt grid)

    enum S {
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 16
        static let lg:  CGFloat = 24
        static let xl:  CGFloat = 32
        static let xxl: CGFloat = 48
        static let xxxl: CGFloat = 64
    }

    // MARK: - Corner Radius

    enum R {
        static let sm:   CGFloat = 8
        static let md:   CGFloat = 12
        static let lg:   CGFloat = 16
        static let xl:   CGFloat = 20
        static let pill: CGFloat = 999
    }

    // MARK: - Typography

    enum Font {
        // Timer display — ultra light for elegance
        static let timerDisplay = SwiftUI.Font.system(size: 76, weight: .ultraLight, design: .rounded)
        static let timerDisplayLarge = SwiftUI.Font.system(size: 88, weight: .ultraLight, design: .rounded)

        // Headlines
        static let title1     = SwiftUI.Font.system(size: 28, weight: .bold, design: .rounded)
        static let title2     = SwiftUI.Font.system(size: 22, weight: .semibold, design: .rounded)
        static let headline   = SwiftUI.Font.system(size: 17, weight: .semibold, design: .rounded)

        // Body
        static let body       = SwiftUI.Font.system(size: 16, weight: .regular, design: .rounded)
        static let bodyMono   = SwiftUI.Font.system(size: 16, weight: .regular, design: .monospaced)

        // Labels
        static let caption    = SwiftUI.Font.system(size: 13, weight: .regular, design: .rounded)
        static let captionBold = SwiftUI.Font.system(size: 13, weight: .semibold, design: .rounded)
        static let micro      = SwiftUI.Font.system(size: 11, weight: .regular, design: .rounded)
    }

    // MARK: - Animation

    enum Anim {
        static let standard    = Animation.easeInOut(duration: 0.25)
        static let spring      = Animation.spring(response: 0.35, dampingFraction: 0.75)
        static let bouncy      = Animation.spring(response: 0.3, dampingFraction: 0.6)
        static let progress    = Animation.linear(duration: 0.95)
        static let slow        = Animation.easeInOut(duration: 0.6)
    }
}

// MARK: - Phase Theme

/// Maps a SessionType to its semantic color and visual identity.
struct PhaseTheme {
    let color: SwiftUI.Color
    let label: String
    let icon: String
    let gradient: [SwiftUI.Color]

    static func theme(for type: SessionType) -> PhaseTheme {
        switch type {
        case .focus:
            return PhaseTheme(
                color: DS.Color.focus,
                label: "专注",
                icon: "brain.head.profile",
                gradient: [
                    DS.Color.focus.opacity(0.15),
                    DS.Color.focus.opacity(0.02)
                ]
            )
        case .shortBreak:
            return PhaseTheme(
                color: DS.Color.shortBreak,
                label: "短休息",
                icon: "cup.and.saucer",
                gradient: [
                    DS.Color.shortBreak.opacity(0.15),
                    DS.Color.shortBreak.opacity(0.02)
                ]
            )
        case .longBreak:
            return PhaseTheme(
                color: DS.Color.longBreak,
                label: "长休息",
                icon: "leaf",
                gradient: [
                    DS.Color.longBreak.opacity(0.15),
                    DS.Color.longBreak.opacity(0.02)
                ]
            )
        }
    }
}

// MARK: - View Modifiers

/// Card background with consistent styling.
struct CardBackground: ViewModifier {
    var padding: CGFloat = DS.S.md

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: DS.R.lg)
                    .fill(DS.Color.bgSecondary)
            )
    }
}

extension View {
    func card(padding: CGFloat = DS.S.md) -> some View {
        modifier(CardBackground(padding: padding))
    }

    /// Press scale feedback for buttons.
    func pressable(scale: CGFloat = 0.94) -> some View {
        modifier(PressableModifier(scale: scale))
    }
}

struct PressableModifier: ViewModifier {
    let scale: CGFloat
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? scale : 1.0)
            .animation(DS.Anim.bouncy, value: isPressed)
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, perform: {}, onPressingChanged: { pressing in
                isPressed = pressing
            })
    }
}

// MARK: - Color hex init

extension SwiftUI.Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: s).scanHexInt64(&int)
        let r: UInt64, g: UInt64, b: UInt64
        switch s.count {
        case 3:
            r = (int >> 8) * 17
            g = (int >> 4 & 0xF) * 17
            b = (int & 0xF) * 17
        case 6:
            r = int >> 16
            g = int >> 8 & 0xFF
            b = int & 0xFF
        default:
            r = 243; g = 139; b = 168
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}
