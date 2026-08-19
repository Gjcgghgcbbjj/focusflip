import UIKit

/// Wraps UIImpactFeedbackGenerator / UINotificationFeedbackGenerator for haptics.
/// Follows Apple's recommendation: prepare() before triggering for low-latency.
public final class HapticManager {

    public static let shared = HapticManager()

    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()
    private let selectionGen = UISelectionFeedbackGenerator()

    private init() {
        // Warm up generators once at launch
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        notification.prepare()
        selectionGen.prepare()
    }

    public func light() {
        guard AppSettings.shared.hapticsEnabled else { return }
        impactLight.impactOccurred()
        impactLight.prepare()
    }

    public func medium() {
        guard AppSettings.shared.hapticsEnabled else { return }
        impactMedium.impactOccurred()
        impactMedium.prepare()
    }

    public func heavy() {
        guard AppSettings.shared.hapticsEnabled else { return }
        impactHeavy.impactOccurred()
        impactHeavy.prepare()
    }

    public func success() {
        guard AppSettings.shared.hapticsEnabled else { return }
        notification.notificationOccurred(.success)
        notification.prepare()
    }

    public func warning() {
        guard AppSettings.shared.hapticsEnabled else { return }
        notification.notificationOccurred(.warning)
        notification.prepare()
    }

    public func selection() {
        guard AppSettings.shared.hapticsEnabled else { return }
        selectionGen.selectionChanged()
        selectionGen.prepare()
    }
}