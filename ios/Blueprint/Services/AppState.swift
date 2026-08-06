import Foundation
import SwiftUI

/// Central app state: profile, goal, scans, weekly progress, subscription.
/// Persists everything as JSON in the app's Documents directory (on-device only).
@Observable
final class AppState {
    var profile: UserProfile?
    var target: TargetReference?
    var scans: [Scan] = []
    var progressLogs: [ProgressLog] = []
    var meta: AppMeta = AppMeta()

    /// Unified subscription state (workouts / nutrition / everything).
    var subscription: SubscriptionState = .free
    var nutritionPreferences: NutritionPreferences?

    /// Logged workout sessions (weight/reps per set) keyed by week + day.
    var workoutSessions: [WorkoutSession] = []

    /// Food log entries keyed by "yyyy-MM-dd".
    var foodLogs: [String: DailyFoodLog] = [:]

    /// Recovery state per muscle group, derived from workout sessions.
    var muscleRecovery: [MuscleRecovery] = []

    /// Presented globally when locked content is tapped.
    var showPaywall: Bool = false

    /// Reference to the HealthKit manager, set at app launch so food entries
    /// can be pushed to Apple Health when connected.
    weak var healthKit: HealthKitManager?

    private let fileManager = FileManager.default

    init() {
        load()
        expireTrialIfNeeded()
    }

    // MARK: - Derived state

    /// True if the user has access to the Workouts tier (via subscription or trial).
    var hasWorkoutsAccess: Bool {
        subscription.hasAccess(to: .workouts)
    }

    /// Backward-compat alias.
    var isPro: Bool { hasWorkoutsAccess }

    /// True if the user has access to the Nutrition tier.
    var hasNutritionAccess: Bool {
        subscription.hasAccess(to: .nutrition)
    }

    /// Backward-compat alias.
    var hasNutrition: Bool { hasNutritionAccess }

    var trialDaysLeft: Int? {
        if case .trial(_, let expires) = subscription {
            let secs = expires.timeIntervalSince(Date())
            return max(0, Int(ceil(secs / 86400)))
        }
        return nil
    }

    var hasNutritionPreferences: Bool {
        nutritionPreferences != nil
    }

    var latestScan: Scan? {
        scans.max(by: { $0.date < $1.date })
    }

    var latestAnalysis: AnalysisResult? {
        latestScan?.analysis
    }

    var weeksCompleted: Int {
        progressLogs.filter { $0.completed }.count
    }

    var currentWeek: Int {
        weeksCompleted + 1
    }

    /// Consecutive completed weeks counting back from the most recent log.
    var streakWeeks: Int {
        var streak = 0
        for log in progressLogs.sorted(by: { $0.weekNumber > $1.weekNumber }) {
            if log.completed {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    var canStartNewScan: Bool {
        scans.isEmpty || hasWorkoutsAccess
    }

    var rescanDue: Bool {
        guard !scans.isEmpty else { return false }
        return weeksCompleted - meta.lastScanWeek >= 4
    }

    /// Progress (0-1) through the current 4-week cycle toward the next scan.
    var cycleProgress: Double {
        let done = weeksCompleted - meta.lastScanWeek
        return min(1, max(0, Double(done) / 4))
    }

    /// Rough estimate of weeks remaining to close the gap to the goal physique.
    /// Derived from the latest scan's gap priorities and training days per week.
    var estimatedWeeksToGoal: Int? {
        guard let analysis = latestAnalysis else { return nil }
        guard let profile = profile else { return nil }
        guard !analysis.gapToGoal.isEmpty else { return 0 }

        let maxPriority = analysis.gapToGoal.map { $0.priority.value }.max() ?? 1
        let gapItems = analysis.gapToGoal.count
        let gapScore = Double(maxPriority) + Double(gapItems) * 0.5
        let baseWeeks = gapScore * 4.0
        let frequencyFactor = 4.0 / Double(max(profile.daysPerWeek, 2))
        let experienceFactor: Double
        switch profile.experience {
        case .beginner: experienceFactor = 0.9
        case .intermediate: experienceFactor = 1.0
        case .advanced: experienceFactor = 1.15
        }
        let weeks = baseWeeks * frequencyFactor * experienceFactor
        let remaining = max(0, Int(weeks.rounded()) - weeksCompleted)
        return remaining
    }

    /// Estimated calendar date when the user will reach their goal, if a projection exists.
    var estimatedGoalDate: Date? {
        guard let weeks = estimatedWeeksToGoal else { return nil }
        return Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: Date())
    }

    /// Progress (0-1) toward the goal based on weeks completed vs. estimated total.
    var goalProgress: Double {
        guard let weeks = estimatedWeeksToGoal else { return 0 }
        let total = weeks + weeksCompleted
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(weeksCompleted) / Double(total)))
    }

