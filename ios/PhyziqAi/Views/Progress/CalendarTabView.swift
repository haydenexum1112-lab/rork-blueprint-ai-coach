import SwiftUI

/// Calendar: monthly grid showing past workouts, meals logged that day, volume trends, and session history.
struct CalendarTabView: View {
    @Environment(AppState.self) private var appState

    @State private var displayedMonth: Date = Date()
    @State private var selectedSession: WorkoutSession?
    @State private var selectedDay: DateComponents?

    private let calendar = Calendar.current
    private let weekdays = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        summaryCards
                        monthNavigator
                        monthGrid
                        volumeChart
                        recentSessionsList
                        DisclaimerFooter()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $selectedSession) { session in
                SessionDetailSheet(session: session, usesMetric: usesMetric)
                    .presentationDetents([.medium, .large])
                    .presentationContentInteraction(.scrolls)
            }
            .sheet(item: Binding(
                get: { selectedDay.map { DayIdentifier(components: $0) } },
                set: { newValue in selectedDay = newValue?.components }
            )) { dayId in
                DayDetailSheet(
                    dayComponents: dayId.components,
                    sessions: sessionsForDay(dayId.components),
                    appState: appState
                )
                .presentationDetents([.medium, .large])
                .presentationContentInteraction(.scrolls)
            }
        }
    }

    // MARK: - Empty state

    // MARK: - Summary cards

    private var usesMetric: Bool { appState.profile?.usesMetric ?? false }

    private var summaryCards: some View {
        HStack(spacing: 10) {
            StatCard(
                value: "\(appState.totalSessionsCompleted)",
                label: "SESSIONS\nLOGGED",
                icon: "scalemass.fill"
            )
            StatCard(
                value: WeightFormatter.volume(totalVolumeAllTime, usesMetric: usesMetric),
                label: usesMetric ? "TOTAL KG\nLIFTED" : "TOTAL LB\nLIFTED",
                icon: "barbell.fill"
            )
            StatCard(
                value: "\(appState.workoutSessions.filter { $0.isFinished }.reduce(0) { $0 + $1.estimatedMinutes })",
                label: "MINUTES\nTRAINED",
                icon: "clock.fill"
            )
        }
    }

    private var totalVolumeAllTime: Double {
        appState.workoutSessions.reduce(0) { $0 + $1.totalVolume }
    }

    // MARK: - Month navigation

    private var monthNavigator: some View {
        HStack {
            Button {
                Haptics.impact(.light)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Theme.surface))
            }

            Spacer()

            Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(Theme.textPrimary)

            Spacer()

            Button {
                Haptics.impact(.light)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(canGoForward ? Theme.accent : Theme.textTertiary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Theme.surface))
            }
            .disabled(!canGoForward)
        }
    }

    private var canGoForward: Bool {
        let now = Date()
        return displayedMonth < now
    }

    // MARK: - Month grid

    private var monthGrid: some View {
        let daysInMonth = calendar.range(of: .day, in: .month, for: displayedMonth)?.count ?? 30
        let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) ?? displayedMonth
        let weekday = calendar.component(.weekday, from: firstDay)
        let offset = (weekday + 5) % 7
        let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) ?? DateInterval(start: firstDay, duration: 0)
        let monthSessions = appState.sessionsInMonth(monthInterval)
        let sessionByDay = Dictionary(grouping: monthSessions) { calendar.component(.day, from: $0.date) }

        return VStack(spacing: 6) {
            HStack(spacing: 4) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 10, weight: .black))
                        .tracking(1)
                        .foregroundStyle(Theme.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            let totalCells = ((offset + daysInMonth + 6) / 7) * 7
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(0..<totalCells, id: \.self) { cell in
                    if cell < offset || cell >= offset + daysInMonth {
                        Color.clear.frame(height: 44)
                    } else {
                        let day = cell - offset + 1
                        let sessions = sessionByDay[day] ?? []
                        let isToday = isToday(day: day)
                        let hasMeals = appState.hasNutrition && appState.hasNutritionPreferences
                        DayCell(day: day, hasWorkout: !sessions.isEmpty, hasMeals: hasMeals, isToday: isToday) {
                            Haptics.impact(.light)
                            var comps = calendar.dateComponents([.year, .month], from: displayedMonth)
                            comps.day = day
                            selectedDay = comps
                        }
                    }
                }
            }
        }
        .padding(14)
        .blueprintCard()
    }

    private func sessionsForDay(_ comps: DateComponents) -> [WorkoutSession] {
        guard let date = calendar.date(from: comps) else { return [] }
        return appState.workoutSessions.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    private func isToday(day: Int) -> Bool {
        let today = calendar.dateComponents([.year, .month, .day], from: Date())
        let displayed = calendar.dateComponents([.year, .month], from: displayedMonth)
        return today.year == displayed.year && today.month == displayed.month && today.day == day
    }

    // MARK: - Volume chart

    private var volumeChart: some View {
        let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) ?? DateInterval(start: Date(), duration: 0)
        let monthSessions = appState.sessionsInMonth(monthInterval).sorted { $0.date < $1.date }
        let maxVolume = max(1, monthSessions.map { $0.totalVolume }.max() ?? 0)

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Volume this month", icon: "chart.bar.fill")
            if monthSessions.isEmpty {
                Text("No sessions logged this month yet.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.vertical, 16)
            } else {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(monthSessions) { session in
                        Button {
                            Haptics.impact(.light)
                            selectedSession = session
                        } label: {
                            VStack(spacing: 6) {
                                Text(session.totalVolume > 0 ? String(format: "%.0f", session.totalVolume) : "—")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Theme.textSecondary)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(session.isFinished ? Theme.accent : Theme.accent.opacity(0.35))
                                    .frame(width: 20, height: max(4, CGFloat(session.totalVolume / maxVolume) * 100))
                                Text(session.date.formatted(.dateTime.day()))
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(Theme.textTertiary)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text("Tap a bar to view the session. Tap any day to see workouts and meals.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary.opacity(0.8))
        }
        .padding(16)
        .blueprintCard()
    }

    // MARK: - Recent sessions

    private var recentSessionsList: some View {
        let recent = appState.workoutSessions.sorted { $0.date > $1.date }.prefix(10)
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Recent workouts", icon: "clock.arrow.circlepath")
            if recent.isEmpty {
                Text("No workouts logged yet. Open a day in the PhyziqAi tab and log your weights.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(recent), id: \.id) { session in
                        Button {
                            Haptics.impact(.light)
                            selectedSession = session
                        } label: {
                            SessionRow(session: session, usesMetric: usesMetric)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Day identifier (Identifiable for sheet)

private struct DayIdentifier: Identifiable {
    let components: DateComponents
    var id: String {
        "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }
}

// MARK: - Day cell

private struct DayCell: View {
    let day: Int
    let hasWorkout: Bool
    let hasMeals: Bool
    let isToday: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                Text("\(day)")
                    .font(.system(size: 13, weight: hasWorkout ? .heavy : .medium))
                    .foregroundStyle(hasWorkout ? Theme.textPrimary : Theme.textSecondary)
                HStack(spacing: 3) {
                    if hasWorkout {
                        Circle().fill(Theme.accent).frame(width: 6, height: 6)
                    }
                    if hasMeals {
                        Circle().fill(Theme.success).frame(width: 6, height: 6)
                    }
                    if !hasWorkout && !hasMeals {
                        Color.clear.frame(height: 6)
                    }
                }
                .frame(height: 6)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isToday ? Theme.accent.opacity(0.15) : (hasWorkout || hasMeals ? Theme.accent.opacity(0.06) : Color.clear))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(isToday ? Theme.accent.opacity(0.5) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .accessibilityLabel("Day \(day), \(hasWorkout ? "workout logged" : "no workout"), \(hasMeals ? "meal plan available" : "no meal plan")")
    }
}

// MARK: - Day detail sheet (workouts + meals)

private struct DayDetailSheet: View {
    let dayComponents: DateComponents
    let sessions: [WorkoutSession]
    let appState: AppState
    @Environment(HealthKitManager.self) private var healthKit
    @Environment(\.dismiss) private var dismiss

    private let calendar = Calendar.current

    @State private var healthSummary: HealthDaySummary?
    @State private var isLoadingHealth: Bool = false
    @State private var showQuickWorkout: Bool = false

    private var usesMetric: Bool { appState.profile?.usesMetric ?? false }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if healthKit.isAuthorized {
                    healthSection
                }
                workoutsSection
                mealsSection
                foodLogSection
                Button("Done") { dismiss() }
                    .buttonStyle(SecondaryButtonStyle())
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
        }
        .scrollIndicators(.hidden)
        .background(Theme.bg)
        .task {
            if healthKit.isAuthorized {
                await loadHealthSummary()
            }
        }
    }

    private func loadHealthSummary() async {
        guard let date = calendar.date(from: dayComponents) else { return }
        isLoadingHealth = true
        defer { isLoadingHealth = false }
        do {
            healthSummary = try await healthKit.fetchDaySummary(on: date)
        } catch {
            healthSummary = nil
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let date = calendar.date(from: dayComponents) {
                Text(date.formatted(date: .long, time: .omitted))
                    .font(.displayFont(24))
                    .foregroundStyle(Theme.textPrimary)
                HStack(spacing: 10) {
                    Label("\(sessions.count) workout\(sessions.count == 1 ? "" : "s")", systemImage: "barbell.fill")
                    if appState.hasNutrition && appState.hasNutritionPreferences {
                        Label("Meal plan", systemImage: "fork.knife")
                    }
                }
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    // MARK: - Apple Health stats

    private var healthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(red: 244/255, green: 63/255, blue: 94/255))
                SectionHeader(title: "Apple Health", icon: "")
                Spacer()
                Text("From Health app")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
            }

            if isLoadingHealth {
                HStack(spacing: 10) {
                    ProgressView().tint(Theme.accent).scaleEffect(0.8)
                    Text("Syncing from Apple Health…")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
            } else if let summary = healthSummary {
                HStack(spacing: 10) {
                    healthStatTile(
                        value: "\(summary.steps.formatted())",
                        label: "Steps",
                        icon: "figure.walk",
                        color: Theme.accent
                    )
                    healthStatTile(
                        value: "\(summary.activeCalories)",
                        label: "Active kcal",
                        icon: "flame.fill",
                        color: Theme.warning
                    )
                    if let weight = summary.bodyMassKg {
                        healthStatTile(
                            value: "\(Int(weight.rounded()))",
                            label: "Weight kg",
                            icon: "scalemass.fill",
                            color: Theme.success
                        )
                    } else {
                        healthStatTile(
                            value: "—",
                            label: "Weight kg",
                            icon: "scalemass.fill",
                            color: Theme.textTertiary
                        )
                    }
                }
            } else {
                Text("No Health data for this day.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.vertical, 10)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 244/255, green: 63/255, blue: 94/255).opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color(red: 244/255, green: 63/255, blue: 94/255).opacity(0.15), lineWidth: 1)
                )
        )
    }

    private func healthStatTile(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(1)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
    }

    private var workoutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "Workouts", icon: "barbell.fill", tint: Theme.accent)
                Spacer()
                Button {
                    Haptics.impact(.light)
                    showQuickWorkout = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                        Text("Log workout")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(Theme.accent)
                }
            }
            if sessions.isEmpty {
                Text("No workout logged this day. Tap \"Log workout\" to add one.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 10) {
                    ForEach(sessions) { session in
                        workoutSessionCard(session)
                    }
                }
            }
        }
    }

    private var mealsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Meals", icon: "fork.knife", tint: Theme.accent)
            if !appState.hasNutrition || !appState.hasNutritionPreferences {
                VStack(spacing: 10) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.accent.opacity(0.7))
                    Text(appState.hasNutritionPreferences ? "Unlock Nutrition to see your meal plan." : "Complete your food survey to see what you ate this day.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .blueprintCard()
            } else if let prefs = appState.nutritionPreferences, let date = calendar.date(from: dayComponents) {
                let weekIndex = (calendar.component(.weekday, from: date) + 5) % 7 // Mon=0
                let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
                let plan = MealPlanGenerator.generateDay(prefs: prefs, dayName: dayNames[weekIndex], dayIndex: weekIndex)
                VStack(spacing: 10) {
                    HStack {
                        Text(dayNames[weekIndex])
                            .font(.system(size: 11, weight: .black))
                            .tracking(2)
                            .foregroundStyle(Theme.accent)
                        Spacer()
                        Text("\(plan.totalCalories) kcal · \(plan.totalProtein)g P")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    ForEach(plan.meals) { meal in
                        MealSummaryCard(meal: meal)
                    }
                }
            }
        }
    }

    // MARK: - Food log for this day

    @State private var showAddFoodForDay: Bool = false

    private var foodLogSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "What you ate", icon: "fork.knife", tint: Theme.success)
                Spacer()
                Button {
                    Haptics.impact(.light)
                    showAddFoodForDay = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.accent)
                }
            }
            let log = appState.foodLog(for: calendar.date(from: dayComponents) ?? Date())
            if log.entries.isEmpty {
                Text("Nothing logged this day. Tap + to add what you ate.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 10) {
                    HStack(spacing: 16) {
                        Label("\(log.totalCalories)", systemImage: "flame.fill")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.accent)
                        Label("\(log.totalProtein)g P", systemImage: "figure.strengthtraining.traditional")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.success)
                        Label("\(log.totalCarbs)g C", systemImage: "leaf.fill")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.warning)
                        Label("\(log.totalFat)g F", systemImage: "drop.fill")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.purple)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Theme.accent.opacity(0.06))
                    )

                    ForEach(log.entriesBySlot(), id: \.0) { slot, entries in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(slot.display.uppercased())
                                .font(.system(size: 10, weight: .black))
                                .tracking(2)
                                .foregroundStyle(Theme.textSecondary)
                            ForEach(entries) { entry in
                                HStack(spacing: 10) {
                                    Text(entry.emoji).font(.system(size: 18))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.name)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(Theme.textPrimary)
                                            .lineLimit(2)
                                        Text("\(entry.calories) kcal · \(entry.proteinGrams)g P")
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                    Spacer()
                                    Button {
                                        Haptics.impact(.light)
                                        appState.removeFoodEntry(id: entry.id, on: calendar.date(from: dayComponents) ?? Date())
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundStyle(Theme.warning.opacity(0.8))
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAddFoodForDay) {
            AddFoodSheet(date: calendar.date(from: dayComponents) ?? Date())
        }
        .sheet(isPresented: $showQuickWorkout) {
            QuickWorkoutSheet(date: calendar.date(from: dayComponents) ?? Date())
        }
    }

    private func workoutSessionCard(_ log: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(log.customTitle ?? "Week \(log.weekNumber) · Day \(log.dayIndex + 1)")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if log.isDeload {
                    Text("DELOAD")
                        .font(.system(size: 9, weight: .black))
                        .tracking(1)
                        .foregroundStyle(Theme.success)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Theme.success.opacity(0.15)))
                }
            }
            VStack(spacing: 6) {
                ForEach(Array(log.exercises.enumerated()), id: \.offset) { _, exercise in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(exercise.exerciseName)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            if let best = exercise.bestSet {
                                Text("Best: \(WeightFormatter.display(best.weightKg, usesMetric: usesMetric)) × \(best.reps)")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                        ForEach(Array(exercise.sets.enumerated()), id: \.offset) { idx, set in
                            HStack(spacing: 8) {
                                Text("Set \(idx + 1)")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Theme.textSecondary)
                                    .frame(width: 44, alignment: .leading)
                                Text(set.completed ? WeightFormatter.display(set.weightKg, usesMetric: usesMetric) : "—")
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(Theme.textPrimary)
                                    .frame(width: 80, alignment: .leading)
                                Text("× \(set.reps)")
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 14))
                                    .foregroundStyle(set.completed ? Theme.success : Theme.textTertiary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            HStack(spacing: 10) {
                Label(WeightFormatter.volume(log.totalVolume, usesMetric: usesMetric), systemImage: "barbell.fill")
                Label("\(log.estimatedMinutes) min", systemImage: "clock.fill")
            }
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(Theme.textSecondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.surfaceHi.opacity(0.6))
        )
    }
}

