//
//  BlueprintApp.swift
//  Blueprint
//
//  Created by Rork on July 21, 2026.
//

import SwiftUI

@main
struct BlueprintApp: App {
    @State private var authManager = AuthManager()
    @State private var healthKit = HealthKitManager()
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authManager)
                .environment(healthKit)
                .preferredColorScheme(.light)
                .task { healthKit.loadConnectionState() }
                .task {
                    // Startup diagnostic: confirm Rork toolkit credentials are bundled.
                    let configured = RuntimeConfig.isToolkitConfigured
                    let source = RuntimeConfig.toolkitURL.isEmpty ? "none" : (Config.allValues["EXPO_PUBLIC_TOOLKIT_URL"]?.isEmpty == false ? "Config.swift" : (Bundle.main.url(forResource: "BundledConfig", withExtension: "plist") != nil ? "BundledConfig.plist" : "Info.plist/fallback"))
                    print("[BlueprintApp] Toolkit configured: \(configured) (source: \(source))")
                }
        }
    }
}

/// Locks the app to portrait orientation so the camera feed stays upright
/// when the phone is propped up for a physique scan.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        .portrait
    }
}