    // MARK: - Actions

    func saveProfile(_ newProfile: UserProfile) {
        profile = newProfile
        persist(newProfile, to: "profile.json")
    }

    func saveTarget(_ newTarget: TargetReference?) {
        if let old = target, newTarget?.id != old.id {
            // Intentionally keep old files if images are reused; orphan cleanup below.
        }
        target = newTarget
        if let newTarget {
            persist(newTarget, to: "target.json")
        } else {
            deleteFile("target.json")
        }
    }

    func addScan(_ scan: Scan) {
        var stamped = scan
        stamped.weekTaken = weeksCompleted
        scans.append(stamped)
        meta.lastScanWeek = weeksCompleted
        persistScans()
        persistMeta()
    }

    func deleteScan(_ scan: Scan) {
        for name in scan.frameFileNames {
            ImageStore.delete(name)
        }
        scans.removeAll { $0.id == scan.id }
        persistScans()
    }

    func completeCurrentWeek() {
        let log = ProgressLog(weekNumber: currentWeek, completed: true, date: Date())
        progressLogs.append(log)
        persist(progressLogs, to: "progress.json")
    }

    // MARK: - Workout logging

    /// Find a session for the current week + day index, or nil if none started.
    func sessionFor(week: Int, dayIndex: Int) -> WorkoutSession? {
        workoutSessions.first { $0.weekNumber == week && $0.dayIndex == dayIndex }
    }

    /// Find the most recent completed session for a given day index (any prior week).
    func lastSessionForDayIndex(_ dayIndex: Int) -> WorkoutSession? {
        workoutSessions
            .filter { $0.dayIndex == dayIndex && $0.isFinished }
            .sorted { $0.weekNumber > $1.weekNumber }
            .first
    }

    /// Find the most recent logged set for an exercise name (across all sessions).
    func lastLoggedSet(forExercise name: String) -> WorkoutSet? {
        let allSets = workoutSessions
            .sorted { $0.weekNumber > $1.weekNumber }
            .flatMap { $0.exercises }
            .filter { $0.exerciseName == name }
            .flatMap { $0.sets.filter { $0.completed } }
        return allSets.first
    }

    /// Upsert a workout session for the current week + day, replacing any existing.
    func saveSession(_ session: WorkoutSession) {
        // Detect PRs before saving (compare against previous bests)
        let prs = detectPRs(in: session)
        if let idx = workoutSessions.firstIndex(where: { $0.weekNumber == session.weekNumber && $0.dayIndex == session.dayIndex }) {
            workoutSessions[idx] = session
        } else {
            workoutSessions.append(session)
        }
        persist(workoutSessions, to: "workout_sessions.json")
        recomputeMuscleRecovery()
        // Fire PR notifications
        if let prefs = meta.notificationPrefs, prefs.newPR, prefs.hasAuthorized {
            for pr in prs {
                let usesMetric = profile?.usesMetric ?? false
                NotificationService.shared.sendPRCelebration(
                    exercise: pr.exercise,
                    weightKg: pr.weightKg,
                    reps: pr.reps,
                    usesMetric: usesMetric
                )
            }
        }
    }

