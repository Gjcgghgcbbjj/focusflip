import WidgetKit
import SwiftUI

/// Widget bundle entry point — the real @main of the Widget Extension target.
/// The extension binary is embedded in the app (PlugIns/FocusFlipWidgetExtension.appex)
/// and installed/signed by TrollStore together with the main app.
@main
struct FocusFlipWidgetBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 16.0, *) {
            FocusFlipWidget()
        }
        if #available(iOS 16.2, *) {
            PomodoroLiveActivity()
        }
    }
}
