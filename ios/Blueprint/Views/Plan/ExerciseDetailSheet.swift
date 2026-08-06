import SwiftUI

/// Exercise detail: why it's in the plan, form cues, swap-for-alternative, and per-set weight/reps logging.
struct ExerciseDetailSheet: View {
    let exercise: Exercise
    let swapKey: String
    let weekNumber: Int
    let dayIndex: Int

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var workingSets: [WorkoutSet] = []
    @State private var hasUnsavedChanges: Bool = false

    private var usesMetric: Bool { appState.profile?.usesMetric ?? false }

    /// Rest timer state
    @State private var showRestTimer: Bool = false
    @State private var restTimerSeconds: Int = 90
    @State private var showRestTimerPrompt: Bool = false

    private var isSwapped: Bool {
        appState.isExerciseSwapped(swapKey)
    }

    private var displayName: String {
        isSwapped ? (exercise.alt ?? exercise.name) : exercise.name
    }

    /// The current session for this week/day, or a fresh one.
    private var currentSession: WorkoutSession? {
        appState.sessionFor(week: weekNumber, dayIndex: dayIndex)
    }

    /// Existing log for this exercise within the session, if any.
    private var existingLog: ExerciseLog? {
        currentSession?.exercises.first(where: { $0.exerciseName == displayName })
    }

    /// Most recent set logged for this exercise (any prior session), for the "last time" hint.
    private var lastSet: WorkoutSet? {
        appState.lastLoggedSet(forExercise: displayName)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                headerSection
                whySection
                cuesSection
                logSection
                swapSection
                doneButton
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .background(Theme.bg)
        .task { loadWorkingSets() }
        .safeAreaInset(edge: .bottom) {
            if showRestTimer {
                RestTimerView(seconds: restTimerSeconds) {
                    withAnimation(.spring(duration: 0.4)) {
                        showRestTimer = false
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showRestTimerPrompt) {
            RestTimerPromptSheet()
                .presentationDetents([.medium])
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(displayName)
                .font(.displayFont(26))
                .foregroundStyle(Theme.textPrimary)
            HStack(spacing: 8) {
                StatPill(label: "\(exercise.sets.value) SETS")
                StatPill(label: "\(exercise.reps.value) REPS")
                StatPill(label: "REST \(exercise.restSec.value)s")
            }
        }
        .padding(.top, 24)
    }

    private var whySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Why it's in your plan", icon: "scope")
            Text(exercise.why)
                .font(.system(size: 15))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(4)
        }
    }

    private var cuesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Form cues", icon: "figure.strengthtraining.traditional")
            ForEach(cues, id: \.self) { cue in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.accent)
                        .padding(.top, 2)
                    Text(cue)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textPrimary)
                        .lineSpacing(2)
                }
            }
        }
    }

    private var logSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(title: "Log your sets", icon: "scalemass")
                Spacer()
            }

            if let last = lastSet {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 11, weight: .bold))
                    Text("Last time: \(formattedWeight(last.weightKg)) × \(last.reps)")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(Theme.accent.opacity(0.12)))
            }

            VStack(spacing: 10) {
                HStack {
                    Text("SET")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(usesMetric ? "WEIGHT (KG)" : "WEIGHT (LB)")
                        .frame(width: 110, alignment: .center)
                    Text("REPS")
                        .frame(width: 60, alignment: .center)
                    Image(systemName: "checkmark.circle.fill")
                        .frame(width: 30)
                        .foregroundStyle(.clear)
                }
                .font(.system(size: 10, weight: .black))
                .tracking(1)
                .foregroundStyle(Theme.textSecondary)

                ForEach(Array(workingSets.enumerated()), id: \.offset) { idx, set in
                    SetRow(
                        index: idx + 1,
                        set: binding(for: idx),
                        suggestedWeight: lastSet?.weightKg ?? 0,
                        suggestedReps: suggestedReps,
                        usesMetric: usesMetric,
                        onSetCompleted: {
                            handleSetCompleted()
                        }
                    )
                }
            }

            if hasUnsavedChanges {
                Button {
                    saveLog()
                } label: {
                    Label("Save sets", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Theme.accent)
                        )
                }
                .padding(.top, 4)
            }

            if existingLog != nil {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 13))
                    Text("\(existingLog!.sets.filter { $0.completed }.count) of \(existingLog!.sets.count) sets logged")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Theme.success)
            }
        }
    }

    private var swapSection: some View {
        Group {
            if let alt = exercise.alt, !alt.isEmpty {
                Button {
                    Haptics.impact()
                    appState.toggleExerciseSwap(swapKey)
                    loadWorkingSets()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 15, weight: .bold))
                        Text(isSwapped ? "Swap back to \(exercise.name)" : "Swap for \(alt)")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Theme.accent.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(Theme.accent.opacity(0.4), lineWidth: 1)
                            )
                    )
                }
            }
        }
    }

    private var doneButton: some View {
        Button("Done") {
            if hasUnsavedChanges { saveLog() }
            dismiss()
        }
        .buttonStyle(SecondaryButtonStyle())
    }

    /// Called when a set is checked off. Triggers rest timer if enabled,
    /// or prompts the user to opt in the first time.
    private func handleSetCompleted() {
        guard appState.profile != nil else { return }
        if appState.shouldPromptForRestTimer {
            showRestTimerPrompt = true
        } else if appState.restTimerEnabled {
            startRestTimer()
        }
    }

    /// Kick off the rest timer using the exercise's rest period.
    private func startRestTimer() {
        restTimerSeconds = exercise.restSec.value
        withAnimation(.spring(duration: 0.45)) {
            showRestTimer = true
        }
    }

    // MARK: - Logic

    private var cues: [String] {
        if let provided = exercise.cues, !provided.isEmpty {
            return provided
        }
        return [
            "Control the eccentric — 2-3 seconds down",
            "Full range of motion over heavier weight",
            "Brace your core before every rep",
        ]
    }

    private var suggestedReps: Int {
        let parts = exercise.reps.value.split(separator: "-").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        return parts.last ?? 8
    }

    private func formattedWeight(_ kg: Double) -> String {
        let usesMetric = appState.profile?.usesMetric ?? false
        if kg == 0 { return "bodyweight" }
        return WeightFormatter.display(kg, usesMetric: usesMetric)
    }

    /// Load sets from existing log, or seed fresh from the plan.
    private func loadWorkingSets() {
        if let log = existingLog {
            workingSets = log.sets
        } else {
            workingSets = (0..<exercise.sets.value).map { _ in
                WorkoutSet(
                    weightKg: lastSet?.weightKg ?? 0,
                    reps: suggestedReps,
                    completed: false
                )
            }
        }
        hasUnsavedChanges = false
    }

    /// Binding into workingSets with change tracking.
    private func binding(for index: Int) -> Binding<WorkoutSet> {
        Binding(
            get: { workingSets[index] },
            set: { newValue in
                workingSets[index] = newValue
                hasUnsavedChanges = true
            }
        )
    }

    /// Persist the current working sets into the workout session.
    private func saveLog() {
        let log = ExerciseLog(
            exerciseName: displayName,
            plannedSets: exercise.sets.value,
            plannedReps: exercise.reps.value,
            sets: workingSets
        )
        var session: WorkoutSession
        if let existing = currentSession {
            session = existing
            if let idx = session.exercises.firstIndex(where: { $0.exerciseName == displayName }) {
                session.exercises[idx] = log
            } else {
                session.exercises.append(log)
            }
        } else {
            session = WorkoutSession(
                weekNumber: weekNumber,
                dayIndex: dayIndex,
                dayName: "Day \(dayIndex + 1)",
                date: Date(),
                exercises: [log],
                isDeload: appState.isCurrentWeekDeload
            )
        }
        appState.saveSession(session)
        hasUnsavedChanges = false
        Haptics.success()
    }
}

