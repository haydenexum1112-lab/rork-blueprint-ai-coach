import SwiftUI

/// Review the three captured frames before sending them for analysis.
/// Validates each frame with Vision before allowing analysis to proceed.
struct ConfirmFramesView: View {
    let frames: [Data]
    let onRetake: () -> Void
    let onAnalyze: () -> Void

    @State private var validationResults: [Int: PhotoValidator.RejectionReason] = [:]
    @State private var isValidating: Bool = false
    @State private var hasValidated: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Confirm your scan")
                            .font(.displayFont(30))
                            .foregroundStyle(Theme.textPrimary)
                        Text("Make sure your full body is visible in each frame — head to toe.")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.textSecondary)
                            .lineSpacing(2)
                    }
                    .padding(.top, 20)

                    HStack(spacing: 10) {
                        ForEach(Array(frames.enumerated()), id: \.offset) { index, data in
                            VStack(spacing: 8) {
                                ZStack(alignment: .topTrailing) {
                                    Theme.surfaceHi
                                        .frame(height: 190)
                                        .overlay {
                                            if let image = UIImage(data: data) {
                                                Image(uiImage: image)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .allowsHitTesting(false)
                                            }
                                        }
                                        .clipShape(.rect(cornerRadius: 14))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .strokeBorder(borderColor(for: index), lineWidth: hasValidated ? 2 : 1)
                                        )

                                    if hasValidated {
                                        statusBadge(for: index)
                                            .padding(8)
                                    }
                                }

                                VStack(spacing: 4) {
                                    Text(ScanPose.allCases[min(index, 2)].display.uppercased())
                                        .font(.system(size: 10, weight: .bold))
                                        .tracking(1.5)
                                        .foregroundStyle(Theme.textSecondary)
                                    if let reason = validationResults[index] {
                                        Text(reason.rawValue)
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(Theme.warning)
                                            .multilineTextAlignment(.center)
                                            .lineSpacing(1)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }

                    if hasHardBlocks {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.warning)
                                Text("Some frames need to be retaken")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Theme.warning)
                            }
                            Text("A close-up selfie was detected. Step back so your full body is visible from head to toe.")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textSecondary)
                                .lineSpacing(2)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Theme.warning.opacity(0.12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Theme.warning.opacity(0.3), lineWidth: 1)
                                )
                        )
                    } else if hasSoftWarnings && hasValidated {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.accent)
                                Text("Photos look good to analyze")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Theme.textPrimary)
                            }
                            Text("For best results, stand 2–3 meters back with bright lighting and a plain background. You can retake or continue below.")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textSecondary)
                                .lineSpacing(2)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .blueprintCard()
                    }

                    HStack(spacing: 10) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.accent)
                        Text("Photos are stored only on your device. They're sent once, securely, for this analysis.")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .blueprintCard()
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)

            VStack(spacing: 10) {
                if isValidating {
                    HStack(spacing: 8) {
                        SwiftUI.ProgressView()
                            .tint(Theme.accent)
                        Text("Checking photos…")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                } else {
                    if allFramesValid {
                        Button(hasSoftWarnings ? "Analyze anyway" : "Analyze my physique") {
                            Haptics.impact()
                            onAnalyze()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .opacity(hasValidated ? 1 : 0.5)
                        .disabled(!hasValidated)

                        Button("Retake") {
                            Haptics.impact(.light)
                            onRetake()
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    } else {
                        Button("Retake photos") {
                            Haptics.impact()
                            onRetake()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!hasValidated)
                        .opacity(hasValidated ? 1 : 0.5)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .task {
            await runValidation()
        }
    }

    private var allFramesValid: Bool {
        hasValidated && !hasHardBlocks
    }

    private var hasHardBlocks: Bool {
        validationResults.values.contains { $0.isHardBlock }
    }

    private var hasSoftWarnings: Bool {
        validationResults.values.contains { !$0.isHardBlock }
    }

    private func borderColor(for index: Int) -> Color {
        if !hasValidated { return Theme.hairline }
        return validationResults[index] == nil ? Theme.success.opacity(0.5) : Theme.warning
    }

    @ViewBuilder
    private func statusBadge(for index: Int) -> some View {
        if validationResults[index] == nil {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.success)
                .shadow(color: .black.opacity(0.2), radius: 3)
        } else {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.warning)
                .shadow(color: .black.opacity(0.2), radius: 3)
        }
    }

    private func runValidation() async {
        isValidating = true
        hasValidated = false
        validationResults = [:]
        let (_, failures) = await PhotoValidator.validateAll(frames)
        validationResults = failures
        hasValidated = true
        isValidating = false
        if !failures.isEmpty {
            Haptics.warning()
        }
    }
}
