import WidgetKit
import SwiftUI

/// Widget bundle entry point.
/// Required for WidgetKit to discover and register widgets.
@main
struct FocusFlipWidgetBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 16.0, *) {
            FocusFlipWidget()
        }
        if #available(iOS 16.1, *) {
            PomodoroLiveActivity()
        }
    }
}