// MARK: - Meal summary card (compact)

private struct MealSummaryCard: View {
    let meal: MealPlanEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(meal.mealName.uppercased())
                        .font(.system(size: 10, weight: .black))
                        .tracking(2)
                        .foregroundStyle(Theme.accent)
                    Text(meal.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Text(meal.time)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            Text(meal.items.joined(separator: " · "))
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(2)
            HStack(spacing: 12) {
                macroPill("\(meal.calories)", "kcal")
                macroPill("\(meal.proteinGrams)g", "P")
                macroPill("\(meal.carbsGrams)g", "C")
                macroPill("\(meal.fatGrams)g", "F")
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                )
        )
    }

    private func macroPill(_ value: String, _ label: String) -> some View {
        HStack(spacing: 3) {
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Theme.bg))
    }
}

// MARK: - Session row

private struct SessionRow: View {
    let session: WorkoutSession
    let usesMetric: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(session.date.formatted(.dateTime.day()))
                    .font(.system(size: 18, weight: .black, design: .rounded))
                Text(session.date.formatted(.dateTime.month(.abbreviated)).uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(width: 42)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.accent.opacity(0.1))
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(session.customTitle ?? "Week \(session.weekNumber) · Day \(session.dayIndex + 1)")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Theme.textSecondary)
                    if session.isFinished {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.success)
                    }
                    if session.isDeload {
                        Text("DELOAD")
                            .font(.system(size: 9, weight: .black))
                            .tracking(1)
                            .foregroundStyle(Theme.success)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Theme.success.opacity(0.15)))
                    }
                }
                Text(session.exercises.map { $0.exerciseName }.prefix(3).joined(separator: " · "))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 10) {
                    Label(WeightFormatter.volume(session.totalVolume, usesMetric: usesMetric), systemImage: "barbell.fill")
                    Label("\(session.estimatedMinutes) min", systemImage: "clock.fill")
                }
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(12)
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

