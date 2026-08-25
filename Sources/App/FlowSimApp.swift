import SwiftUI
import UserNotifications

enum AppTab: Hashable {
    case focus, tasks, stats, targets, settings
}

final class AppRouter: ObservableObject {
    static let shared = AppRouter()
    @Published var tab: AppTab = .focus

    func showFocus() { tab = .focus }
}

/// 通知操作按钮响应（点「开始下一阶段」→ 直接开跑）
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        Notifications.registerCategories()
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == Notifications.actionStartNext {
            DispatchQueue.main.async {
                if case .prepared = FocusEngine.shared.state {
                    FocusEngine.shared.startPreparedPhase()
                } else if FocusEngine.shared.state == .idle {
                    FocusEngine.shared.startFocus()
                } else if FocusEngine.shared.isPaused {
                    FocusEngine.shared.resume()
                }
            }
        }
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

@main
struct FlowSimApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var router = AppRouter.shared

    init() {
        // CI 截图巡游逃生门（skill §六）：FF_UI_TOUR=1 时不请求通知权限，
        // 系统弹窗会挡住 openurl 导航与截图主体。真机路径不受影响。
        if ProcessInfo.processInfo.environment["FF_UI_TOUR"] != "1" {
            Notifications.requestOnce()
        }
        // CI 巡游初始 tab：SIMCTL_CHILD_FF_TAB=tasks 等。
        // 实测 iOS 26 模拟器 simctl openurl 对自定义 scheme 不投递 warm URL、
        // 冷启动弹确认框，环境变量是唯一免点按的确定性导航。
        if let t = ProcessInfo.processInfo.environment["FF_TAB"] {
            AppRouter.shared.tab = Self.tourTab(t) ?? .focus
        }
        // CI 巡游演示数据（库为空才种），让截图呈现有数据的真实形态
        if ProcessInfo.processInfo.environment["FF_SEED_DEMO"] == "1" {
            Store.shared.seedDemoIfEmpty()
        }

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = UIColor.systemBackground
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }

    private static func tourTab(_ name: String) -> AppTab? {
        switch name {
        case "focus": return .focus
        case "tasks": return .tasks
        case "stats": return .stats
        case "targets": return .targets
        case "settings": return .settings
        default: return nil
        }
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
            .onAppear {
                // 巡游脚本等这个标记再截图（冷启动首帧就绪，替代盲睡）
                if ProcessInfo.processInfo.environment["FF_UI_TOUR"] == "1" {
                    DispatchQueue.main.async { print("FF_TOUR_READY") }
                }
            }
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
                    // 快捷指令深链。⚠️ iOS 26 模拟器实测 warm openurl 不投递、
                    // 冷启动弹确认框——真机待验证，CI 巡游走 FF_TAB 环境变量。
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
