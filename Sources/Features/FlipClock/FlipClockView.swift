import SwiftUI

/// Clean numeric time display (MM:SS or HH:MM:SS).
///
/// Replaces the 3D flip-clock with a modern, minimal numeric readout.
/// Uses SF Pro Rounded ultra-light + monospacedDigit for stability.
/// `.contentTransition(.numericText())` provides a subtle per-digit
/// crossfade on change — elegant without being distracting.
struct FlipClockView: View {

    let totalSeconds: Int
    var digitHeight: CGFloat = 64   // kept for API compat; controls font size
    var showHours: Bool = false

    private var timeString: String {
        let h = totalSeconds / 3600
        let m = showHours ? (totalSeconds % 3600) / 60 : totalSeconds / 60
        let s = showHours ? (totalSeconds % 3600) % 60 : totalSeconds % 60

        if showHours || h > 0 {
            return String(format: "%02d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    var body: some View {
        Text(timeString)
            .font(.system(size: digitHeight * 1.15, weight: .ultraLight, design: .rounded))
            .monospacedDigit()
            .foregroundColor(DS.Color.textPrimary)
            .numericTextTransition()
            .animation(.easeInOut(duration: 0.2), value: totalSeconds)
    }
}
