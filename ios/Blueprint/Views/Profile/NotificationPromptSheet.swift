import SwiftUI

/// One-time opt-in sheet shown when the user has never set up notifications.
/// Explains each notification type and lets the user toggle which ones they want.
struct NotificationPromptSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var isRequesting: Bool = false
    @State private var denied: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Hero
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Theme.accent.opacity(0.12))
                                .frame(width: 72, height: 72)
                            Image(systemName: "bell.badge.fill")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(Theme.accent)
                        }
                        Text("Stay on track")
                            .font(.displayFont(24))
                            .foregroundStyle(Theme.textPrimary)
                        Text("Blueprint can nudge you at the right moments to keep your training, nutrition, and progress on autopilot. Pick the ones you want.")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                    if denied {
                        deniedBanner
                    }

                    // Default toggles preview
                    VStack(alignment: .leading, spacing: 0) {
                        Text("WHAT YOU'LL GET")
                            .font(.system(size: 11, weight: .black))
                            .tracking(2)
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.bottom, 12)

                        ForEach(NotificationToggleType.allCases) { type in
                            NotificationToggleRow(type: type)
                        }
                    }

                    // Enable button
                    Button {
                        Haptics.impact(.medium)
                        Task { await requestPermission() }
                    } label: {
                        HStack(spacing: 8) {
                            if isRequesting {
                                ProgressView()
                                    .tint(Color.black)
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "bell.fill")
                                    .font(.system(size: 16))
                            }
                            Text(isRequesting ? "Asking permission…" : "Enable notifications")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.accent))
                    }
                    .disabled(isRequesting)
                    .opacity(isRequesting ? 0.6 : 1)

                    // Skip
                    Button {
                        Haptics.impact(.light)
                        // Mark as seen but not authorized — user can enable later from Profile
                        var prefs = appState.notificationPrefs ?? NotificationPrefs()
                        prefs.hasAuthorized = false
                        appState.meta.notificationPrefs = prefs
                        // Persist directly since setNotificationPrefs would reschedule
                        appState.persistMeta()
                        dismiss()
                    } label: {
                        Text("Maybe later")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(Theme.bg.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Theme.textSecondary.opacity(0.5))
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var deniedBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundStyle(Theme.warning)
            VStack(alignment: .leading, spacing: 2) {
                Text("Notifications are off")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Enable them in Settings to receive alerts.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Link("Settings", destination: URL(string: UIApplication.openSettingsURLString)!)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.accent)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.warning.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.warning.opacity(0.2), lineWidth: 1))
    }

    private func requestPermission() async {
        isRequesting = true
        defer { isRequesting = false }

        let granted = await NotificationService.shared.requestAuthorization()
        if granted {
            appState.enableNotifications()
            Haptics.success()
            dismiss()
        } else {
            denied = true
            Haptics.warning()
        }
    }
}

/// A single toggle row in the notification setup / preferences card.
struct NotificationToggleRow: View {
    @Environment(AppState.self) private var appState

    let type: NotificationToggleType

    private var isEnabled: Bool {
        guard let prefs = appState.notificationPrefs else { return true }
        switch type {
        case .streakProtection: return prefs.streakProtection
        case .workoutReminder: return prefs.workoutReminder
        case .rescanReminder: return prefs.rescanReminder
        case .mealLogging: return prefs.mealLogging
        case .recoveryReady: return prefs.recoveryReady
        case .weeklySummary: return prefs.weeklySummary
        case .inactivityNudge: return prefs.inactivityNudge
        case .newPR: return prefs.newPR
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Theme.accent.opacity(0.08))
                    .frame(width: 38, height: 38)
                Image(systemName: type.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(type.label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(type.description)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
            Toggle("", isOn: Binding<Bool>(
                get: { isEnabled },
                set: { newValue in
                    Haptics.impact(.light)
                    if appState.notificationPrefs == nil {
                        // Initialize with defaults if not yet set
                        var prefs = NotificationPrefs()
                        // Apply the user's toggle
                        switch type {
                        case .streakProtection: prefs.streakProtection = newValue
                        case .workoutReminder: prefs.workoutReminder = newValue
                        case .rescanReminder: prefs.rescanReminder = newValue
                        case .mealLogging: prefs.mealLogging = newValue
                        case .recoveryReady: prefs.recoveryReady = newValue
                        case .weeklySummary: prefs.weeklySummary = newValue
                        case .inactivityNudge: prefs.inactivityNudge = newValue
                        case .newPR: prefs.newPR = newValue
                        }
                        appState.meta.notificationPrefs = prefs
                        appState.persistMeta()
                    } else {
                        appState.setNotificationToggle(type, enabled: newValue)
                    }
                }
            ))
            .labelsHidden()
            .tint(Theme.accent)
        }
        .padding(.vertical, 10)
    }
}