// MARK: - Set row

private struct SetRow: View {
    let index: Int
    @Binding var set: WorkoutSet
    let suggestedWeight: Double
    let suggestedReps: Int
    var usesMetric: Bool = true
    var onSetCompleted: () -> Void = {}

    @State private var weightText: String = ""
    @State private var repsText: String = ""

    var body: some View {
        HStack(spacing: 8) {
            Text("\(index)")
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundStyle(set.completed ? Theme.accent : Theme.textSecondary)
                .frame(width: 28, alignment: .leading)

            HStack(spacing: 4) {
                TextField("0", text: $weightText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 9)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Theme.surfaceHi)
                    )
                Text(WeightFormatter.unitLabel(usesMetric: usesMetric))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(width: 110)

            TextField("\(suggestedReps)", text: $repsText)
                .keyboardType(.numberPad)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.vertical, 9)
                .frame(width: 60)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Theme.surfaceHi)
                )

            Button {
                let wasCompleted = set.completed
                set.completed.toggle()
                commitFields()
                if set.completed, !wasCompleted {
                    Haptics.success()
                    onSetCompleted()
                } else {
                    Haptics.impact(.light)
                }
            } label: {
                Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(set.completed ? Theme.success : Theme.textTertiary)
            }
            .frame(width: 30)
        }
        .padding(.vertical, 4)
        .onAppear { syncFields() }
        .onChange(of: weightText) { _, _ in commitFields() }
        .onChange(of: repsText) { _, _ in commitFields() }
    }

    private func syncFields() {
        if weightText.isEmpty {
            let displayVal = WeightFormatter.fromKg(set.weightKg, usesMetric: usesMetric)
            weightText = set.weightKg > 0 ? String(format: "%.1f", displayVal) : ""
        }
        if repsText.isEmpty {
            repsText = set.reps > 0 ? "\(set.reps)" : "\(suggestedReps)"
        }
    }

    private func commitFields() {
        let rawWeight = Double(weightText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let w = WeightFormatter.toKg(rawWeight, usesMetric: usesMetric)
        let r = Int(repsText) ?? suggestedReps
        if set.weightKg != w || set.reps != r {
            set.weightKg = w
            set.reps = r
        }
    }
}

// MARK: - Stat pill

private struct StatPill: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .black, design: .monospaced))
            .tracking(1)
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(Theme.accent.opacity(0.12)))
    }
}
