import SwiftUI
import AuthenticationServices
import CryptoKit

@Observable
final class AuthManager {
    var user: User?
    var isLoading: Bool = true
    var isSigningIn: Bool = false
    var showError: Bool = false
    var errorMessage: String = ""
    var lastSignInProvider: String?

    private let authURL = RuntimeConfig.rorkAuthURL
    private let appKey = RuntimeConfig.rorkAppKey
    private let projectID = RuntimeConfig.projectID
    private var codeVerifier: String?
    private var webAuthSession: ASWebAuthenticationSession?

    private var developerHint: String? {
        UserDefaults.standard.string(forKey: "RORK_DEVELOPER_HINT")
    }

    struct User: Codable, Identifiable {
        let id: String
        let email: String
        let name: String?
        let picture: String?
    }

    init() {
        Task { await checkAuth() }
    }

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private var authEnv: String {
        #if targetEnvironment(simulator)
        return "simulator"
        #else
        return "native"
        #endif
    }

    private func userFromToken(_ token: String) -> User? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }

        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }

        guard let data = Data(base64Encoded: base64) else { return nil }

        struct JWTPayload: Codable {
            let sub: String
            let email: String?
            let name: String?
            let picture: String?
            let exp: TimeInterval?
        }

        guard let payload = try? JSONDecoder().decode(JWTPayload.self, from: data) else { return nil }
        if let exp = payload.exp, Date(timeIntervalSince1970: exp) < Date() { return nil }

        return User(id: payload.sub, email: payload.email ?? "", name: payload.name, picture: payload.picture)
    }

    private func getRefreshToken() -> String? {
        #if targetEnvironment(simulator)
        if let ud = UserDefaults.standard.string(forKey: "RORK_AUTH_REFRESH_TOKEN") {
            return ud
        }
        #endif
        return KeychainHelper.get("refresh_token")
    }

    @MainActor
    func checkAuth() async {
        defer { isLoading = false }

        if let accessToken = KeychainHelper.get("access_token"),
           let user = userFromToken(accessToken) {
            self.user = user
            return
        }

        if getRefreshToken() != nil {
            await refreshToken()
        }
    }

    @MainActor
    func signIn(provider: String) async {
        isSigningIn = true
        lastSignInProvider = provider
        defer { isSigningIn = false }
        do {
            let verifier = generateCodeVerifier()
            let challenge = generateCodeChallenge(from: verifier)
            codeVerifier = verifier

            guard let url = URL(string: "\(authURL)/oauth/initiate") else {
                setError("Invalid URL")
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            var initiateBody: [String: String] = [
                "app_key": appKey,
                "provider": provider,
                "code_challenge": challenge,
                "target": "swift",
                "env": authEnv,
            ]
            if authEnv == "simulator", let hint = developerHint {
                initiateBody["developer_hint"] = hint
            }
            request.httpBody = try JSONEncoder().encode(initiateBody)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    setError(errorResponse.error)
                } else {
                    setError("Sign in failed (\(statusCode))")
                }
                return
            }
            let initiateResponse = try JSONDecoder().decode(InitiateResponse.self, from: data)

            let code: String
            if initiateResponse.flow == "popup" {
                do {
                    code = try await pollForCode(state: initiateResponse.state)
                } catch AuthError.cancelledByUser {
                    code = try await runWebAuthSession(authURL: initiateResponse.auth_url)
                }
            } else {
                code = try await runWebAuthSession(authURL: initiateResponse.auth_url)
            }

            await exchangeCode(code)
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            // User dismissed the web auth sheet — not an error.
            return
        } catch AuthError.cancelledByUser {
            return
        } catch let error as ASWebAuthenticationSessionError
        where error.code == .presentationContextInvalid || error.code == .presentationContextNotProvided {
            // The sheet couldn't present (no usable window — mainly an iPad
            // scene-timing issue). Show a friendly retry message instead of
            // Apple's raw error.
            setError("We couldn't open the sign-in window. Please try again.")
            print("[Auth] Presentation context error: \(error.code.rawValue)")
        } catch AuthError.presentationUnavailable {
            setError("We couldn't open the sign-in window. Please try again.")
        } catch {
            setError("Sign in failed. Please try again.\n\(error.localizedDescription)")
        }
    }

    private func pollForCode(state: String) async throws -> String {
        guard let url = URL(string: "\(authURL)/oauth/poll-code") else {
            throw AuthError.invalidURL
        }

        let deadline = Date().addingTimeInterval(5 * 60)
        while Date() < deadline {
            try await Task.sleep(for: .seconds(1.5))

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(["app_key": appKey, "state": state])

            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { continue }
            guard let pollResponse = try? JSONDecoder().decode(PollCodeResponse.self, from: data) else { continue }

            if pollResponse.status == "cancelled" {
                throw AuthError.cancelledByUser
            }
            if pollResponse.status == "ready", let code = pollResponse.code {
                return code
            }
        }

        throw AuthError.popupTimeout
    }

    @MainActor
    private func runWebAuthSession(authURL authURLString: String) async throws -> String {
        let callbackScheme = "rork-\(projectID)"

        // On iPad — especially right after launch or during scene transitions —
        // no window may be foreground-active yet. Starting the session without a
        // real, visible window fails with `presentationContextInvalid` (error 3),
        // so we always wait for a valid anchor before starting.
        func waitForAnchor(seconds: Double) async -> Bool {
            let deadline = Date().addingTimeInterval(seconds)
            while Date() < deadline {
                if WebAuthPresentationContext.hasValidAnchor { return true }
                try? await Task.sleep(for: .milliseconds(250))
            }
            return WebAuthPresentationContext.hasValidAnchor
        }

        guard await waitForAnchor(seconds: 5) else {
            throw AuthError.presentationUnavailable
        }

        do {
            return try await startWebAuthSession(url: URL(string: authURLString), callbackScheme: callbackScheme)
        } catch let error as ASWebAuthenticationSessionError
        where error.code == .presentationContextInvalid || error.code == .presentationContextNotProvided {
            // The window went away mid-flight (app backgrounded, scene teardown).
            // Wait for a fresh anchor and retry once before surfacing the
            // friendly retry error.
            guard await waitForAnchor(seconds: 5) else {
                throw AuthError.presentationUnavailable
            }
            return try await startWebAuthSession(url: URL(string: authURLString), callbackScheme: callbackScheme)
        }
    }

    @MainActor
    private func startWebAuthSession(url: URL?, callbackScheme: String) async throws -> String {
        guard let url else { throw AuthError.invalidURL }
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { [weak self] callbackURL, error in
                self?.webAuthSession = nil

                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let url = callbackURL,
                      let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: AuthError.noCode)
                    return
                }

                continuation.resume(returning: code)
            }

            self.webAuthSession = session
            session.presentationContextProvider = WebAuthPresentationContext.shared
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }

    @MainActor
    private func exchangeCode(_ code: String) async {
        guard let verifier = codeVerifier else { return }
        codeVerifier = nil

        guard let url = URL(string: "\(authURL)/oauth/token") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode([
            "app_key": appKey,
            "code": code,
            "code_verifier": verifier,
        ])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    setError(errorResponse.error)
                } else {
                    setError("Sign in failed (\(statusCode))")
                }
                return
            }
            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

            KeychainHelper.set("access_token", value: tokenResponse.access_token)
            KeychainHelper.set("refresh_token", value: tokenResponse.refresh_token)

            user = tokenResponse.user
        } catch {
            setError("Sign in failed: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func refreshToken() async {
        guard let storedRefreshToken = getRefreshToken() else {
            user = nil
            return
        }

        guard let url = URL(string: "\(authURL)/oauth/refresh") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode([
            "app_key": appKey,
            "refresh_token": storedRefreshToken,
        ])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                await signOut()
                return
            }

            let refreshResponse = try JSONDecoder().decode(RefreshResponse.self, from: data)
            KeychainHelper.set("access_token", value: refreshResponse.access_token)
            user = userFromToken(refreshResponse.access_token)
        } catch {
            await signOut()
        }
    }

    @MainActor
    func signOut() async {
        KeychainHelper.delete("access_token")
        KeychainHelper.delete("refresh_token")
        UserDefaults.standard.removeObject(forKey: "RORK_AUTH_REFRESH_TOKEN")
        user = nil
    }

    private func setError(_ message: String) {
        errorMessage = message
        showError = true
    }
}

