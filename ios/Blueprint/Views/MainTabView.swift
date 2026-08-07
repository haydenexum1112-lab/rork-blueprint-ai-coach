import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(StoreManager.self) private var store

    var body: some View {
        @Bindable var state = appState
        TabView {
            HomeView()
                .tabItem {
                    Label("PhyziqAi", systemImage: "square.grid.2x2.fill")
                }

            ProgressTabView()
                .tabItem {
                    Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                }

            CalendarTabView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }

            NutritionTabView()
                .tabItem {
                    Label("Nutrition", systemImage: "fork.knife")
                }

            ProfileTabView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle.fill")
                }
        }
        .fullScreenCover(isPresented: $state.showPaywall) {
            PaywallView()
                .environment(appState)
                .environment(store)
        }
    }
}
