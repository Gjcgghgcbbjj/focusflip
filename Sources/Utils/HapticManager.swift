import UIKit

/// Wraps UIImpactFeedbackGenerator / UINotificationFeedbackGenerator for haptics.
public final class HapticManager {

    public static let shared = HapticManager()

    private init() {}

    public func light() {
        guard AppSettings.shared.hapticsEnabled else { return }
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.impactOccurred()
    }

    public func medium() {
        guard AppSettings.shared.hapticsEnabled else { return }
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.impactOccurred()
    }

    public func heavy() {
        guard AppSettings.shared.hapticsEnabled else { return }
        let gen = UIImpactFeedbackGenerator(style: .heavy)
        gen.impactOccurred()
    }

    public func success() {
        guard AppSettings.shared.hapticsEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    public func warning() {
        guard AppSettings.shared.hapticsEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    public func selection() {
        guard AppSettings.shared.hapticsEnabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