private struct InitiateResponse: Codable {
    let auth_url: String
    let state: String
    let flow: String?
}

private struct PollCodeResponse: Codable {
    let status: String
    let code: String?
}

private struct TokenResponse: Codable {
    let access_token: String
    let refresh_token: String
    let user: AuthManager.User
}

private struct RefreshResponse: Codable {
    let access_token: String
    let expires_in: Int
}

private struct ErrorResponse: Codable {
    let error: String
}

enum AuthError: LocalizedError {
    case noCode
    case invalidURL
    case serverError(statusCode: Int)
    case popupTimeout
    case cancelledByUser
    case presentationUnavailable

    var errorDescription: String? {
        switch self {
        case .noCode: return "No authorization code received"
        case .invalidURL: return "Invalid URL"
        case .serverError(let code): return "Server error (\(code))"
        case .popupTimeout: return "Sign-in timed out — please try again"
        case .cancelledByUser: return "Sign-in cancelled by user"
        case .presentationUnavailable: return "We couldn't open the sign-in window. Please try again."
        }
    }
}

class WebAuthPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = WebAuthPresentationContext()

    /// True when the app has a window we can legally present from. Starting the
    /// session without one causes `presentationContextInvalid` (error 3), which
    /// is how sign-in was failing during App Review.
    @MainActor
    static var hasValidAnchor: Bool {
        !validWindows.isEmpty
    }

    /// Foreground-active scene windows first (scene's keyWindow preferred), then
    /// foreground-inactive scenes (common right after launch on iPad, where no
    /// scene is active yet but its windows are visible and CAN present), then any
    /// attached scene. Never returns an empty `ASPresentationAnchor()` from a
    /// session start — `runWebAuthSession` refuses to start without a real window.
    @MainActor
    private static var validWindows: [UIWindow] {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }

        // Prefer the scene's keyWindow, then its other visible windows.
        func orderedWindows(of scene: UIWindowScene) -> [UIWindow] {
            var ordered: [UIWindow] = []
            if let key = scene.keyWindow { ordered.append(key) }
            ordered.append(contentsOf: scene.windows.filter { !$0.isHidden && $0 !== scene.keyWindow })
            return ordered
        }

        // 1. Foreground-active scene (normal case).
        let active = scenes
            .filter { $0.activationState == .foregroundActive }
            .flatMap(orderedWindows)
        if let first = active.first { return [first] }

        // 2. Foreground-inactive scene (mid-activation on iPad).
        let inactive = scenes
            .filter { $0.activationState == .foregroundInactive }
            .flatMap(orderedWindows)
        if let first = inactive.first { return [first] }

        // 3. Any attached scene with a visible window (last resort).
        let any = scenes.flatMap(orderedWindows)
        if let first = any.first { return [first] }
        return []
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Sessions are only started after `hasValidAnchor` confirms a live window,
        // and we wait up to 5s for one before starting and on retry — so this
        // never hands back an unusable empty anchor in practice.
        Self.validWindows.first ?? ASPresentationAnchor()
    }
}
