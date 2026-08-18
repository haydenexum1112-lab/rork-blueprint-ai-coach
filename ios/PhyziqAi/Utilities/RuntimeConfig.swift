import Foundation

/// Runtime config reader that pulls public environment variables from:
/// 1. A bundled `BundledConfig.plist` generated at build time by a shell script phase
/// 2. The app's Info.plist (injected via INFOPLIST_KEY_* build settings)
/// 3. The process environment (for local builds/previews)
///
/// This is a workaround for the auto-generated Config.swift not reliably
/// receiving values in the Rork iOS build pipeline.
enum RuntimeConfig {
    private static var bundledConfig: [String: String] = {
        guard let url = Bundle.main.url(forResource: "BundledConfig", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String]
        else { return [:] }
        return plist
    }()

    private static func string(_ key: String) -> String {
        // 1. Bundled config plist (generated fresh from env vars at build time)
        if let value = bundledConfig[key], !value.isEmpty {
            return value
        }
        // 2. Rork-generated Config.swift (fallback if plist is not generated)
        if let value = Config.allValues[key], !value.isEmpty {
            return value
        }
        // 3. Info.plist (injected by build settings)
        if let value = Bundle.main.infoDictionary?[key] as? String, !value.isEmpty {
            return value
        }
        // 4. Info.plist keys may also be written with the INFOPLIST_KEY_ prefix in some CI setups
        if let value = Bundle.main.infoDictionary?["INFOPLIST_KEY_" + key] as? String, !value.isEmpty {
            return value
        }
        // 5. Process environment (for local builds/previews)
        if let value = ProcessInfo.processInfo.environment[key], !value.isEmpty {
            return value
        }
        return ""
    }

    static var projectID: String { string("EXPO_PUBLIC_PROJECT_ID") }
    static var rorkAPIBaseURL: String { string("EXPO_PUBLIC_RORK_API_BASE_URL") }
    static var rorkAppKey: String { string("EXPO_PUBLIC_RORK_APP_KEY") }
    static var rorkAuthURL: String { string("EXPO_PUBLIC_RORK_AUTH_URL") }
    static var rorkFunctionsURL: String { string("EXPO_PUBLIC_RORK_FUNCTIONS_URL") }
    static var rorkToolkitSecretKey: String { string("EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY") }
    static var teamID: String { string("EXPO_PUBLIC_TEAM_ID") }
    static var toolkitURL: String { string("EXPO_PUBLIC_TOOLKIT_URL") }

    /// True when the AI toolkit has the URL and secret it needs.
    static var isToolkitConfigured: Bool {
        !toolkitURL.isEmpty && !rorkToolkitSecretKey.isEmpty
    }
}
