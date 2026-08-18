import SwiftUI
import AVFoundation

/// A sticky bottom-pill rest timer. Counts down from `seconds`, chimes + vibrates at 0.
/// Designed to overlay the ExerciseDetailSheet via safeAreaInset.
struct RestTimerView: View {
    let seconds: Int
    var onSkip: () -> Void

    @State private var remaining: Int
    @State private var isPaused: Bool = false
    @State private var progress: Double = 1.0
    @State private var addedSeconds: Int = 0

    @State private var audioPlayer: AVAudioPlayer?
    @State private var didFinish: Bool = false

    init(seconds: Int, onSkip: @escaping () -> Void) {
        self.seconds = max(1, seconds)
        self._remaining = State(initialValue: max(1, seconds))
        self.onSkip = onSkip
    }

    var body: some View {
        HStack(spacing: 14) {
            // Ring
            ZStack {
                Circle()
                    .stroke(Theme.surfaceHi, lineWidth: 5)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.3), value: progress)
                Text(formatTime(remaining))
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundStyle(remaining <= 5 && remaining > 0 ? Theme.warning : Theme.textPrimary)
                    .monospacedDigit()
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 2) {
                Text(isPaused ? "Rest paused" : (remaining > 0 ? "Resting" : "Rest complete"))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(remaining > 0 ? "Catch your breath. We'll chime at zero." : "Get after the next set.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // Pause / resume
            Button {
                Haptics.impact(.light)
                isPaused.toggle()
            } label: {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Theme.surfaceHi))
            }
            .disabled(remaining <= 0)

            // +15s
            Button {
                Haptics.impact(.light)
                remaining += 15
                addedSeconds += 15
                recomputeProgress()
            } label: {
                Text("+15")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 42, height: 38)
                    .background(Capsule().fill(Theme.accent.opacity(0.12)))
            }
            .disabled(remaining <= 0)

            // Skip
            Button {
                Haptics.impact(.light)
                onSkip()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Theme.surface))
                    .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(Theme.accent.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 12, y: 4)
        )
        .padding(.horizontal, 22)
        .padding(.bottom, 6)
        .task { prepareChime() }
        .onAppear {
            guard !isPaused, remaining > 0 else { return }
            startTickLoop()
        }
        .onChange(of: isPaused) { _, paused in
            if !paused, remaining > 0, !didFinish {
                startTickLoop()
            }
        }
    }

    // MARK: - Tick loop

    private func startTickLoop() {
        Task { @MainActor in
            while remaining > 0 && !isPaused && !didFinish {
                try? await Task.sleep(for: .seconds(1))
                guard !isPaused, !didFinish else { break }
                if remaining <= 0 { break }
                remaining -= 1
                recomputeProgress()
                if remaining == 3 {
                    Haptics.impact(.light)
                } else if remaining <= 0 {
                    finish()
                }
            }
        }
    }

    private func recomputeProgress() {
        let total = Double(seconds + addedSeconds)
        progress = total > 0 ? max(0.02, Double(remaining) / total) : 0
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        progress = 0
        Haptics.success()
        playChime()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.4))
            onSkip()
        }
    }

    // MARK: - Chime

    private func prepareChime() {
        // Soft, short sine-style alert synthesized in-memory — no asset needed.
        let sampleRate: Double = 44100
        let duration: Double = 0.4
        let count: Int = Int(sampleRate * duration)
        var data = Data(capacity: count * 2)
        var amp: Double = 0.5
        let freq: Double = 880
        for i in 0..<count {
            let t = Double(i) / sampleRate
            // Decay envelope
            let env = pow(1.0 - Double(i) / Double(count), 1.5)
            let sample = amp * env * sin(2.0 * .pi * freq * t)
            var intSample = Int16(sample * Double(Int16.max))
            withUnsafeBytes(of: &intSample) { data.append(contentsOf: $0) }
            amp = 0.5
        }
        let player = try? AVAudioPlayer(data: data)
        player?.prepareToPlay()
        audioPlayer = player
    }

    private func playChime() {
        audioPlayer?.currentTime = 0
        audioPlayer?.play()
    }

    // MARK: - Formatting

    private func formatTime(_ secs: Int) -> String {
        let m = secs / 60
        let s = secs % 60
        return m > 0 ? String(format: "%d:%02d", m, s) : "\(s)s"
    }
}

// MARK: - One-time opt-in prompt

/// Bottom sheet asking the user if they'd like to enable the rest timer.
/// Shown the first time they complete a set if `shouldPromptForRestTimer` is true.
struct RestTimerPromptSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 22) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.12))
                    .frame(width: 96, height: 96)
                Image(systemName: "timer")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }

            VStack(spacing: 10) {
                Text("Turn on the rest timer?")
                    .font(.displayFont(24))
                    .foregroundStyle(Theme.textPrimary)
                Text("When you check off a set, we'll start a countdown for your rest period — with a chime when it's time for the next one.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 12)
            }

            VStack(spacing: 10) {
                Button {
                    Haptics.success()
                    appState.setRestTimerPreference(true)
                    dismiss()
                } label: {
                    Text("Yes, use rest timer")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Theme.accent)
                        )
                }

                Button {
                    Haptics.impact(.light)
                    appState.setRestTimerPreference(false)
                    dismiss()
                } label: {
                    Text("Not now")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 28)

            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 30)
        .background(Theme.bg)
        .presentationDetents([.medium])
    }
}
