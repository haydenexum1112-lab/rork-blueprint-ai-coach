import SwiftUI

/// Animated waiting screen while the AI runs the physique analysis.
struct AnalyzingView: View {
    @State private var scanOffset: CGFloat = -160
    @State private var messageIndex: Int = 0
    @State private var pulse: Bool = false

    private let messages: [String] = [
        "Mapping your proportions…",
        "Assessing symmetry & balance…",
        "Measuring the gap to your goal…",
        "Engineering your training split…",
        "Finalizing your blueprint…",
    ]

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            BlueprintGridBackground().ignoresSafeArea()

            VStack(spacing: 36) {
                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Theme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .strokeBorder(Theme.accent.opacity(0.35), lineWidth: 1)
                        )
                        .frame(width: 200, height: 320)

                    Image(systemName: "figure.stand")
                        .font(.system(size: 190, weight: .ultraLight))
                        .foregroundStyle(Theme.accent.opacity(0.5))

                    // Scan line sweeping up and down
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Theme.accent.opacity(0), Theme.accent, Theme.accent.opacity(0)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 190, height: 3)
                        .shadow(color: Theme.accent, radius: 8)
                        .offset(y: scanOffset)
                }
                .scaleEffect(pulse ? 1.02 : 1)

                VStack(spacing: 10) {
                    Text("ANALYZING")
                        .font(.system(size: 14, weight: .black))
                        .tracking(6)
                        .foregroundStyle(Theme.accent)

                    Text(messages[messageIndex])
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .contentTransition(.opacity)
                        .animation(.easeInOut(duration: 0.4), value: messageIndex)

                    Text("This usually takes 20–40 seconds")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                scanOffset = 160
            }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                if messageIndex < messages.count - 1 {
                    messageIndex += 1
                }
            }
        }
    }
}
