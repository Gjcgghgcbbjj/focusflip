import SwiftUI
import CoreData
import UIKit

@main
struct FocusFlipApp: App {

    @StateObject private var engine = PomodoroEngine.shared
    @StateObject private var settings = AppSettings.shared

    init() {
        // Tab bar appearance
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(DS.Color.bgPrimary)
        tabAppearance.shadowColor = .clear
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        // Nav bar appearance
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(DS.Color.bgPrimary)
        navAppearance.shadowColor = .clear
        navAppearance.titleTextAttributes = [
            .foregroundColor: UIColor(DS.Color.textPrimary)
        ]
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(DS.Color.textPrimary)
        ]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, PersistenceController.shared.viewContext)
                .environmentObject(engine)
                .environmentObject(settings)
                .onAppear {
                    NotificationService.shared.requestPermission()
                }
        }
    }
}

// MARK: - Root tab view

struct ContentView: View {

    var body: some View {
        TabView {
            TimerView()
                .tabItem {
                    Label("计时", systemImage: "timer")
                }

            TasksView()
                .tabItem {
                    Label("任务", systemImage: "checklist")
                }

            if #available(iOS 16.0, *) {
                StatsView()
                    .tabItem {
                        Label("统计", systemImage: "chart.bar.fill")
                    }
            }

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
        }
        .tint(DS.Color.accent)
    }
}