    /// Detected personal records for a session being saved.
    private struct DetectedPR {
        let exercise: String
        let weightKg: Double
        let reps: Int
    }

    /// Compares each exercise's best set against the prior best across all existing sessions.
    private func detectPRs(in newSession: WorkoutSession) -> [DetectedPR] {
        var prs: [DetectedPR] = []
        for exercise in newSession.exercises {
            guard let newBest = exercise.bestSet else { continue }
            // Find prior best across all existing sessions (excluding the one being saved)
            let priorBest = workoutSessions
                .filter { !($0.weekNumber == newSession.weekNumber && $0.dayIndex == newSession.dayIndex) }
                .flatMap { $0.exercises }
                .filter { $0.exerciseName == exercise.exerciseName }
                .compactMap { $0.bestSet }
                .max(by: { $0.weightKg < $1.weightKg })
            if let prior = priorBest, newBest.weightKg > prior.weightKg + 0.01 {
                prs.append(DetectedPR(exercise: exercise.exerciseName, weightKg: newBest.weightKg, reps: newBest.reps))
            } else if priorBest == nil && newBest.weightKg > 0 {
                // First time logging this exercise — not a PR, skip
            }
        }
        return prs
    }

    /// Delete a workout session.
    func deleteSession(_ session: WorkoutSession) {
        workoutSessions.removeAll { $0.id == session.id }
        persist(workoutSessions, to: "workout_sessions.json")
        recomputeMuscleRecovery()
    }

    // MARK: - Food logging

