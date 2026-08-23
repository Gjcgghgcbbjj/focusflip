import SwiftUI

/// FocusFlip design system.
/// All shared typography, spacing, elevation, motion and reusable hub components live here.
struct DS {

    // MARK: - Typography

    struct F {
        static let display = Font.system(size: 56, weight: .light, design: .rounded)
        static let timerLg = Font.system(size: 62, weight: .light, design: .rounded)
        static let hero = Font.system(size: 38, weight: .bold, design: .rounded)
        static let numberL = Font.system(size: 24, weight: .bold, design: .rounded)
        static let title1  = Font.system(size: 30, weight: .bold, design: .rounded)
        static let title2  = Font.system(size: 22, weight: .bold, design: .rounded)
        static let numberM = Font.system(size: 17, weight: .bold, design: .rounded)
        static let headline = Font.system(size: 16, weight: .semibold)
        static let body     = Font.system(size: 15)
        static let bodyMd   = Font.system(size: 15, weight: .medium)
        static let bodySb   = Font.system(size: 15, weight: .semibold)
        static let subhead  = Font.system(size: 13, weight: .medium)
        static let subheadSb = Font.system(size: 13, weight: .semibold)
        static let caption  = Font.system(size: 11)
        static let microCaps = Font.system(size: 10, weight: .semibold)
    }

    // MARK: - Spacing

    struct S {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 32
        static let screen: CGFloat = 20
        static let card: CGFloat = 18
    }

    // MARK: - Radius

    struct R {
        static let hero: CGFloat = 28
        static let card: CGFloat = 22
        static let embedded: CGFloat = 16
        static let tile: CGFloat = 12
        static let composer: CGFloat = 14
    }

    // MARK: - Component sizes

    struct H {
        static let primaryButton: CGFloat = 54
        static let circleMain: CGFloat = 76
        static let ghostPill: CGFloat = 40
        static let chip: CGFloat = 38
        static let segInner: CGFloat = 36
        static let touchMin: CGFloat = 44
    }

    // MARK: - Motion

    struct Motion {
        static let quick = Animation.spring(response: 0.24, dampingFraction: 0.78)
        static let soft = Animation.spring(response: 0.34, dampingFraction: 0.84)
        static let ring = Animation.easeInOut(duration: 0.32)
        static let settle = Animation.spring(response: 0.45, dampingFraction: 0.76)
    }

    // MARK: - Semantic colors

    static let accent = Color(hex: "#5865F2")
    static let accentDeep = Color(hex: "#4C50E0")
    static let danger = Color(hex: "#E5573F")
    static let success = Color(hex: "#2FA84F")

    static var canvas: Color { Color(.systemGroupedBackground) }
    static var surface: Color { Color(.secondarySystemGroupedBackground) }
}

// MARK: - Elevation

extension DS {
    enum SurfaceRole {
        case standard, hero, overlay, inset
    }
}

private struct HubSurface: ViewModifier {
    let role: DS.SurfaceRole

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.primary.opacity(0.035), lineWidth: 0.5)
                    )
            )
            .shadow(color: Color.black.opacity(shadowOpacity),
                    radius: shadowRadius, x: 0, y: shadowY)
    }

    private var cornerRadius: CGFloat {
        switch role {
        case .hero, .overlay: return DS.R.hero
        case .standard: return DS.R.card
        case .inset: return DS.R.embedded
        }
    }

    private var shadowOpacity: Double {
        switch role {
        case .standard, .inset: return 0.055
        case .hero: return 0.075
        case .overlay: return 0.16
        }
    }

    private var shadowRadius: CGFloat {
        switch role {
        case .standard, .inset: return 18
        case .hero: return 26
        case .overlay: return 34
        }
    }

    private var shadowY: CGFloat {
        switch role {
        case .standard, .inset: return 7
        case .hero: return 12
        case .overlay: return 18
        }
    }
}

extension View {
    /// Adds the shared neutral card material without adding padding.
    func hubSurface(_ role: DS.SurfaceRole = .standard) -> some View {
        modifier(HubSurface(role: role))
    }

    /// Adds shared padding and card material.
    func hubCard(_ role: DS.SurfaceRole = .standard,
                 inset: CGFloat = DS.S.card) -> some View {
        self.padding(inset)
            .hubSurface(role)
    }
}

// MARK: - Reusable hub primitives

struct SectionHeader: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(DS.F.title2)
            Spacer(minLength: DS.S.sm)
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(DS.F.subheadSb)
                        .foregroundColor(DS.accent)
                        .padding(.vertical, DS.S.sm + 2)
                        .padding(.horizontal, DS.S.sm)
                }
                .buttonStyle(PressStyle())
            }
        }
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    var detail: String?
    var icon: String?
    var tint: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: DS.S.xs) {
            HStack(spacing: DS.S.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(tint)
                }
                Text(title)
                    .font(DS.F.microCaps)
                    .kerning(1.2)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(DS.F.numberL)
                .monospacedDigit()
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            if let detail {
                Text(detail)
                    .font(DS.F.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.S.md + 2)
        .hubSurface(.inset)
    }
}

struct PillControl<Label: View>: View {
    let isSelected: Bool
    var tint: Color = DS.accent
    @ViewBuilder let label: () -> Label

    var body: some View {
        label()
            .font(DS.F.subheadSb)
            .foregroundColor(isSelected ? .white : tint)
            .padding(.horizontal, DS.S.lg)
            .frame(minHeight: DS.H.chip)
            .background(Capsule().fill(isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(0.11))))
    }
}

// MARK: - iOS15 half-height sheet bridge（medium/large detents + grabber）

struct SheetDetents: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> DetentVC { DetentVC() }
    func updateUIViewController(_ vc: DetentVC, context: Context) {}

    final class DetentVC: UIViewController {
        override func willMove(toParent parent: UIViewController?) {
            super.willMove(toParent: parent)
            guard let sheet = parent?.presentationController
                    as? UISheetPresentationController else { return }
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
    }
}

// MARK: - Numeric tween

struct RollText: View {
    var value: Int
    var font: Font = DS.F.numberM
    var color: Color = .primary

    @State private var shown: Double = 0

    var body: some View {
        Text("\(Int(shown.rounded()))")
            .font(font)
            .monospacedDigit()
            .foregroundColor(color)
            .onAppear { shown = Double(value) }
            .onChange(of: value) { v in
                withAnimation(.easeOut(duration: 0.6)) { shown = Double(v) }
            }
    }
}

// MARK: - Press feedback / haptics

struct PressStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    var pressedOpacity: Double = 0.86

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? pressedOpacity : 1)
            .animation(.spring(response: 0.26, dampingFraction: 0.72),
                       value: configuration.isPressed)
    }
}

enum Haptic {
    static func tick() { UISelectionFeedbackGenerator().selectionChanged() }
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
