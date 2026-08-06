import SwiftUI

/// Quick freeform workout logger, launched from the Calendar day detail.
/// Lets the user add exercises with sets/reps/weight without needing a plan day.
struct QuickWorkoutSheet: View {
    let date: Date

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var workoutTitle: String = ""
    @State private var exercises: [QuickExercise] = []
    @State private var showAddExercise: Bool = false

    private var usesMetric: Bool { appState.profile?.usesMetric ?? false }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    titleSection
                    if exercises.isEmpty {
                        emptyExerciseState
                    } else {
                        exerciseList
                    }
                    addExerciseButton
                }
                .padding(.horizontal, 22)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(Theme.bg)
            .navigationTitle("Log Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { saveWorkout() }
                        .fontWeight(.bold)
                        .foregroundStyle(Theme.accent)
                        .disabled(exercises.isEmpty)
                }
            }
            .sheet(isPresented: $showAddExercise) {
                AddQuickExerciseSheet { newEx in
                    exercises.append(newEx)
                    showAddExercise = false
                }
                .presentationDetents([.large])
                .presentationContentInteraction(.scrolls)
            }
        }
    }

    // MARK: - Sections

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Workout name")
                .font(.system(size: 12, weight: .black))
                .tracking(2)
                .foregroundStyle(Theme.textSecondary)
            TextField("e.g. Morning Lift", text: $workoutTitle)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Theme.hairline, lineWidth: 1)
                        )
                )
            Text(date.formatted(date: .long, time: .omitted))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
        }
    }

    private var emptyExerciseState: some View {
        VStack(spacing: 12) {
            Image(systemName: "barbell.fill")
                .font(.system(size: 36))
                .foregroundStyle(Theme.accent.opacity(0.5))
            Text("Add your first exercise")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text("Tap below to search 300+ exercises and log sets, reps, and weight.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private var exerciseList: some View {
        VStack(spacing: 14) {
            ForEach($exercises) { $ex in
                QuickExerciseCard(exercise: $ex, usesMetric: usesMetric) {
                    exercises.removeAll { $0.id == ex.id }
                }
            }
            let totalVolume = exercises.flatMap { $0.sets }.filter { $0.completed }.reduce(0.0) { $0 + $1.weightKg * Double($1.reps) }
            let totalSets = exercises.flatMap { $0.sets }.filter { $0.completed }.count
            HStack(spacing: 16) {
                Label(WeightFormatter.volume(totalVolume, usesMetric: usesMetric), systemImage: "barbell.fill")
                Label("\(totalSets) sets", systemImage: "list.number")
                Spacer()
            }
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.accent.opacity(0.06)))
        }
    }

    private var addExerciseButton: some View {
        Button {
            Haptics.impact(.light)
            showAddExercise = true
        } label: {
            Label("Add exercise", systemImage: "plus.circle.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Theme.accent.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Theme.accent.opacity(0.3), lineWidth: 1)
                        )
                )
        }
    }

    // MARK: - Save

    private func saveWorkout() {
        let title = workoutTitle.trimmingCharacters(in: .whitespaces)
        let exerciseLogs = exercises.map { qe in
            ExerciseLog(
                exerciseName: qe.name,
                plannedSets: qe.sets.count,
                plannedReps: "\(qe.targetReps)",
                sets: qe.sets
            )
        }
        let session = WorkoutSession(
            weekNumber: 0,
            dayIndex: -1,
            dayName: title.isEmpty ? "Custom Workout" : title,
            date: date,
            exercises: exerciseLogs,
            isDeload: false,
            customTitle: title.isEmpty ? "Custom Workout" : title
        )
        appState.saveSession(session)
        Haptics.success()
        dismiss()
    }
}

// MARK: - Quick exercise model

struct QuickExercise: Identifiable {
    let id = UUID()
    var name: String
    var targetReps: Int
    var sets: [WorkoutSet]
}

// MARK: - Quick exercise card

