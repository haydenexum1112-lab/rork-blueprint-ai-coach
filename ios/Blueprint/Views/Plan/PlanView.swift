import SwiftUI

/// Weekly training plan built from the latest scan's analysis.
struct PlanView: View {
    @Environment(AppState.self) private var appState
    @Environment(HealthKitManager.self) private var healthKit
    @Binding var showScanFlow: Bool

    @State private var selectedDayIndex: Int = 0
    @State private var selectedExercise: ExerciseSelection?
    @State private var showResults: Bool = false
    @State private var showWeekCompleteConfirm: Bool = false

    struct ExerciseSelection: Identifiable {
        let id = UUID()
        let exercise: Exercise
        let swapKey: String
    }

    var body: some View {
        Group {
            if appState.latestAnalysis != nil {
                planContent
            } else {
                Text("No plan yet")
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .sheet(item: $selectedExercise) { selection in
            ExerciseDetailSheet(
                exercise: selection.exercise,
                swapKey: selection.swapKey,
                weekNumber: appState.currentWeek,
                dayIndex: selectedDayIndex
            )
            .presentationDetents([.medium, .large])
            .presentationContentInteraction(.scrolls)
        }
        .sheet(isPresented: $showResults) {
            if let scan = appState.latestScan {
                ResultsView(scan: scan)
            }
        }
        .confirmationDialog("Mark this week complete?", isPresented: $showWeekCompleteConfirm, titleVisibility: .visible) {
            Button("Complete Week \(appState.currentWeek)") {
                Haptics.success()
                appState.completeCurrentWeek()
                selectedDayIndex = 0
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Layout

    private var planContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                planHeader
                splitInfoCard
                progressionCard
                RecoveryTrackerCard()
                if !healthKit.isAuthorized && healthKit.isAvailable {
                    healthConnectBanner
                }
                if appState.rescanDue {
                    rescanBanner
                }
                dayPicker
                selectedDaySection
                completeWeekButton
                DisclaimerFooter()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Header

    private var planHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("WEEK \(appState.currentWeek)")
                        .font(.system(size: 11, weight: .black))
                        .tracking(3)
                        .foregroundStyle(Theme.accent)
                    Text(appState.latestAnalysis?.plan.splitName ?? "Your split")
                        .font(.displayFont(26))
                        .foregroundStyle(Theme.textPrimary)
                }
                Spacer()
                Button {
                    Haptics.impact(.light)
                    showResults = true
                } label: {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Theme.surface))
                }
            }

            HStack(spacing: 8) {
                Label("\(appState.latestAnalysis?.plan.daysPerWeek.value ?? 0) days / week", systemImage: "calendar")
                Label("\(appState.streakWeeks) week streak", systemImage: "flame.fill")
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: - Split card

    private var splitInfoCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.accent.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Your split")
                    .font(.system(size: 12, weight: .black))
                    .tracking(2)
                    .foregroundStyle(Theme.textSecondary)
                Text(appState.latestAnalysis?.plan.splitName ?? "")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(Theme.textPrimary)
                Text(appState.latestAnalysis?.plan.splitDescription ?? "")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            TagChip(text: "\(appState.latestAnalysis?.plan.daysPerWeek.value ?? 0) days")
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cardRadius)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                )
                .shadow(color: Theme.accent.opacity(0.04), radius: 16, x: 0, y: 6)
        )
    }

    // MARK: - Progression card

    private var progressionCard: some View {
        let progression = appState.weekProgression(forWeek: appState.currentWeek)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: progression.isDeload ? "leaf.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(progression.isDeload ? Theme.success : Theme.accent)
                Text(progression.isDeload ? "Deload week" : "What's new this week")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("WK \(progression.weekNumber)")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(Theme.textSecondary)
            }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(progression.changes, id: \.self) { change in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: progression.isDeload ? "moon.zzz.fill" : "arrowtriangle.right.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(progression.isDeload ? Theme.success : Theme.accent)
                            .padding(.top, 4)
                        Text(change)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                            .lineSpacing(2)
                    }
                }
            }
        }
        .padding(16)
        .blueprintCard()
    }

    // MARK: - Apple Health connect banner

    private var healthConnectBanner: some View {
        Button {
            Haptics.impact(.light)
            Task {
                await healthKit.requestAuthorization()
            }
        } label: {
            HStack(spacing: 12) {
            Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color(red: 244/255, green: 63/255, blue: 94/255))
                    .frame(width: 44, height: 44)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(red: 244/255, green: 63/255, blue: 94/255).opacity(0.12)))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Connect to Apple Health")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Sync your weight, workouts, and step count automatically.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color(red: 244/255, green: 63/255, blue: 94/255).opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Rescan

    private var rescanBanner: some View {
        Button {
            Haptics.impact()
            if appState.canStartNewScan {
                showScanFlow = true
            } else {
                appState.showPaywall = true
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Time to re-scan")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("4 weeks done — measure your progress and refresh the plan.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(16)
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

    // MARK: - Day picker with rest day

    private var dayPicker: some View {
        let trainingDays = appState.latestAnalysis?.plan.days ?? []
        let totalSlots = totalDaySlots(trainingDays: trainingDays)
        let trainingDayCount = trainingDays.count
        let plan = appState.latestAnalysis?.plan

        return ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(0..<totalSlots, id: \.self) { index in
                    if index < trainingDayCount {
                        let locked = !(plan?.isDayFree(index) ?? true) && !appState.hasWorkoutsAccess
                        Button {
                            Haptics.impact(.light)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                selectedDayIndex = index
                            }
                        } label: {
                            HStack(spacing: 5) {
                                if locked {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 10, weight: .bold))
                                }
                                Text("Day \(index + 1)")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundStyle(selectedDayIndex == index ? Color.black : Theme.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(selectedDayIndex == index ? Theme.accent : Theme.surface)
                                    .overlay(
                                        Capsule().strokeBorder(selectedDayIndex == index ? Color.clear : Theme.hairline, lineWidth: 1)
                                    )
                            )
                        }
                    } else {
                        Button {
                            Haptics.impact(.light)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                selectedDayIndex = index
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "leaf.fill")
                                    .font(.system(size: 10, weight: .bold))
                                Text("Rest")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundStyle(selectedDayIndex == index ? Color.black : Theme.success)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(selectedDayIndex == index ? Theme.success.opacity(0.85) : Theme.surface)
                                    .overlay(
                                        Capsule().strokeBorder(selectedDayIndex == index ? Color.clear : Theme.hairline, lineWidth: 1)
                                    )
                            )
                        }
                    }
                }
            }
        }
        .contentMargins(.horizontal, 0)
        .scrollIndicators(.hidden)
    }

    /// Total slots = training days + rest days (so a 4-day plan shows 7 slots).
    private func totalDaySlots(trainingDays: [WorkoutDay]) -> Int {
        max(trainingDays.count, 7)
    }

    // MARK: - Selected day section

    @ViewBuilder
    private var selectedDaySection: some View {
        if let plan = appState.latestAnalysis,
           let day = currentWeekPlanDay(at: selectedDayIndex) {
            let locked = !plan.plan.isDayFree(selectedDayIndex) && !appState.hasWorkoutsAccess
            dayCard(day: day, dayIndex: selectedDayIndex, scanId: appState.latestScan?.id ?? UUID(), isLocked: locked)
        } else {
            restDayCard
        }
    }

    /// Fetch the day for the current week (with progression applied).
    private func currentWeekPlanDay(at index: Int) -> WorkoutDay? {
        guard let days = appState.currentWeekPlanDays(), days.indices.contains(index) else { return nil }
        return days[index]
    }

    private var restDayCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(Theme.success)
            Text("Rest & recover")
                .font(.system(size: 19, weight: .heavy))
                .foregroundStyle(Theme.textPrimary)
            Text("Recovery is where your muscles rebuild. Stay active with light walking or mobility work — no heavy lifting today.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
            HStack(spacing: 18) {
                restPill(icon: "figure.walk", label: "Light walk")
                restPill(icon: "hand.raised.fill", label: "Mobility")
                restPill(icon: "moon.fill", label: "Sleep 8h")
            }
            .padding(.top, 4)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .fill(Theme.success.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cardRadius)
                        .strokeBorder(Theme.success.opacity(0.25), lineWidth: 1)
                )
        )
    }

    private func restPill(icon: String, label: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.success)
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(Capsule().fill(Theme.surface))
    }

    // MARK: - Day card

    private func dayCard(day: WorkoutDay, dayIndex: Int, scanId: UUID, isLocked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(day.day)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(Theme.textPrimary)
                HStack(spacing: 6) {
                    ForEach(day.targets, id: \.self) { region in
                        TagChip(text: region.capitalized)
                    }
                    Spacer()
                    sessionStatusBadge(dayIndex: dayIndex)
                }
            }

            VStack(spacing: 8) {
                ForEach(Array(day.exercises.enumerated()), id: \.offset) { exerciseIndex, exercise in
                    let swapKey = "\(scanId.uuidString)-\(dayIndex)-\(exerciseIndex)"
                    ExerciseRow(
                        exercise: exercise,
                        isSwapped: appState.isExerciseSwapped(swapKey),
                        lastSet: appState.lastLoggedSet(forExercise: exercise.name),
                        usesMetric: appState.profile?.usesMetric ?? false,
                        onTap: {
                            Haptics.impact(.light)
                            selectedExercise = ExerciseSelection(exercise: exercise, swapKey: swapKey)
                        }
                    )
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .blueprintCard()
        .overlay {
            if isLocked {
                lockOverlay
            }
        }
    }

    @ViewBuilder
    private func sessionStatusBadge(dayIndex: Int) -> some View {
        if let session = appState.sessionFor(week: appState.currentWeek, dayIndex: dayIndex) {
            let completedCount = session.exercises.flatMap { $0.sets.filter { $0.completed } }.count
            let totalSets = session.exercises.reduce(0) { $0 + $1.sets.count }
            HStack(spacing: 4) {
                Image(systemName: session.isFinished ? "checkmark.seal.fill" : "scalemass.fill")
                    .font(.system(size: 10, weight: .bold))
                Text(session.isFinished ? "Logged" : "\(completedCount)/\(totalSets) sets")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(session.isFinished ? Theme.success : Theme.accent)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Capsule().fill(session.isFinished ? Theme.success.opacity(0.12) : Theme.accent.opacity(0.12)))
        }
    }

    private var lockOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .fill(.ultraThinMaterial)
            VStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Theme.accent)
                Text("Unlock your full week")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(Theme.textPrimary)
                Text("Days 1–3 are free. Go Pro to unlock the rest of your week.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                Button("Unlock with Pro") {
                    Haptics.impact()
                    appState.showPaywall = true
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.black)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Capsule().fill(Theme.accent))
            }
            .padding(20)
        }
    }

    // MARK: - Complete week

    private var completeWeekButton: some View {
        Button {
            Haptics.impact(.light)
            showWeekCompleteConfirm = true
        } label: {
            Label("Mark week \(appState.currentWeek) complete", systemImage: "checkmark.circle.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.success)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Theme.success.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Theme.success.opacity(0.35), lineWidth: 1)
                        )
                )
        }
    }
}

// MARK: - Exercise row

private struct ExerciseRow: View {
    let exercise: Exercise
    let isSwapped: Bool
    let lastSet: WorkoutSet?
    let usesMetric: Bool
    let onTap: () -> Void

    private var displayName: String {
        isSwapped ? (exercise.alt ?? exercise.name) : exercise.name
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(displayName)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                            .multilineTextAlignment(.leading)
                        if isSwapped {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Theme.accent)
                        }
                    }
                    HStack(spacing: 8) {
                        Text("\(exercise.sets.value) sets × \(exercise.reps.value) · rest \(exercise.restSec.value)s")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.textSecondary)
                        if let last = lastSet {
                            Text("· last \(WeightFormatter.display(last.weightKg, usesMetric: usesMetric)) × \(last.reps)")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Theme.accent)
                        }
                    }
                }
                Spacer()
                Image(systemName: "info.circle")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.surfaceHi.opacity(0.6))
            )
        }
    }
}
