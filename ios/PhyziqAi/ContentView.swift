import SwiftUI

/// Root router: onboarding until a profile exists, then the main tab experience.
struct ContentView: View {
    @State private var appState = AppState()
    @State private var store = StoreManager()
    @Environment(HealthKitManager.self) private var healthKit

    var body: some View {
        Group {
            if appState.profile == nil {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .environment(appState)
        .environment(store)
        .tint(Theme.accent)
        .onAppear {
            // Connect AppState -> HealthKitManager so food entries can push to Health
            appState.healthKit = healthKit
            // Reschedule notifications on launch to reflect current state
            if let prefs = appState.meta.notificationPrefs, prefs.hasAuthorized {
                NotificationService.shared.rescheduleAll(appState: appState)
            }
        }
        .task {
            // Sync subscription state from StoreKit on launch
            await store.updateEntitlements()
            appState.syncFromStoreKit(store)
        }
    }
}

#Preview {
    ContentView()
}