private struct QuickExerciseCard: View {
    @Binding var exercise: QuickExercise
    let usesMetric: Bool
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(exercise.name)
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button {
                    Haptics.impact(.light)
                    onDelete()
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.danger.opacity(0.7))
                }
            }

            HStack {
                Text("SET")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(WeightFormatter.unitLabel(usesMetric: usesMetric).uppercased())
                    .frame(width: 90, alignment: .center)
                Text("REPS")
                    .frame(width: 56, alignment: .center)
                Image(systemName: "checkmark.circle.fill")
                    .frame(width: 28)
                    .foregroundStyle(.clear)
            }
            .font(.system(size: 10, weight: .black))
            .tracking(1)
            .foregroundStyle(Theme.textSecondary)

            ForEach(Array(exercise.sets.enumerated()), id: \.offset) { idx, _ in
                QuickSetRow(
                    index: idx + 1,
                    set: bindingFor(idx),
                    usesMetric: usesMetric
                )
            }

            Button {
                Haptics.impact(.light)
                exercise.sets.append(WorkoutSet(
                    weightKg: exercise.sets.last?.weightKg ?? 0,
                    reps: exercise.targetReps,
                    completed: false
                ))
            } label: {
                Label("Add set", systemImage: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                )
        )
    }

    private func bindingFor(_ index: Int) -> Binding<WorkoutSet> {
        Binding(
            get: { exercise.sets[index] },
            set: { exercise.sets[index] = $0 }
        )
    }
}

// MARK: - Quick set row

private struct QuickSetRow: View {
    let index: Int
    @Binding var set: WorkoutSet
    let usesMetric: Bool

    @State private var weightText: String = ""
    @State private var repsText: String = ""

    var body: some View {
        HStack(spacing: 8) {
            Text("\(index)")
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundStyle(set.completed ? Theme.accent : Theme.textSecondary)
                .frame(width: 24, alignment: .leading)

            HStack(spacing: 4) {
                TextField("0", text: $weightText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 9)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surfaceHi))
                Text(WeightFormatter.unitLabel(usesMetric: usesMetric))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(width: 90)

            TextField("8", text: $repsText)
                .keyboardType(.numberPad)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.vertical, 9)
                .frame(width: 56)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surfaceHi))

            Button {
                let wasCompleted = set.completed
                set.completed.toggle()
                commitFields()
                if set.completed, !wasCompleted {
                    Haptics.success()
                } else {
                    Haptics.impact(.light)
                }
            } label: {
                Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(set.completed ? Theme.success : Theme.textTertiary)
            }
            .frame(width: 28)
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
            repsText = set.reps > 0 ? "\(set.reps)" : ""
        }
    }

    private func commitFields() {
        let rawWeight = Double(weightText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let kg = WeightFormatter.toKg(rawWeight, usesMetric: usesMetric)
        let r = Int(repsText) ?? 8
        if set.weightKg != kg || set.reps != r {
            set.weightKg = kg
            set.reps = r
        }
    }
}

// MARK: - Add exercise sheet (searchable browser)

private struct AddQuickExerciseSheet: View {
    let onAdd: (QuickExercise) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var search: String = ""
    @State private var selectedMuscle: MuscleGroup?
    @State private var selectedEquipment: ExerciseEquipment?
    @State private var showCustomSheet: Bool = false

