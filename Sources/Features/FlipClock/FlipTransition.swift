import SwiftUI

/// Simple opacity transition modifier (replaces 3D flip).
struct FlipTransition: ViewModifier {
    let value: Int

    func body(content: Content) -> some View {
        content
            .id(value)
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}

extension View {
    func flipTransition(for value: Int) -> some View {
        modifier(FlipTransition(value: value))
    }
}
