import SwiftUI
import CoreData
import UIKit

@main
struct FocusFlipApp: App {

    @ObservedObject private var engine = PomodoroEngine.shared
    @ObservedObject private var settings = AppSettings.shared
    @StateObject private var router = AppRouter.shared

    init() {
        // Tab bar appearance (dynamic — adapts to light/dark)
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = DS.UIColorToken.bgPrimary
        tabAppearance.shadowColor = .clear
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        // Nav bar appearance
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = DS.UIColorToken.bgPrimary
        navAppearance.shadowColor = .clear
        navAppearance.titleTextAttributes = [
            .foregroundColor: DS.UIColorToken.textPrimary
        ]
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: DS.UIColorToken.textPrimary
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
        case stats
        case settings
    }

    @Published var selectedTab: Tab = .timer
}

// MARK: - Root tab view

struct ContentView: View {

    @EnvironmentObject private var router: AppRouter

    var body: some View {
        TabView(selection: $router.selectedTab) {
            TimerView3()
                .tabItem {
                    Label("计时", systemImage: "timer")
                }
                .tag(AppRouter.Tab.timer)

            TasksView()
                .tabItem {
                    Label("任务", systemImage: "checklist")
                }
                .tag(AppRouter.Tab.tasks)

            if #available(iOS 16.0, *) {
                StatsView()
                    .tabItem {
                        Label("统计", systemImage: "chart.bar.fill")
                    }
                    .tag(AppRouter.Tab.stats)
            } else {
                StatsLegacyView()
                    .tabItem {
                        Label("统计", systemImage: "chart.bar.fill")
                    }
                    .tag(AppRouter.Tab.stats)
            }

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
                .tag(AppRouter.Tab.settings)
        }
        .tint(DS.Color.accent)
    }
}
