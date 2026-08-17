import SwiftUI

// MARK: - iOS 15 compatibility helpers
//
// These extensions provide safe fallbacks for APIs introduced after iOS 15,
// so the app compiles on the iPhoneOS15.6 SDK and runs on iOS 15+.

extension View {
    /// Applies `.contentTransition(.numericText())` on iOS 16+,
    /// no-ops on iOS 15.
    @ViewBuilder
    func numericTextTransition() -> some View {
        if #available(iOS 16.0, *) {
            self.contentTransition(.numericText())
        } else {
            self
        }
    }

    /// Hides scroll view background on iOS 16+, no-ops on iOS 15.
    @ViewBuilder
    func hideScrollBackground() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}