    private var filteredExercises: [ExerciseDefinition] {
        ExerciseLibrary.search(query: search, muscle: selectedMuscle, equipment: selectedEquipment)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                filterRow
                exerciseList
            }
            .background(Theme.bg)
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCustomSheet = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
            .sheet(isPresented: $showCustomSheet) {
                CustomExerciseSheet { exercise in
                    onAdd(exercise)
                    showCustomSheet = false
                    dismiss()
                }
                .presentationDetents([.medium, .large])
                .presentationContentInteraction(.scrolls)
            }
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
            TextField("Search 300+ exercises", text: $search)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
            if !search.isEmpty {
                Button {
                    search = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.surface)
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.hairline, lineWidth: 1))
        )
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    // MARK: - Filter row

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "All", isSelected: selectedMuscle == nil && selectedEquipment == nil) {
                    selectedMuscle = nil
                    selectedEquipment = nil
                }
                ForEach(MuscleGroup.allCases) { muscle in
                    filterChip(
                        label: muscle.display,
                        isSelected: selectedMuscle == muscle
                    ) {
                        selectedMuscle = selectedMuscle == muscle ? nil : muscle
                    }
                }
                Divider().frame(height: 22).padding(.horizontal, 4)
                ForEach(ExerciseEquipment.allCases) { eq in
                    filterChip(
                        label: eq.display,
                        icon: eq.icon,
                        isSelected: selectedEquipment == eq
                    ) {
                        selectedEquipment = selectedEquipment == eq ? nil : eq
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
    }

    private func filterChip(label: String, icon: String? = nil, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.impact(.light)
            action()
        } label: {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                }
                Text(label)
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(isSelected ? Color.black : Theme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(isSelected ? Theme.accent : Theme.surface)
                    .overlay(Capsule().strokeBorder(isSelected ? Color.clear : Theme.hairline, lineWidth: 1))
            )
        }
    }

    // MARK: - Exercise list

    @ViewBuilder
    private var exerciseList: some View {
        if filteredExercises.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 36))
                    .foregroundStyle(Theme.accent.opacity(0.4))
                Text("No exercises found")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Try a different search or filter, or tap the pencil icon to create a custom exercise.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredExercises) { exercise in
                        ExercisePickerRow(exercise: exercise) {
                            addExercise(exercise)
                        }
                    }
                }
                .padding(.bottom, 32)
            }
        }
    }

    private func addExercise(_ def: ExerciseDefinition) {
        Haptics.success()
        let workoutSets = (0..<def.defaultSets).map { _ in
            WorkoutSet(weightKg: 0, reps: def.defaultReps, completed: false)
        }
        onAdd(QuickExercise(name: def.name, targetReps: def.defaultReps, sets: workoutSets))
        dismiss()
    }
}

// MARK: - Exercise picker row

private struct ExercisePickerRow: View {
    let exercise: ExerciseDefinition
    let onTap: () -> Void

    var body: some View {
        Button { onTap() } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.accent.opacity(0.1))
                        .frame(width: 38, height: 38)
                    Image(systemName: exercise.primaryMuscle.icon)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(exercise.primaryMuscle.display)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.textSecondary)
                        if !exercise.secondaryMuscles.isEmpty {
                            Text("· \(exercise.secondaryMuscles.map(\.display).joined(separator: ", "))")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Theme.textTertiary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(exercise.equipment.display)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                    Text("\(exercise.defaultSets)×\(exercise.defaultReps)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.accent)
                }

                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.accent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        Divider().overlay(Theme.hairline).padding(.leading, 70)
    }
}

// MARK: - Custom exercise sheet

private struct CustomExerciseSheet: View {
    let onAdd: (QuickExercise) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var sets: Int = 3
    @State private var reps: Int = 8

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("EXERCISE NAME")
                            .font(.system(size: 12, weight: .black))
                            .tracking(2)
                            .foregroundStyle(Theme.textSecondary)
                        TextField("e.g. Cable Lateral Raise", text: $name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Theme.surface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(Theme.hairline, lineWidth: 1)
                                    )
                            )
                    }

                    HStack(spacing: 16) {
                        VStack(spacing: 6) {
                            Text("SETS")
                                .font(.system(size: 11, weight: .black))
                                .tracking(2)
                                .foregroundStyle(Theme.textSecondary)
                            Stepper("\(sets)", value: $sets, in: 1...10)
                                .font(.system(size: 18, weight: .heavy, design: .rounded))
                                .foregroundStyle(Theme.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))

                        VStack(spacing: 6) {
                            Text("REPS")
                                .font(.system(size: 11, weight: .black))
                                .tracking(2)
                                .foregroundStyle(Theme.textSecondary)
                            Stepper("\(reps)", value: $reps, in: 1...30)
                                .font(.system(size: 18, weight: .heavy, design: .rounded))
                                .foregroundStyle(Theme.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(Theme.bg)
            .navigationTitle("Custom Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        let exerciseName = trimmed.isEmpty ? "Exercise" : trimmed
                        let workoutSets = (0..<sets).map { _ in
                            WorkoutSet(weightKg: 0, reps: reps, completed: false)
                        }
                        onAdd(QuickExercise(name: exerciseName, targetReps: reps, sets: workoutSets))
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.accent)
                }
            }
        }
    }
}
