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
        // CI 截图巡游逃生门（skill §六）：FF_UI_TOUR=1 时不请求通知权限，
        // 系统弹窗会挡住 openurl 导航与截图主体。真机路径不受影响。
        if ProcessInfo.processInfo.environment["FF_UI_TOUR"] != "1" {
            Notifications.requestOnce()
        }

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
                case "tab":
                    // focusflip://tab/{focus|tasks|stats|targets|settings}
                    // 供 CI 截图巡游与快捷指令确定性导航，避免坐标点按漂移
                    switch url.pathComponents.last ?? "" {
                    case "focus": router.tab = .focus
                    case "tasks": router.tab = .tasks
                    case "stats": router.tab = .stats
                    case "targets": router.tab = .targets
                    case "settings": router.tab = .settings
                    default: break
                    }
                default: break
                }
            }
        }
    }
}
