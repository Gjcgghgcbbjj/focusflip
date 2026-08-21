import SwiftUI

@main
struct FlowSimApp: App {

    init() {
        Notifications.requestOnce()
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                HomeView()
                    .tabItem { Label("专注", systemImage: "timer") }
                TodoView()
                    .tabItem { Label("任务", systemImage: "checklist") }
                StatsView()
                    .tabItem { Label("统计", systemImage: "chart.bar") }
                SettingsView()
                    .tabItem { Label("设置", systemImage: "gearshape") }
            }
            .tint(Color(hex: "#5865F2"))
            .onOpenURL { url in
                switch url.host ?? "" {
                case "start":
                    if case .prepared = FocusEngine.shared.state {
                        FocusEngine.shared.startPreparedPhase()
                    } else if FocusEngine.shared.state == .idle {
                        FocusEngine.shared.startFocus()
                    } else if FocusEngine.shared.isPaused {
                        FocusEngine.shared.resume()
                    }
                case "pause": FocusEngine.shared.pause()
                case "resume": FocusEngine.shared.resume()
                case "skip": FocusEngine.shared.skip()
                default: break
                }
            }
        }
    }
}
