import SwiftUI

/// PAR-Q (Physical Activity Readiness Questionnaire) — 7 standard yes/no questions
/// presented before the first training plan is shown.
struct HealthScreenerView: View {
    @Environment(AppState.self) private var appState
    let onComplete: (Bool) -> Void

    @State private var answers: [Bool?] = Array(repeating: nil, count: ParQQuestions.all.count)
    @State private var showWarning: Bool = false

    private var allAnswered: Bool {
        answers.allSatisfy { $0 != nil }
    }

    private var anyYes: Bool {
        answers.contains(true)
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("Health Check")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 4)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Before you start")
                                .font(.displayFont(28))
                                .foregroundStyle(Theme.textPrimary)
                            Text("Answer 7 quick questions so we can make sure your plan is safe for you. This is the standard PAR-Q used by fitness professionals worldwide.")
                                .font(.system(size: 15))
                                .foregroundStyle(Theme.textSecondary)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        VStack(spacing: 12) {
                            ForEach(Array(ParQQuestions.all.enumerated()), id: \.offset) { index, question in
                                questionCard(index: index, question: question)
                            }
                        }

                        if allAnswered && !anyYes {
                            clearedCard
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
                .scrollIndicators(.hidden)

                if allAnswered && !anyYes {
                    Button {
                        Haptics.success()
                        appState.meta.parqPassed = true
                        appState.meta.parqCompletedAt = Date()
                        appState.persistMeta()
                        onComplete(true)
                    } label: {
                        Text("Continue to my plan")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                } else if allAnswered && anyYes {
                    Button {
                        Haptics.warning()
                        showWarning = true
                    } label: {
                        Text("See recommendation")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                }
            }
        }
        .sheet(isPresented: $showWarning) {
            warningSheet
        }
    }

    // MARK: - Question card

    @ViewBuilder
    private func questionCard(index: Int, question: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(question)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                answerButton(index: index, answer: false, label: "No")
                answerButton(index: index, answer: true, label: "Yes")
            }
        }
        .padding(16)
        .blueprintCard()
    }

    private func answerButton(index: Int, answer: Bool, label: String) -> some View {
        let isSelected = answers[index] == answer
        let isYes = answer
        return Button {
            Haptics.impact(.light)
            answers[index] = answer
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(isSelected ? Color.white : (isYes ? Theme.warning : Theme.textPrimary))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? (isYes ? Theme.warning : Theme.accent) : Theme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(isSelected ? Color.clear : Theme.hairline, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Cleared card

    private var clearedCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.success.opacity(0.14))
                    .frame(width: 36, height: 36)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.success)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("You're cleared to train")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.success)
                Text("No health concerns flagged. Let's build your plan.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.success.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Theme.success.opacity(0.25), lineWidth: 1)
                )
        )
    }

    // MARK: - Warning sheet

    private var warningSheet: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Theme.warning.opacity(0.14))
                        .frame(width: 80, height: 80)
                    Image(systemName: "stethoscope")
                        .font(.system(size: 34))
                        .foregroundStyle(Theme.warning)
                }

                Text("Check with your doctor first")
                    .font(.displayFont(24))
                    .foregroundStyle(Theme.textPrimary)

                Text("You answered yes to one or more health questions. We strongly recommend consulting a physician before starting any exercise program. Bring your PhyziqAi plan to the conversation so they can advise on modifications.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    Haptics.impact(.light)
                    appState.meta.parqPassed = false
                    appState.meta.parqCompletedAt = Date()
                    appState.persistMeta()
                    onComplete(false)
                } label: {
                    Text("I'll check with my doctor first")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())

                Button {
                    Haptics.warning()
                    appState.meta.parqPassed = true
                    appState.meta.parqCompletedAt = Date()
                    appState.persistMeta()
                    showWarning = false
                    onComplete(true)
                } label: {
                    Text("Continue anyway")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Theme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Theme.hairline, lineWidth: 1)
                        )
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .presentationDetents([.medium])
    }
}

/// Standard PAR-Q 7-question form.
nonisolated enum ParQQuestions {
    static let all: [String] = [
        "Has your doctor ever said you have a heart condition and that you should only do physical activity recommended by a doctor?",
        "Do you feel pain in your chest when you do physical activity?",
        "In the past month, have you had chest pain when you were not doing physical activity?",
        "Do you lose your balance because of dizziness or do you ever lose consciousness?",
        "Do you have a bone or joint problem that could be made worse by a change in your physical activity?",
        "Is your doctor currently prescribing drugs for your blood pressure or heart condition?",
        "Do you know of any other reason why you should not do physical activity?",
    ]
}
