import SwiftUI

/// Analysis results: physique score, strengths, gap to goal, and top priorities.
struct ResultsView: View {
    let scan: Scan
    var isPostScan: Bool = false
    var onContinue: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var scoreAnimation: Double = 0

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            if let analysis = scan.analysis {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if let score = analysis.physiqueScore {
                            scoreHeroSection(analysis, score: score)
                            regionBreakdownSection(score)
                        }
                        summarySection(analysis)
                        strengthsSection(analysis)
                        focusSection(analysis)
                        gapSection(analysis)
                        DisclaimerFooter()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, isPostScan ? 24 : 12)
                    .padding(.bottom, 120)
                }
                .scrollIndicators(.hidden)
            } else {
                Text("No analysis available for this scan.")
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isPostScan {
                Button("See my training plan") {
                    Haptics.success()
                    onContinue?()
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Theme.bg.opacity(0.95))
            }
        }
        .overlay(alignment: .topTrailing) {
            if !isPostScan {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Theme.surface))
                }
                .padding(.trailing, 20)
                .padding(.top, 12)
            }
        }
        .onAppear {
            if scan.analysis?.physiqueScore != nil {
                withAnimation(.easeOut(duration: 1.2)) {
                    scoreAnimation = 1
                }
            }
        }
    }

    // MARK: - Score hero

    private func scoreHeroSection(_ analysis: AnalysisResult, score: PhysiqueScore) -> some View {
        VStack(spacing: 18) {
            Text("YOUR PHYSIQUE SCORE")
                .font(.system(size: 12, weight: .black))
                .tracking(4)
                .foregroundStyle(Theme.accent)

            ZStack {
                Circle()
                    .stroke(Theme.surfaceHi, lineWidth: 14)
                    .frame(width: 180, height: 180)

                Circle()
                    .trim(from: 0, to: scoreAnimation * CGFloat(score.overall.value) / 100)
                    .stroke(
                        Theme.accent,
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text("\(score.overall.value)")
                        .font(.system(size: 56, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Text("/ 100")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .accessibilityLabel("Physique score: \(score.overall.value) out of 100")

            HStack(spacing: 8) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 12, weight: .bold))
                Text("Confidence: \(analysis.confidenceLevel.display)")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Theme.accent.opacity(0.12)))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cardRadius)
                        .strokeBorder(Theme.accent.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Region breakdown

    private func regionBreakdownSection(_ score: PhysiqueScore) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "By region", icon: "chart.bar.fill", tint: Theme.accent)
                .accessibilityHeading(.h2)

            VStack(spacing: 12) {
                ForEach(sortedRegions(score.byRegion), id: \.key) { entry in
                    regionBar(name: entry.key.capitalized, value: entry.value.value)
                }
            }
        }
    }

    private func sortedRegions(_ byRegion: [String: FlexInt]) -> [(key: String, value: FlexInt)] {
        let preferred = ["chest", "shoulders", "back", "arms", "legs", "core"]
        return byRegion
            .sorted { a, b in
                let ai = preferred.firstIndex(of: a.key.lowercased()) ?? 99
                let bi = preferred.firstIndex(of: b.key.lowercased()) ?? 99
                if ai != bi { return ai < bi }
                return a.key < b.key
            }
            .map { (key: $0.key, value: $0.value) }
    }

    private func regionBar(name: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(value)")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Theme.surfaceHi)
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(barColor(value))
                        .frame(width: geo.size.width * CGFloat(value) / 100, height: 8)
                }
            }
            .frame(height: 8)
        }
    }

    private func barColor(_ value: Int) -> Color {
        if value >= 75 { return Theme.accent }
        if value >= 50 { return Theme.accent.opacity(0.7) }
        return Theme.warning
    }

    // MARK: - Summary

    private func summarySection(_ analysis: AnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(analysis.summary)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineSpacing(5)
                .accessibilityHeading(.h1)

            Text(scan.date.formatted(date: .long, time: .omitted))
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)

            Text("This is an AI-generated estimate for motivation and tracking — not a clinical or medical assessment.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary.opacity(0.8))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .blueprintCard()
    }

    // MARK: - Strengths

    private func strengthsSection(_ analysis: AnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "What you're achieving", icon: "trophy.fill", tint: Theme.success)
                .accessibilityHeading(.h2)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(analysis.assessment.strengths, id: \.self) { strength in
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Theme.success.opacity(0.14))
                                .frame(width: 32, height: 32)
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .black))
                                .foregroundStyle(Theme.success)
                        }
                        Text(strength)
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.textPrimary)
                            .lineSpacing(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Theme.success.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(Theme.success.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
            }
        }
    }

    // MARK: - Focus areas

    private func focusSection(_ analysis: AnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Where to focus next", icon: "scope", tint: Theme.warning)
                .accessibilityHeading(.h2)

            VStack(spacing: 10) {
                ForEach(analysis.assessment.focusAreas, id: \.self) { area in
                    HStack(alignment: .top, spacing: 12) {
                        Text(area.region.uppercased())
                            .font(.system(size: 11, weight: .black))
                            .tracking(1)
                            .foregroundStyle(Theme.warning)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Theme.warning.opacity(0.14)))
                        Text(area.note)
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.textPrimary)
                            .lineSpacing(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Theme.warning.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(Theme.warning.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
            }
        }
    }

    // MARK: - Gap to goal

    private func gapSection(_ analysis: AnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Gap to your goal", icon: "figure.walk.motion", tint: Theme.accent)
                .accessibilityHeading(.h2)

            VStack(spacing: 10) {
                ForEach(Array(analysis.gapToGoal.sorted { $0.priority.value < $1.priority.value }.enumerated()), id: \.offset) { index, gap in
                    HStack(alignment: .top, spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Theme.accent.opacity(0.14))
                                .frame(width: 40, height: 40)
                            Text("\(gap.priority.value)")
                                .font(.system(size: 18, weight: .black, design: .monospaced))
                                .foregroundStyle(Theme.accent)
                        }
                        .accessibilityLabel("Priority \(gap.priority.value)")

                        VStack(alignment: .leading, spacing: 5) {
                            Text(gap.region.capitalized)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(Theme.textPrimary)
                            Text(gap.rationale)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.textSecondary)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(16)
                    .blueprintCard()
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Priority \(index + 1): \(gap.region). \(gap.rationale)")
                }
            }
        }
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String
    var tint: Color = Theme.accent

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(tint)
            Text(title)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(Theme.textPrimary)
        }
    }
}
