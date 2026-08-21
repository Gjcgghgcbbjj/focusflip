import SwiftUI
import CoreData
import UIKit

@main
struct FocusFlipApp: App {

    @ObservedObject private var engine = PomodoroEngine.shared
    @ObservedObject private var settings = AppSettings.shared
    @StateObject private var router = AppRouter.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Tab bar appearance (dynamic — adapts to light/dark)
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = DS3.UIColorToken.bg
        tabAppearance.shadowColor = .clear
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        UITabBar.appearance().unselectedItemTintColor = DS3.UIColorToken.textDim

        // Nav bar appearance
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = DS3.UIColorToken.bg
        navAppearance.shadowColor = .clear
        navAppearance.titleTextAttributes = [
            .foregroundColor: DS3.UIColorToken.text
        ]
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: DS3.UIColorToken.text
        ]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, PersistenceController.shared.viewContext)
                .environmentObject(router)
                .onAppear {
                    NotificationService.shared.requestPermission()
                }
                .onOpenURL { url in
                    handleURL(url)
                }
                .onChange(of: scenePhase) { phase in
                    if phase == .background {
                        PersistenceController.shared.autoBackupIfNeeded()
                        UIApplication.shared.isIdleTimerDisabled = false
                    }
                }
        }
    }

    // MARK: - URL scheme (focusflip://...)

    private func handleURL(_ url: URL) {
        guard url.scheme == "focusflip" else { return }

        switch url.host ?? "" {
        case "start":
            router.selectedTab = .timer
            engine.startFocus()
            if settings.whiteNoiseEnabled { SoundPlayer.shared.playWhiteNoise() }
        case "pause":
            engine.pause()
        case "resume":
            engine.resume()
        case "skip":
            engine.skip()
        case "reset":
            engine.reset()
            SoundPlayer.shared.stopWhiteNoise()
        case "timer":
            router.selectedTab = .timer
        case "habits":
            router.selectedTab = .habits
        case "tasks":
            router.selectedTab = .tasks
        case "stats":
            router.selectedTab = .stats
        case "settings":
            router.selectedTab = .settings
        default:
            break
        }
    }
}

// MARK: - App router (tab switching from URL schemes / shortcuts)

/// Minimal navigation state shared across the app.
final class AppRouter: ObservableObject {

    static let shared = AppRouter()

    enum Tab: Int {
        case timer
        case tasks
        case habits
        case stats
        case settings
    }

    @Published var selectedTab: Tab = .timer
}

// MARK: - Root tab view

struct ContentView: View {

    @EnvironmentObject private var router: AppRouter
    @ObservedObject private var engine = PomodoroEngine.shared
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        ZStack {
        TabView(selection: $router.selectedTab) {
            TimerView3()
                .tabItem {
                    Label("计时", systemImage: "timer")
                }
                .tag(AppRouter.Tab.timer)

            TasksView3()
                .tabItem {
                    Label("任务", systemImage: "checklist")
                }
                .tag(AppRouter.Tab.tasks)

            HabitsView3()
                .tabItem {
                    Label("习惯", systemImage: "checkmark.seal")
                }
                .tag(AppRouter.Tab.habits)

            StatsView3()
                .tabItem {
                    Label("统计", systemImage: "chart.bar.fill")
                }
                .tag(AppRouter.Tab.stats)

            SettingsView3()
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
                .tag(AppRouter.Tab.settings)
        }
        .tint(DS3.Color.accent)

        if settings.immersiveMode && engine.isRunning {
            ImmersiveFocusView()
        }
        }
        .animation(DS3.Anim.smooth, value: engine.isRunning)
    }
}
