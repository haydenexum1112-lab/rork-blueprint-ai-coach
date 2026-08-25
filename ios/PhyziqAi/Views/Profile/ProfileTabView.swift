import SwiftUI
import AuthenticationServices
import UIKit

/// Profile: account, stats, goal photos, training prefs, subscription, and privacy controls.
struct ProfileTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(AuthManager.self) private var auth
    @Environment(HealthKitManager.self) private var healthKit

    @State private var showEditProfile: Bool = false
    @State private var showGoalSetup: Bool = false
    @State private var showDeleteAllConfirm: Bool = false
    @State private var showDeleteAccountConfirm: Bool = false
    @State private var healthSteps: Int?
    @State private var healthWeight: Double?
    @State private var isSyncingHealth: Bool = false
    @State private var showNotificationPrompt: Bool = false

    var body: some View {
        @Bindable var auth = auth

        return NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        accountCard

                        if let profile = appState.profile {
                            headerCard(profile)
                            statsCard(profile)
                            goalCard
                            healthCard
                            notificationsCard
                            trainingPrefsCard
                            subscriptionCard(profile)
                            privacyCard
                        }
                        DisclaimerFooter()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showEditProfile) {
                EditProfileSheet()
            }
            .sheet(isPresented: $showGoalSetup) {
                GoalSetupView()
            }
            .sheet(isPresented: $showNotificationPrompt) {
                NotificationPromptSheet()
            }
            .confirmationDialog(
                "Delete all data?",
                isPresented: $showDeleteAllConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete everything", role: .destructive) {
                    Haptics.warning()
                    appState.deleteAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes your profile, all scans, photos, and progress from this device. This cannot be undone.")
            }
            .confirmationDialog(
                "Delete your account?",
                isPresented: $showDeleteAccountConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete account & data", role: .destructive) {
                    Haptics.warning()
                    appState.deleteAllData()
                    Task { await auth.signOut() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your account, signs you out, and removes all scans, photos, and progress from this device. This cannot be undone.")
            }
            .alert("Sign in error", isPresented: $auth.showError) {
                Button("OK") {}
            } message: {
                Text(auth.errorMessage)
            }
        }
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Theme.accent.opacity(0.14))
                        .frame(width: 54, height: 54)
                    Image(systemName: auth.user == nil ? "person" : "person.fill.checkmark")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Theme.accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(auth.user == nil ? "Account" : "Signed in")
                        .font(.system(size: 12, weight: .black))
                        .tracking(2)
                        .foregroundStyle(Theme.textSecondary)
                    Text(auth.user?.name ?? auth.user?.email ?? "Sign in to sync your progress")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(Theme.textPrimary)
                }

                Spacer()
            }

            if auth.isLoading || auth.isSigningIn {
                HStack {
                    Spacer()
                    SwiftUI.ProgressView()
                        .tint(Theme.accent)
                    Spacer()
                }
                .padding(.vertical, 8)
            } else if auth.user == nil {
                VStack(spacing: 10) {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.email, .fullName]
                    } onCompletion: { _ in
                        Task { await auth.signIn(provider: "apple") }
                    }
                    .frame(height: 50)
                    .clipShape(.rect(cornerRadius: 12))

                    Button {
                        Task { await auth.signIn(provider: "google") }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "globe")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Continue with Google")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Theme.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Theme.hairline, lineWidth: 1)
                                )
                        )
                    }
                    .disabled(auth.isSigningIn)
                }
            } else {
                VStack(spacing: 10) {
                    Button {
                        Task { await auth.signOut() }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.right.square")
                            Text("Sign out")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        showDeleteAccountConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "person.crop.circle.badge.minus")
                            Text("Delete account")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(18)
        .blueprintCard()
    }

    private func headerCard(_ profile: UserProfile) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.14))
                    .frame(width: 62, height: 62)
                Text(String(profile.name.prefix(1)).uppercased())
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(Theme.accent)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name)
                    .font(.system(size: 21, weight: .heavy))
                    .foregroundStyle(Theme.textPrimary)
                Text(appState.subscription.display)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(appState.subscription.isActive ? Theme.accent : Theme.textSecondary)
            }
            Spacer()
            Button {
                Haptics.impact(.light)
                showEditProfile = true
            } label: {
                Text("Edit")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(Theme.accent.opacity(0.12)))
            }
        }
        .padding(18)
        .blueprintCard()
    }

    private func statsCard(_ profile: UserProfile) -> some View {
        VStack(spacing: 0) {
            InfoRow(label: "Age", value: "\(profile.age)")
            Divider().overlay(Theme.hairline)
            InfoRow(label: "Height", value: profile.heightDisplay)
            Divider().overlay(Theme.hairline)
            InfoRow(label: "Weight", value: profile.weightDisplay)
            Divider().overlay(Theme.hairline)
            InfoRow(label: "Experience", value: profile.experience.display)
            Divider().overlay(Theme.hairline)
            InfoRow(label: "Training days", value: "\(profile.daysPerWeek) / week")
            Divider().overlay(Theme.hairline)
            InfoRow(label: "Equipment", value: profile.equipment.display)
        }
        .blueprintCard()
    }

    private var goalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "Goal physique", icon: "scope")
                Spacer()
                Button {
                    Haptics.impact(.light)
                    showGoalSetup = true
                } label: {
                    Text(appState.target == nil ? "Add" : "Edit")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.accent)
                }
            }
            if let target = appState.target {
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(target.images) { reference in
                            Theme.surfaceHi
                                .frame(width: 90, height: 120)
                                .overlay {
                                    if let data = ImageStore.loadData(reference.fileName),
                                       let image = UIImage(data: data) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .allowsHitTesting(false)
                                    }
                                }
                                .clipShape(.rect(cornerRadius: 12))
                        }
                    }
                }
                .scrollIndicators(.hidden)
            } else {
                Text("No goal photos yet.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(18)
        .blueprintCard()
    }

    private func subscriptionCard(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Subscription", icon: "crown.fill")
            Text(appState.subscription.display)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(appState.subscription.isActive ? Theme.accent : Theme.textSecondary)

            if appState.subscription.isActive {
                Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                    Label("Manage subscription", systemImage: "arrow.up.right.square")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.danger)
                }
            } else {
                Button {
                    Haptics.impact()
                    appState.showPaywall = true
                } label: {
                    Text("Choose your plan")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Theme.accent))
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .blueprintCard()
    }

    // MARK: - Notifications card

    private var notificationsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.accent)
                SectionHeader(title: "Notifications", icon: "")
                Spacer()
                if let prefs = appState.notificationPrefs, prefs.hasAuthorized {
                    Label("On", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.success)
                }
            }

            if let prefs = appState.notificationPrefs, prefs.hasAuthorized {
                // Show individual toggles
                VStack(spacing: 0) {
                    ForEach(NotificationToggleType.allCases) { type in
                        NotificationToggleRow(type: type)
                        if type != NotificationToggleType.allCases.last {
                            Divider().overlay(Theme.hairline)
                        }
                    }
                }
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.bg))
                .padding(.top, 2)

                Button {
                    Haptics.warning()
                    appState.disableNotifications()
                } label: {
                    Label("Turn off all notifications", systemImage: "bell.slash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }
            } else if appState.notificationPrefs != nil && appState.notificationPrefs?.hasAuthorized == false {
                // User skipped — show re-enable button
                Text("You skipped notification setup. Enable them to get streak reminders, workout alerts, and PR celebrations.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .lineSpacing(3)

                Button {
                    Haptics.impact(.light)
                    showNotificationPrompt = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 15))
                        Text("Enable notifications")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.accent))
                }
            } else {
                // Never seen — show enable button
                Text("Get timely reminders for workouts, meal logging, streaks, and personal records.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .lineSpacing(3)

                Button {
                    Haptics.impact(.light)
                    showNotificationPrompt = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 15))
                        Text("Set up notifications")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.accent))
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .blueprintCard()
    }

    // MARK: - Training preferences card

    private var trainingPrefsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Training preferences", icon: "dumbbell.fill")

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Rest timer")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Count down rest between sets with a chime at the end.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
                Toggle("", isOn: Binding<Bool>(
                    get: { appState.restTimerPreference == true },
                    set: { newValue in
                        Haptics.impact(.light)
                        appState.setRestTimerPreference(newValue)
                    }
                ))
                .labelsHidden()
                .tint(Theme.accent)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .blueprintCard()
    }

    // MARK: - Apple Health card

    private var healthCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color(red: 244/255, green: 63/255, blue: 94/255))
                SectionHeader(title: "Apple Health", icon: "")
                Spacer()
                if healthKit.isAuthorized {
                    Label("Connected", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.success)
                }
            }

            Text("Sync your body weight, workouts, and step count from Apple Health, and share your logged meals back to the Health app.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(3)

            if !healthKit.isAvailable {
                let isPad = UIDevice.current.userInterfaceIdiom == .pad
                Text(isPad
                     ? "Apple Health isn't available on iPad in this version of PhyziqAi. Connect on iPhone to sync health data."
                     : "Apple Health isn't available on this device.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.warning)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else if healthKit.isAuthorized {
                // Live data preview
                VStack(spacing: 0) {
                    if isSyncingHealth {
                        HStack(spacing: 10) {
                            ProgressView().tint(Theme.accent).scaleEffect(0.8)
                            Text("Syncing from Apple Health…")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.textSecondary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    } else if let steps = healthSteps {
                        InfoRow(label: "Today's steps", value: "\(steps.formatted())")
                        Divider().overlay(Theme.hairline)
                        if let weight = healthWeight {
                            InfoRow(label: "Latest weight", value: profileWeightDisplay(weight))
                            Divider().overlay(Theme.hairline)
                        }
                        InfoRow(label: "Workouts & energy", value: "Auto-synced")
                    } else {
                        InfoRow(label: "Today's steps", value: "—")
                        Divider().overlay(Theme.hairline)
                        InfoRow(label: "Latest weight", value: "—")
                    }
                }
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.bg))
                .padding(.top, 2)

                HStack(spacing: 10) {
                    Button {
                        Haptics.impact(.light)
                        Task { await syncHealthData() }
                    } label: {
                        Label("Sync now", systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.accent))
                    }
                    .disabled(isSyncingHealth)
                    .opacity(isSyncingHealth ? 0.5 : 1)

                    Button {
                        Haptics.warning()
                        healthKit.disconnect()
                        healthSteps = nil
                        healthWeight = nil
                    } label: {
                        Label("Disconnect", systemImage: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Theme.surface)
                                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.hairline, lineWidth: 1))
                            )
                    }
                }
                .padding(.top, 4)
            } else {
                Button {
                    Haptics.impact(.light)
                    Task {
                        await healthKit.requestAuthorization()
                        if healthKit.isAuthorized {
                            await syncHealthData()
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 16))
                        Text("Connect to Apple Health")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(red: 244/255, green: 63/255, blue: 94/255))
                    )
                }
                .disabled(healthKit.isRequesting)
                .opacity(healthKit.isRequesting ? 0.6 : 1)

                if let error = healthKit.lastError {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.warning)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 2)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .blueprintCard()
        .task {
            if healthKit.isAuthorized {
                await syncHealthData()
            }
        }
    }

    /// Pulls weight + steps from Health and updates profile weight if needed.
    private func syncHealthData() async {
        isSyncingHealth = true
        defer { isSyncingHealth = false }
        do {
            let steps = try await healthKit.fetchSteps(on: Date())
            healthSteps = steps
        } catch {
            healthSteps = nil
        }
        do {
            let weight = try await healthKit.fetchLatestBodyMass()
            healthWeight = weight
            // Update profile weight silently
            if let weight, var profile = appState.profile,
               abs(profile.weightKg - weight) > 0.05 {
                profile.weightKg = weight
                appState.saveProfile(profile)
            }
        } catch {
            healthWeight = nil
        }
    }

    private func profileWeightDisplay(_ kg: Double) -> String {
        guard let profile = appState.profile else { return "\(Int(kg.rounded())) kg" }
        if profile.usesMetric {
            return "\(Int(kg.rounded())) kg"
        }
        return "\(Int((kg * 2.20462).rounded())) lb"
    }

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Privacy & data", icon: "lock.shield.fill")

            Text("Your photos and analysis stay on this device. Images are sent once, securely, only at the moment of analysis — never stored on a server.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(3)

            cloudBackupSection

            Divider().overlay(Theme.hairline)

            ShareLink(item: appState.exportDataJSON()) {
                Label("Export my data", systemImage: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }

            Button {
                showDeleteAllConfirm = true
            } label: {
                Label("Delete all my data", systemImage: "trash.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.danger)
            }

            HStack(spacing: 20) {
                Link("Terms of Use", destination: URL(string: "https://65qn5mmc0o8br1jaq624d-web.rork.live/terms")!)
                Link("Privacy Policy", destination: URL(string: "https://65qn5mmc0o8br1jaq624d-web.rork.live/privacy")!)
                Link("Privacy Choices", destination: URL(string: "https://65qn5mmc0o8br1jaq624d-web.rork.live/privacy-choices")!)
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Theme.textSecondary.opacity(0.7))
            .padding(.top, 4)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .blueprintCard()
    }

    // MARK: - Cloud backup

    @State private var cloudBackup = CloudBackupService.shared
    @State private var showDeleteCloudConfirm: Bool = false
    @State private var cloudStatusMessage: String?

    private var cloudBackupSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("iCloud backup")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Encrypted scan analyses stored in your iCloud. Photos stay on-device only.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Toggle("", isOn: Binding<Bool>(
                    get: { appState.meta.cloudBackupEnabled },
                    set: { newValue in
                        Haptics.impact(.light)
                        appState.meta.cloudBackupEnabled = newValue
                        appState.persistMeta()
                    }
                ))
                .labelsHidden()
                .tint(Theme.accent)
            }

            if appState.meta.cloudBackupEnabled {
                if let backupDate = appState.meta.cloudBackupDate {
                    Text("Last backed up: \(backupDate.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }

                if cloudBackup.isBackingUp {
                    HStack(spacing: 8) {
                        ProgressView().tint(Theme.accent).scaleEffect(0.7)
                        Text("Backing up…")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                    }
                } else if cloudBackup.isRestoring {
                    HStack(spacing: 8) {
                        ProgressView().tint(Theme.accent).scaleEffect(0.7)
                        Text("Restoring…")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        Haptics.impact(.light)
                        Task {
                            let ok = await cloudBackup.backup(scans: appState.scans)
                            if ok {
                                appState.meta.cloudBackupDate = Date()
                                appState.persistMeta()
                                cloudStatusMessage = "Backup complete."
                            } else {
                                cloudStatusMessage = cloudBackup.lastError ?? "Backup failed."
                            }
                        }
                    } label: {
                        Label("Back up now", systemImage: "arrow.up.icloud")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.accent))
                    }

                    Button {
                        Haptics.impact(.light)
                        Task {
                            if let restored = await cloudBackup.restore() {
                                for scan in restored where !appState.scans.contains { $0.id == scan.id } {
                                    appState.scans.append(scan)
                                }
                                appState.persistScans()
                                cloudStatusMessage = "Restored \(restored.count) scans."
                            } else {
                                cloudStatusMessage = cloudBackup.lastError ?? "No backup found."
                            }
                        }
                    } label: {
                        Label("Restore", systemImage: "arrow.down.icloud")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Theme.surface)
                                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.hairline, lineWidth: 1))
                            )
                    }
                }

                Button {
                    showDeleteCloudConfirm = true
                } label: {
                    Label("Delete cloud backup", systemImage: "icloud.slash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.danger)
                }

                if let msg = cloudStatusMessage {
                    Text(msg)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.top, 2)
                }
            }
        }
        .confirmationDialog(
            "Delete cloud backup?",
            isPresented: $showDeleteCloudConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete backup", role: .destructive) {
                Haptics.warning()
                cloudBackup.deleteBackup()
                appState.meta.cloudBackupDate = nil
                appState.persistMeta()
                cloudStatusMessage = "Cloud backup deleted."
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes your encrypted scan metadata from iCloud. Your on-device data is not affected.")
        }
    }
}

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
    }
}
