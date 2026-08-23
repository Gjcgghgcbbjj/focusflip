import SwiftUI

enum AppTab: Hashable {
    case focus, tasks, stats, targets, settings
}

final class AppRouter: ObservableObject {
    static let shared = AppRouter()
    @Published var tab: AppTab = .focus

    func showFocus() { tab = .focus }
}

@main
struct FlowSimApp: App {
    @StateObject private var router = AppRouter.shared

    init() {
        Notifications.requestOnce()

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = UIColor.systemBackground
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }

    var body: some Scene {
        WindowGroup {
            TabView(selection: $router.tab) {
                HomeView()
                    .tabItem { Label("专注", systemImage: "timer") }
                    .tag(AppTab.focus)
                TodoView()
                    .tabItem { Label("任务", systemImage: "checklist") }
                    .tag(AppTab.tasks)
                StatsView()
                    .tabItem { Label("统计", systemImage: "chart.bar") }
                    .tag(AppTab.stats)
                TargetView()
                    .tabItem { Label("目标", systemImage: "flag") }
                    .tag(AppTab.targets)
                SettingsView()
                    .tabItem { Label("设置", systemImage: "gearshape") }
                    .tag(AppTab.settings)
            }
            .tint(DS.accent)
            .overlay(ToastOverlay())
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
