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
                    .tabItem { Label("计时", systemImage: "timer") }
                SettingsView()
                    .tabItem { Label("设置", systemImage: "gearshape") }
            }
            .tint(Color(hex: "#5865F2"))
        }
    }
}