    /// Date key for a Date -> "yyyy-MM-dd".
    func foodLogKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }

    /// Today's food log, or an empty one.
    func todaysFoodLog() -> DailyFoodLog {
        let key = foodLogKey(for: Date())
        return foodLogs[key] ?? DailyFoodLog(dateKey: key, entries: [])
    }

    /// Food log for a specific date.
    func foodLog(for date: Date) -> DailyFoodLog {
        let key = foodLogKey(for: date)
        return foodLogs[key] ?? DailyFoodLog(dateKey: key, entries: [])
    }

    /// Add a food entry to a specific date's log.
    /// Also writes the nutrition data to Apple Health if connected.
    func addFoodEntry(_ entry: FoodLogEntry, on date: Date = Date()) {
        let key = foodLogKey(for: date)
        var log = foodLogs[key] ?? DailyFoodLog(dateKey: key, entries: [])
        log.entries.append(entry)
        foodLogs[key] = log
        persistFoodLogs()
        // Push to Apple Health in the background (no-op if not connected)
        Task { @MainActor in
            await healthKit?.writeNutritionEntry(
                name: entry.name,
                calories: entry.calories,
                proteinGrams: entry.proteinGrams,
                carbsGrams: entry.carbsGrams,
                fatGrams: entry.fatGrams,
                date: entry.loggedAt
            )
        }
    }

    /// Remove a food entry by id from a specific date's log.
    func removeFoodEntry(id: UUID, on date: Date = Date()) {
        let key = foodLogKey(for: date)
        guard var log = foodLogs[key] else { return }
        log.entries.removeAll { $0.id == id }
        foodLogs[key] = log
        persistFoodLogs()
    }

    /// Replace a food entry (edit) on a specific date.
    func updateFoodEntry(_ entry: FoodLogEntry, on date: Date = Date()) {
        let key = foodLogKey(for: date)
        guard var log = foodLogs[key] else { return }
        if let idx = log.entries.firstIndex(where: { $0.id == entry.id }) {
            log.entries[idx] = entry
            foodLogs[key] = log
            persistFoodLogs()
        }
    }

    /// All entries logged today, sorted by slot then time.
    func todaysEntries() -> [FoodLogEntry] {
        todaysFoodLog().entries.sorted {
            if $0.mealSlot.sortOrder != $1.mealSlot.sortOrder {
                return $0.mealSlot.sortOrder < $1.mealSlot.sortOrder
            }
            return $0.loggedAt < $1.loggedAt
        }
    }

    /// Macro totals for today.
    var todaysCalories: Int { todaysFoodLog().totalCalories }
    var todaysProtein: Int { todaysFoodLog().totalProtein }
    var todaysCarbs: Int { todaysFoodLog().totalCarbs }
    var todaysFat: Int { todaysFoodLog().totalFat }

    private func persistFoodLogs() {
        persist(foodLogs, to: "food_logs.json")
    }

    // MARK: - Recovery tracking

    /// Recompute muscle recovery state from all workout sessions.
    /// Called automatically when sessions are saved/deleted.
    func recomputeMuscleRecovery() {
        var latestByMuscle: [MuscleGroup: Date] = [:]
        for session in workoutSessions where session.isFinished {
            for exercise in session.exercises where exercise.isComplete {
                let muscles = ExerciseMuscleMap.muscles(for: exercise.exerciseName)
                for muscle in muscles {
                    if let existing = latestByMuscle[muscle] {
                        if session.date > existing { latestByMuscle[muscle] = session.date }
                    } else {
                        latestByMuscle[muscle] = session.date
                    }
                }
            }
        }
        muscleRecovery = latestByMuscle.map { muscle, date in
            let recoversBy = date.addingTimeInterval(TimeInterval(muscle.recoveryHours * 3600))
            return MuscleRecovery(muscle: muscle, lastTrained: date, recoversBy: recoversBy)
        }.sorted { $0.muscle.rawValue < $1.muscle.rawValue }
        persist(muscleRecovery, to: "muscle_recovery.json")
    }

    /// Recovery status for a specific muscle group (nil if never trained).
    func recovery(for muscle: MuscleGroup) -> MuscleRecovery? {
        muscleRecovery.first { $0.muscle == muscle }
    }

    /// Muscles that are still recovering (not yet ready to train hard).
    var recoveringMuscles: [MuscleRecovery] {
        muscleRecovery.filter { !$0.isRecovered }.sorted { $0.hoursRemaining > $1.hoursRemaining }
    }

    /// Muscles that are fully recovered and ready to train.
    var readyMuscles: [MuscleRecovery] {
        muscleRecovery.filter { $0.isRecovered }
    }

    /// Returns muscle groups targeted in the last 48 hours (still recovering).
    var recentlyTrainedMuscles: [MuscleGroup] {
        muscleRecovery.filter { !$0.isRecovered }.map { $0.muscle }
    }

    // MARK: - Weekly progression

    /// True when the current week is a deload week (every 4th week).
    var isCurrentWeekDeload: Bool {
        currentWeek > 0 && currentWeek % 4 == 0
    }

    /// Progression multiplier applied to reps when generating a new week's plan.
    /// Week 1 = baseline. Weeks 2-3: +1 rep. Deload week: -40% volume (fewer sets).
    func progressionForWeek(_ week: Int) -> (repBonus: Int, setScale: Double, isDeload: Bool) {
        if week > 0 && week % 4 == 0 {
            return (repBonus: 0, setScale: 0.6, isDeload: true)
        }
        let cyclesElapsed = week / 4
        let weekInCycle = week % 4
        let repBonus = cyclesElapsed + max(0, weekInCycle - 1)
        return (repBonus: repBonus, setScale: 1.0, isDeload: false)
    }

    /// Build a progression summary describing what changed vs the prior week.
    func weekProgression(forWeek week: Int) -> WeekProgression {
        let prog = progressionForWeek(week)
        var changes: [String] = []
        if prog.isDeload {
            changes.append("Deload week — 40% less volume to recover.")
            changes.append("Keep weights the same, fewer sets.")
            return WeekProgression(weekNumber: week, isDeload: true, changes: changes)
        }
        if prog.repBonus > 0 {
            changes.append("+\(prog.repBonus) rep on main lifts")
        }
        if let lastWeekSession = workoutSessions.filter({ $0.weekNumber == week - 1 && $0.isFinished }).first {
            let priorWeek = workoutSessions.filter { $0.weekNumber == week - 2 && $0.isFinished }.first
            for ex in lastWeekSession.exercises {
                if let best = ex.bestSet {
                    let priorBest = priorWeek?.exercises.first(where: { $0.exerciseName == ex.exerciseName })?.bestSet
                    if let prior = priorBest {
                        let delta = best.weightKg - prior.weightKg
                        if abs(delta) > 0.01 {
                            let sign = delta > 0 ? "+" : ""
                            changes.append("\(ex.exerciseName): \(sign)\(String(format: "%.1f", delta)) kg")
                        }
                    } else {
                        changes.append("\(ex.exerciseName): \(String(format: "%.1f", best.weightKg)) kg baseline")
                    }
                }
            }
        }
        if changes.isEmpty {
            changes.append("Same as last week — focus on form.")
        }
        return WeekProgression(weekNumber: week, isDeload: false, changes: changes)
    }

    /// Derived plan for the current week with progression applied to reps/sets.
    func currentWeekPlanDays() -> [WorkoutDay]? {
        guard let plan = latestAnalysis?.plan else { return nil }
        let prog = progressionForWeek(currentWeek)
        return plan.days.enumerated().map { index, day in
            let scaledSetCount = max(1, Int(Double(day.exercises.count > 0 ? day.exercises[0].sets.value : 3) * prog.setScale))
            let exercises = day.exercises.map { exercise in
                var ex = exercise
                let bumpedReps = bumpReps(exercise.reps.value, by: prog.repBonus)
                ex = Exercise(
                    name: exercise.name,
                    sets: FlexInt(prog.isDeload ? scaledSetCount : exercise.sets.value),
                    reps: FlexString(bumpedReps),
                    restSec: exercise.restSec,
                    why: exercise.why,
                    alt: exercise.alt,
                    cues: exercise.cues
                )
                return ex
            }
            return WorkoutDay(day: day.day, targets: day.targets, exercises: exercises)
        }
    }

    /// Increase the rep range by a bonus, preserving the format ("8" -> "9", "8-12" -> "9-13").
    private func bumpReps(_ reps: String, by bonus: Int) -> String {
        if bonus == 0 { return reps }
        let parts = reps.split(separator: "-").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        if parts.count == 2 {
            return "\(parts[0] + bonus)-\(parts[1] + bonus)"
        } else if parts.count == 1 {
            return "\(parts[0] + bonus)"
        }
        return reps
    }

    /// All sessions in a given calendar month, for the calendar view.
    func sessionsInMonth(_ month: DateInterval) -> [WorkoutSession] {
        workoutSessions.filter { month.contains($0.date) }.sorted { $0.date < $1.date }
    }

    /// Total sessions completed (finished) all-time.
    var totalSessionsCompleted: Int {
        workoutSessions.filter { $0.isFinished }.count
    }

    func isExerciseSwapped(_ key: String) -> Bool {
        meta.swappedExerciseKeys.contains(key)
    }

    func toggleExerciseSwap(_ key: String) {
        if meta.swappedExerciseKeys.contains(key) {
            meta.swappedExerciseKeys.remove(key)
        } else {
            meta.swappedExerciseKeys.insert(key)
        }
        persistMeta()
    }

    func markPaywallSeen() {
        meta.hasSeenPaywall = true
        persistMeta()
    }

    // MARK: - Rest timer preference

    /// Whether the user wants the between-set rest timer. nil = not yet asked.
    var restTimerPreference: Bool? {
        meta.restTimerEnabled
    }

    /// True only when the user has explicitly opted in.
    var restTimerEnabled: Bool {
        meta.restTimerEnabled == true
    }

    /// True the first time we should prompt the user to opt in.
    var shouldPromptForRestTimer: Bool {
        meta.restTimerEnabled == nil
    }

    func setRestTimerPreference(_ enabled: Bool) {
        meta.restTimerEnabled = enabled
        persistMeta()
    }

    // MARK: - Notification preferences

    /// Current notification preferences (nil if not yet set up).
    var notificationPrefs: NotificationPrefs? {
        meta.notificationPrefs
    }

    /// True the first time we should prompt the user to enable notifications.
    var shouldPromptForNotifications: Bool {
        meta.notificationPrefs == nil
    }

    /// Save notification preferences and reschedule all notifications.
    func setNotificationPrefs(_ prefs: NotificationPrefs) {
        meta.notificationPrefs = prefs
        persistMeta()
        NotificationService.shared.rescheduleAll(appState: self)
    }

    /// Enable notifications with default prefs after user grants permission.
    func enableNotifications() {
        var prefs = meta.notificationPrefs ?? NotificationPrefs()
        prefs.hasAuthorized = true
        meta.notificationPrefs = prefs
        persistMeta()
        NotificationService.shared.rescheduleAll(appState: self)
    }

    /// Disable all notifications.
    func disableNotifications() {
        NotificationService.shared.cancelAll()
        if var prefs = meta.notificationPrefs {
            prefs.hasAuthorized = false
            meta.notificationPrefs = prefs
            persistMeta()
        }
    }

    /// Update a single notification type toggle.
    func setNotificationToggle(_ type: NotificationToggleType, enabled: Bool) {
        var prefs = meta.notificationPrefs ?? NotificationPrefs()
        switch type {
        case .streakProtection: prefs.streakProtection = enabled
        case .workoutReminder: prefs.workoutReminder = enabled
        case .rescanReminder: prefs.rescanReminder = enabled
        case .mealLogging: prefs.mealLogging = enabled
        case .recoveryReady: prefs.recoveryReady = enabled
        case .weeklySummary: prefs.weeklySummary = enabled
        case .inactivityNudge: prefs.inactivityNudge = enabled
        case .newPR: prefs.newPR = enabled
        }
        meta.notificationPrefs = prefs
        persistMeta()
        NotificationService.shared.rescheduleAll(appState: self)
    }

    // MARK: - Subscription (StoreKit 2 backed, with local fallback)

    /// Syncs subscription state from StoreKit 2 via StoreManager.
    /// Called on app launch and after successful purchases/restores.
    func syncFromStoreKit(_ store: StoreManager) {
        if let tier = store.currentTier {
            if store.isInTrial {
                let expires = store.expirationDate ?? Date().addingTimeInterval(7 * 86400)
                subscription = .trial(tier: tier, expires: expires)
            } else {
                subscription = .subscribed(tier: tier)
            }
        } else {
            // No active StoreKit entitlement — only keep local trial if still valid
            if case .trial(_, let expires) = subscription, expires > Date() {
                // Local trial still valid, keep it
            } else {
                subscription = .free
            }
        }
        persist(subscription, to: "subscription.json")
        if var current = profile {
            current.subscriptionStatus = subscription
            saveProfile(current)
        }
    }

    func startTrial(tier: SubscriptionTier = .everything) {
        let expires = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        subscription = .trial(tier: tier, expires: expires)
        persist(subscription, to: "subscription.json")
        if var current = profile {
            current.subscriptionStatus = subscription
            saveProfile(current)
        }
    }

    func subscribe(tier: SubscriptionTier) {
        subscription = .subscribed(tier: tier)
        persist(subscription, to: "subscription.json")
        if var current = profile {
            current.subscriptionStatus = subscription
            saveProfile(current)
        }
    }

    func cancelSubscription() {
        subscription = .free
        persist(subscription, to: "subscription.json")
        if var current = profile {
            current.subscriptionStatus = .free
            saveProfile(current)
        }
    }

    private func expireTrialIfNeeded() {
        if case .trial(_, let expires) = subscription, expires <= Date() {
            subscription = .free
            persist(subscription, to: "subscription.json")
        }
    }

    // MARK: - Privacy

    func deleteAllData() {
        ImageStore.deleteAll()
        NotificationService.shared.cancelAll()
        for name in ["profile.json", "target.json", "scans.json", "progress.json", "meta.json", "subscription.json", "nutrition_prefs.json", "workout_sessions.json", "food_logs.json", "muscle_recovery.json"] {
            deleteFile(name)
        }
        profile = nil
        target = nil
        scans = []
        progressLogs = []
        meta = AppMeta()
        subscription = .free
        nutritionPreferences = nil
        workoutSessions = []
        foodLogs = [:]
        muscleRecovery = []
    }

    /// Human-readable JSON export of all non-image data.
    func exportDataJSON() -> String {
        struct Export: Codable {
            let profile: UserProfile?
            let scans: [Scan]
            let progressLogs: [ProgressLog]
            let workoutSessions: [WorkoutSession]
            let foodLogs: [String: DailyFoodLog]
            let muscleRecovery: [MuscleRecovery]
            let exportedAt: Date
        }
        let export = Export(profile: profile, scans: scans, progressLogs: progressLogs, workoutSessions: workoutSessions, foodLogs: foodLogs, muscleRecovery: muscleRecovery, exportedAt: Date())
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(export), let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    // MARK: - Persistence

    private var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func persist<T: Encodable>(_ value: T, to fileName: String) {
        let url = documentsURL.appendingPathComponent(fileName)
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(value)
            try data.write(to: url, options: [.atomic, .completeFileProtection])
        } catch {
            print("[AppState] Persist \(fileName) failed: \(error.localizedDescription)")
        }
    }

    func persistScans() {
        persist(scans, to: "scans.json")
    }

    func persistMeta() {
        persist(meta, to: "meta.json")
    }

    private func loadValue<T: Decodable>(_ type: T.Type, from fileName: String) -> T? {
        let url = documentsURL.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(type, from: data)
    }

    private func load() {
        profile = loadValue(UserProfile.self, from: "profile.json")
        target = loadValue(TargetReference.self, from: "target.json")
        scans = loadValue([Scan].self, from: "scans.json") ?? []
        progressLogs = loadValue([ProgressLog].self, from: "progress.json") ?? []
        meta = loadValue(AppMeta.self, from: "meta.json") ?? AppMeta()
        subscription = loadValue(SubscriptionState.self, from: "subscription.json") ?? .free
        // Migrate old nutrition subscription if present
        if subscription == .free {
            let oldNutrition = loadValue(NutritionSubscriptionStatus.self, from: "nutrition_sub.json")
            if let old = oldNutrition, old != .none {
                if case .active = old { subscription = .subscribed(tier: .nutrition) }
                else if case .trial(let expires) = old, expires > Date() { subscription = .trial(tier: .nutrition, expires: expires) }
                persist(subscription, to: "subscription.json")
            }
        }
        // Also migrate old profile-embedded subscription
        if subscription == .free, let p = profile {
            switch p.subscriptionStatus {
            case .subscribed: subscription = p.subscriptionStatus
            case .trial: subscription = p.subscriptionStatus
            case .free: break
            }
        }
        nutritionPreferences = loadValue(NutritionPreferences.self, from: "nutrition_prefs.json")
        workoutSessions = loadValue([WorkoutSession].self, from: "workout_sessions.json") ?? []
        foodLogs = loadValue([String: DailyFoodLog].self, from: "food_logs.json") ?? [:]
        muscleRecovery = loadValue([MuscleRecovery].self, from: "muscle_recovery.json") ?? []
        if muscleRecovery.isEmpty && !workoutSessions.isEmpty {
            recomputeMuscleRecovery()
        }
    }

    private func deleteFile(_ fileName: String) {
        try? fileManager.removeItem(at: documentsURL.appendingPathComponent(fileName))
    }

    // MARK: - Nutrition

    func saveNutritionPreferences(_ prefs: NutritionPreferences) {
        nutritionPreferences = prefs
        persist(prefs, to: "nutrition_prefs.json")
    }
}
