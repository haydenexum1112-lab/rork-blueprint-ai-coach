import SwiftUI

/// The PhyziqAi tab. Guides the user through goal setup → baseline scan,
/// then becomes the weekly training plan.
struct HomeView: View {
    @Environment(AppState.self) private var appState

    @State private var showGoalSetup: Bool = false
    @State private var showScanFlow: Bool = false
    @State private var showNotificationPrompt: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()

                if appState.target == nil {
                    setupContent
                } else if appState.latestAnalysis == nil {
                    SetupHeroView(
                        stepLabel: "STEP 2 OF 2",
                        icon: "viewfinder",
                        title: "Baseline\nscan.",
                        subtitle: "Three photos — front, side, back. The AI maps where you are today and builds your plan to close the gap.",
                        buttonTitle: "Start my scan"
                    ) {
                        showScanFlow = true
                    }
                } else {
                    PlanView(showScanFlow: $showScanFlow)
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("PHYZIQAI")
                        .font(.system(size: 14, weight: .black))
                        .tracking(4)
                        .foregroundStyle(Theme.accent)
                }
            }
            .sheet(isPresented: $showGoalSetup) {
                GoalSetupView()
            }
            .sheet(isPresented: $showNotificationPrompt) {
                NotificationPromptSheet()
            }
            .fullScreenCover(isPresented: $showScanFlow) {
                ScanFlowView()
            }
            .onAppear {
                appState.ensurePlanMatchesProfile()
            }
            .onChange(of: appState.scans.count) { _, newCount in
                // Prompt for notifications the first time a plan is generated
                if newCount > 0 && appState.latestAnalysis != nil && appState.shouldPromptForNotifications {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showNotificationPrompt = true
                    }
                }
            }
        }
    }

    private var setupContent: some View {
        ZStack {
            PhyziqAiGridBackground().ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                Spacer()

                Text("STEP 1 OF 2")
                    .font(.system(size: 12, weight: .black))
                    .tracking(4)
                    .foregroundStyle(Theme.accent)

                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Theme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .strokeBorder(Theme.accent.opacity(0.35), lineWidth: 1)
                        )
                        .frame(width: 84, height: 84)
                    Image(systemName: "scope")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }
                .shadow(color: Theme.accent.opacity(0.2), radius: 24)

                Text("Set your\ntarget.")
                    .font(.displayFont(42))
                    .foregroundStyle(Theme.textPrimary)
                    .lineSpacing(2)

                Text("Upload 1–3 photos of the physique you're working toward. That's what we'll measure you against.")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.textSecondary)
                    .lineSpacing(4)

                Spacer()

                Button("Set my goal") {
                    Haptics.impact()
                    showGoalSetup = true
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }
}

private struct SetupHeroView: View {
    let stepLabel: String
    let icon: String
    let title: String
    let subtitle: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        ZStack {
            PhyziqAiGridBackground().ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                Spacer()

                Text(stepLabel)
                    .font(.system(size: 12, weight: .black))
                    .tracking(4)
                    .foregroundStyle(Theme.accent)

                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Theme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .strokeBorder(Theme.accent.opacity(0.35), lineWidth: 1)
                        )
                        .frame(width: 84, height: 84)
                    Image(systemName: icon)
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }
                .shadow(color: Theme.accent.opacity(0.2), radius: 24)

                Text(title)
                    .font(.displayFont(42))
                    .foregroundStyle(Theme.textPrimary)
                    .lineSpacing(2)

                Text(subtitle)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.textSecondary)
                    .lineSpacing(4)

                Spacer()

                Button(buttonTitle) {
                    Haptics.impact()
                    action()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }
}