// MARK: - Session detail

private struct SessionDetailSheet: View {
    let session: WorkoutSession
    let usesMetric: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(session.customTitle ?? "Week \(session.weekNumber) · Day \(session.dayIndex + 1)")
                        .font(.system(size: 12, weight: .black))
                        .tracking(2)
                        .foregroundStyle(Theme.accent)
                    Text(session.date.formatted(date: .long, time: .omitted))
                        .font(.displayFont(24))
                        .foregroundStyle(Theme.textPrimary)
                    HStack(spacing: 10) {
                        Label(WeightFormatter.volume(session.totalVolume, usesMetric: usesMetric), systemImage: "barbell.fill")
                        Label("\(session.estimatedMinutes) min", systemImage: "clock.fill")
                        if session.isDeload { Label("Deload", systemImage: "leaf.fill") }
                    }
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
                }
                .padding(.top, 22)

                ForEach(session.exercises) { log in
                    ExerciseLogCard(log: log, usesMetric: usesMetric)
                }

                Button("Done") { dismiss() }
                    .buttonStyle(SecondaryButtonStyle())
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 22)
        }
        .scrollIndicators(.hidden)
        .background(Theme.bg)
    }
}

private struct ExerciseLogCard: View {
    let log: ExerciseLog
    let usesMetric: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(log.exerciseName)
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if let best = log.bestSet {
                    Text("Best: \(WeightFormatter.display(best.weightKg, usesMetric: usesMetric)) × \(best.reps)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.accent)
                }
            }
            VStack(spacing: 6) {
                ForEach(Array(log.sets.enumerated()), id: \.offset) { idx, set in
                    HStack {
                        Text("Set \(idx + 1)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 50, alignment: .leading)
                        Text(set.completed ? WeightFormatter.display(set.weightKg, usesMetric: usesMetric) : "—")
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Theme.textPrimary)
                            .frame(width: 80, alignment: .leading)
                        Text("× \(set.reps)")
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 16))
                            .foregroundStyle(set.completed ? Theme.success : Theme.textTertiary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.surfaceHi.opacity(0.6))
        )
    }
}

// MARK: - Stat card

private struct StatCard: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Theme.accent)
            Text(value)
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(1)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .blueprintCard()
    }
}
