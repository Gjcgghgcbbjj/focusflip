import SwiftUI

/// Simple digit component with subtle fade transition.
/// Kept for backward compatibility; FlipClockView now uses Text directly.
struct FlipDigitView: View {
    let digit: Int
    var size: CGFloat = 120

    var body: some View {
        Text("\(digit)")
            .font(.system(size: size * 0.75, weight: .ultraLight, design: .rounded))
            .monospacedDigit()
            .foregroundColor(DS.Color.textPrimary)
            .numericTextTransition()
            .animation(.easeInOut(duration: 0.2), value: digit)
    }
}

// MARK: - Animation tokens (kept for reference by other files)

enum FlipAnim {
    static let topFall = Animation.timingCurve(0.42, 0.0, 0.58, 1.0, duration: 0.18)
    static let bottomLand = Animation.timingCurve(0.25, 0.46, 0.45, 0.94, duration: 0.20)
    static let ring = Animation.linear(duration: 0.95)
    static let bgTransition = Animation.easeInOut(duration: 0.6)
    static let buttonPress = Animation.spring(response: 0.3, dampingFraction: 0.6)
    static let colonBlink = Animation.easeInOut(duration: 1.0)
}
