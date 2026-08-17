import WidgetKit
import SwiftUI

/// Widget bundle entry point.
/// NOTE: This file should be in a separate Widget Extension target.
/// When compiled into the main app target, the @main is conditionally
/// applied via compiler flags. For TrollStore single-binary builds,
/// we do NOT use @main here — the app's @main is in FocusFlipApp.swift.
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
