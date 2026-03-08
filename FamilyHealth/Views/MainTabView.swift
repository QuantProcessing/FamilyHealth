import SwiftUI

/// Main tab bar with 5 tabs: Home, Records, AI, Family, Settings
struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("首页", systemImage: "house.fill")
                }
                .tag(0)

            RecordsView()
                .tabItem {
                    Label("档案", systemImage: "doc.text.fill")
                }
                .tag(1)

            AIChatListView()
                .tabItem {
                    Label("AI", systemImage: "brain.head.profile")
                }
                .tag(2)

            FamilyListView()
                .tabItem {
                    Label("家庭", systemImage: "person.3.fill")
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
    }
}
