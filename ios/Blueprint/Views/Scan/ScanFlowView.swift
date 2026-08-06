import SwiftUI

/// Full-screen scan journey: method choice → capture → confirm → analyzing → results.
struct ScanFlowView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    enum Stage {
        case intro
        case photoCapture
        case videoPick
        case confirm
        case analyzing
        case healthScreener(Scan)
        case results(Scan)
        case failed(String)
    }

    @State private var stage: Stage = .intro
    @State private var frames: [Data] = []
    @State private var pendingScan: Scan?

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            switch stage {
            case .intro:
                ScanIntroView(
                    onPhoto: { withAnimation { stage = .photoCapture } },
                    onVideo: { withAnimation { stage = .videoPick } },
                    onClose: { dismiss() }
                )
            case .photoCapture:
                CameraCaptureView(
                    onComplete: { captured in
                        frames = captured
                        withAnimation { stage = .confirm }
                    },
                    onBack: { withAnimation { stage = .intro } }
                )
            case .videoPick:
                VideoPickView(
                    onComplete: { captured in
                        frames = captured
                        withAnimation { stage = .confirm }
                    },
                    onBack: { withAnimation { stage = .intro } }
                )
            case .confirm:
                ConfirmFramesView(
                    frames: frames,
                    onRetake: {
                        frames = []
                        withAnimation { stage = .intro }
                    },
                    onAnalyze: {
                        withAnimation { stage = .analyzing }
                        runAnalysis()
                    }
                )
            case .analyzing:
                AnalyzingView()
            case .healthScreener(let scan):
                HealthScreenerView { _ in
                    withAnimation { stage = .results(scan) }
                }
            case .results(let scan):
                ResultsView(scan: scan, isPostScan: true) {
                    finishFlow()
                }
            case .failed(let message):
                ScanErrorView(
                    message: message,
                    onRetry: {
                        withAnimation { stage = .confirm }
                    },
                    onClose: { dismiss() }
                )
            }
        }
        
        .interactiveDismissDisabled(isAnalyzing)
    }

    private var isAnalyzing: Bool {
        if case .analyzing = stage { return true }
        return false
    }

    private func finishFlow() {
        let shouldShowPaywall = !appState.subscription.isActive && !appState.meta.hasSeenPaywall
        dismiss()
        if shouldShowPaywall {
            appState.markPaywallSeen()
            Task {
                try? await Task.sleep(for: .milliseconds(450))
                appState.showPaywall = true
            }
        }
    }

    private func runAnalysis() {
        let capturedFrames = frames
        var targets: [(data: Data, caption: String)] = []
        if let goal = appState.target {
            for reference in goal.images {
                if let data = ImageStore.loadData(reference.fileName) {
                    targets.append((data, reference.caption))
                }
            }
        }
        let context = buildProfileContext()

        Task {
            do {
                let input = AnalysisInput(profileContext: context, frames: capturedFrames, targets: targets)
                let (result, rawJSON) = try await AIService.analyze(input)

                var fileNames: [String] = []
                for frame in capturedFrames {
                    let stored = ImageResizer.resize(frame, maxBytes: 900_000) ?? frame
                    if let name = ImageStore.save(stored) {
                        fileNames.append(name)
                    }
                }

                let scan = Scan(date: Date(), frameFileNames: fileNames, analysis: result, rawJSON: rawJSON)
                appState.addScan(scan)
                Haptics.success()
                if appState.meta.parqPassed == nil {
                    withAnimation { stage = .healthScreener(scan) }
                } else {
                    withAnimation { stage = .results(scan) }
                }
            } catch {
                Haptics.warning()
                withAnimation { stage = .failed(error.localizedDescription) }
            }
        }
    }

    private func buildProfileContext() -> String {
        guard let profile = appState.profile else { return "{}" }
        let goals = profile.goalTags.map { $0.display }.joined(separator: ", ")
        let captions = appState.target?.images
            .map { $0.caption }
            .filter { !$0.isEmpty }
            .joined(separator: " | ") ?? ""
        return """
        {
          "age": \(profile.age),
          "sex": "\(profile.sex.rawValue)",
          "heightCm": \(Int(profile.heightCm)),
          "weightKg": \(Int(profile.weightKg)),
          "experience": "\(profile.experience.rawValue)",
          "trainingDaysPerWeek": \(profile.daysPerWeek),
          "equipment": "\(profile.equipment.display)",
          "goals": "\(goals)",
          "goalPhotoNotes": "\(captions)"
        }
        """
    }
}

// MARK: - Intro

private struct ScanIntroView: View {
    let onPhoto: () -> Void
    let onVideo: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Theme.surface))
                }
                Spacer()
            }
            .padding(.horizontal, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Physique Scan")
                            .font(.displayFont(34))
                            .foregroundStyle(Theme.textPrimary)
                        Text("Three angles — front, side, back. Your photos never leave your phone except for the moment of analysis.")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.textSecondary)
                            .lineSpacing(3)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("FOR BEST RESULTS")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(Theme.accent)
                        TipRow(icon: "lightbulb.max.fill", text: "Bright, even lighting — face a window")
                        TipRow(icon: "tshirt.fill", text: "Fitted clothing or training gear")
                        TipRow(icon: "rectangle.portrait", text: "Plain background, phone at chest height")
                        TipRow(icon: "figure.stand", text: "Stand 2–3 meters from the camera")
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .blueprintCard()

                    VStack(spacing: 12) {
                        ScanMethodCard(
                            icon: "camera.fill",
                            title: "Guided photos",
                            subtitle: "Take 3 photos with pose guides",
                            action: onPhoto
                        )
                        ScanMethodCard(
                            icon: "video.fill",
                            title: "Scan video",
                            subtitle: "Pick a 20–30s slow-turn video — we extract the angles",
                            action: onVideo
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
    }
}

private struct TipRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Theme.accent)
                .frame(width: 24)
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
        }
    }
}

private struct ScanMethodCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.impact()
            action()
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Theme.accent.opacity(0.14))
                        .frame(width: 54, height: 54)
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(16)
            .blueprintCard()
        }
    }
}

// MARK: - Error

private struct ScanErrorView: View {
    let message: String
    let onRetry: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(Theme.warning)
            Text("Analysis failed")
                .font(.displayFont(26))
                .foregroundStyle(Theme.textPrimary)
            Text(message)
                .font(.system(size: 15))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Button("Try again", action: onRetry)
                .buttonStyle(PrimaryButtonStyle())
            Button("Close", action: onClose)
                .buttonStyle(SecondaryButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }
}
