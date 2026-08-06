import SwiftUI

/// Recovery tracker: shows which muscle groups are still recovering and which are ready.
/// Surfaces as a card in the Plan tab so users can pick a day that targets recovered muscles.
struct RecoveryTrackerCard: View {
    @Environment(AppState.self) private var appState

    private var recovering: [MuscleRecovery] { appState.recoveringMuscles }
    private var ready: [MuscleGroup] {
        let trained = Set(appState.muscleRecovery.filter { $0.isRecovered }.map { $0.muscle })
        let allTrained = Set(appState.muscleRecovery.map { $0.muscle })
        // Muscles that have been trained and are now recovered
        let readySet = trained
        // Include muscles never trained yet (ready by default) up to the full list
        let neverTrained = Set(MuscleGroup.allCases).subtracting(allTrained)
        return Array(readySet.union(neverTrained)).sorted { $0.rawValue < $1.rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.accent)
                Text("Recovery")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(ready.count) ready · \(recovering.count) recovering")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
            }

            if appState.muscleRecovery.isEmpty {
                Text("Log a workout to see which muscles are recovering.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.vertical, 4)
            } else {
                if !recovering.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("STILL RECOVERING")
                            .font(.system(size: 10, weight: .black))
                            .tracking(2)
                            .foregroundStyle(Theme.warning)
                        ForEach(recovering) { rec in
                            recoveryRow(rec)
                        }
                    }
                }
                if !ready.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("READY TO TRAIN")
                            .font(.system(size: 10, weight: .black))
                            .tracking(2)
                            .foregroundStyle(Theme.success)
                        FlowingChips(items: ready.map { $0.display }) { label in
                            Text(label)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Theme.success.opacity(0.12)))
                        }
                    }
                }
            }
        }
        .padding(16)
        .blueprintCard()
    }

    private func recoveryRow(_ rec: MuscleRecovery) -> some View {
        HStack(spacing: 12) {
            Image(systemName: rec.muscle.icon)
                .font(.system(size: 14))
                .foregroundStyle(Theme.warning)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(rec.muscle.display)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(rec.statusLabel)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Theme.surfaceHi, lineWidth: 4)
                Circle()
                    .trim(from: 0, to: rec.progress)
                    .stroke(Theme.warning, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.4), value: rec.progress)
            }
            .frame(width: 28, height: 28)
        }
    }
}

/// Simple wrapping chips layout for muscle group tags.
private struct FlowingChips<Item: Hashable, Content: View>: View {
    let items: [Item]
    @ViewBuilder let content: (Item) -> Content
    private let padding: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            generateContent(in: geo.size)
        }
        .frame(minHeight: 28)
    }

    private func generateContent(in size: CGSize) -> some View {
        var x: CGFloat = 0
        var rows: [[Item]] = [[]]
        for item in items {
            let label = String(describing: item)
            let width = label.size(withFont: .systemFont(ofSize: 12, weight: .semibold)).width + 32
            if x + width > size.width {
                rows.append([item])
                x = width + padding
            } else {
                rows[rows.count - 1].append(item)
                x += width + padding
            }
        }
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(row, id: \.self) { item in
                        content(item)
                    }
                    Spacer()
                }
            }
        }
    }
}

private extension String {
    func size(withFont font: UIFont) -> CGSize {
        let attributes = [NSAttributedString.Key.font: font]
        return (self as NSString).size(withAttributes: attributes)
    }
}
