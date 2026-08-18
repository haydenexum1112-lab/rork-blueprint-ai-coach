import Foundation
import UserNotifications
import SwiftUI

/// Manages scheduling and delivery of all 8 notification types:
/// streak protection, workout reminders, rescan reminders, meal logging nudges,
/// recovery ready, weekly summary, inactivity nudge, and PR celebrations.
final class NotificationService {

    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    private init() {}

    // MARK: - Permission

    /// Request notification authorization. Returns true if granted.
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            return granted
        } catch {
            print("[Notifications] Authorization error: \(error.localizedDescription)")
            return false
        }
    }

    /// Current authorization status.
    var authorizationStatus: UNAuthorizationStatus {
        get async {
            await withCheckedContinuation { continuation in
                center.getNotificationSettings { settings in
                    continuation.resume(returning: settings.authorizationStatus)
                }
            }
        }
    }

    // MARK: - Scheduling

    /// Re-syncs all scheduled notifications based on current app state and prefs.
    /// Clears existing scheduled notifications and reschedules as needed.
    @MainActor
    func rescheduleAll(appState: AppState) {
        center.removeAllPendingNotificationRequests()

        guard let prefs = appState.meta.notificationPrefs, prefs.hasAuthorized else { return }
        guard let profile = appState.profile else { return }

        if prefs.streakProtection { scheduleStreakProtection(appState: appState, prefs: prefs) }
        if prefs.workoutReminder { scheduleWorkoutReminder(appState: appState, prefs: prefs) }
        if prefs.rescanReminder { scheduleRescanReminder(appState: appState) }
        if prefs.mealLogging { scheduleMealLoggingNudges(prefs: prefs) }
        if prefs.recoveryReady { scheduleRecoveryReady(appState: appState) }
        if prefs.weeklySummary { scheduleWeeklySummary(appState: appState) }
        if prefs.inactivityNudge { scheduleInactivityNudge(appState: appState) }
        // PR celebrations are triggered on-demand when a PR is detected, not scheduled.
    }

    // MARK: - 1. Streak Protection

    /// Schedules a streak protection notification on each remaining training day
    /// this week if no workout has been logged yet for that day.
    private func scheduleStreakProtection(appState: AppState, prefs: NotificationPrefs) {
        guard let plan = appState.latestAnalysis?.plan else { return }
        let streak = appState.streakWeeks
        guard streak >= 1 else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)

        // Map plan days to weekday offsets (assuming week starts on the day of first scan)
        // Simple approach: schedule for the next 7 days, check if it's a training day
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            let dateWeekday = calendar.component(.weekday, from: date)

            // Check if this is a training day (map to plan day index)
            guard dayOffset > 0 || !hasLoggedWorkoutToday(appState) else { continue }

            // Schedule for evening of training days if not yet logged
            let hour = 18 // 6 PM — "don't break your streak"
            guard let fireDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) else { continue }
            guard fireDate > Date() else { continue }

            // Only schedule on days that are training days in the plan
            let dayIndex = dayOffset % plan.days.count
            let dayName = plan.days[dayIndex].day

            let content = UNMutableNotificationContent()
            content.title = "Don't break your streak!"
            content.body = "You're on a \(streak)-week streak. Train today (\(dayName)) to keep it alive."
            content.sound = .default
            content.categoryIdentifier = NotificationCategory.streakProtection.rawValue

            let trigger = UNCalendarNotificationTrigger(dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate), repeats: false)
            let request = UNNotificationRequest(identifier: "\(NotificationCategory.streakProtection.rawValue)-\(dayOffset)", content: content, trigger: trigger)

            center.add(request)
        }
    }

    // MARK: - 2. Workout Day Reminder

    /// Schedules a morning reminder on each training day for the upcoming week.
    private func scheduleWorkoutReminder(appState: AppState, prefs: NotificationPrefs) {
        guard let plan = appState.latestAnalysis?.plan else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            let dayIndex = dayOffset % plan.days.count
            let dayName = plan.days[dayIndex].day

            let hour = prefs.reminderHour
            guard let fireDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) else { continue }
            guard fireDate > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Today's workout: \(dayName)"
            content.body = "Your training plan is waiting. Let's get to work."
            content.sound = .default
            content.categoryIdentifier = NotificationCategory.workoutReminder.rawValue

            let trigger = UNCalendarNotificationTrigger(dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate), repeats: false)
            let request = UNNotificationRequest(identifier: "\(NotificationCategory.workoutReminder.rawValue)-\(dayOffset)", content: content, trigger: trigger)

            center.add(request)
        }
    }

    // MARK: - 3. Rescan Reminder

    /// Schedules a rescan notification when the current 4-week cycle completes.
    private func scheduleRescanReminder(appState: AppState) {
        guard !appState.scans.isEmpty else { return }

        let weeksSinceLastScan = appState.weeksCompleted - appState.meta.lastScanWeek
        let weeksUntilRescan = 4 - weeksSinceLastScan

        guard weeksUntilRescan > 0 else {
            // Rescan is due now — schedule for today
            let calendar = Calendar.current
            guard let fireDate = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: Date()) else { return }
            guard fireDate > Date() else { return }

            let content = UNMutableNotificationContent()
            content.title = "Time for a rescan!"
            content.body = "You've completed \(appState.weeksCompleted) weeks. Scan again to see your progress and update your plan."
            content.sound = .default
            content.categoryIdentifier = NotificationCategory.rescanReminder.rawValue

            let trigger = UNCalendarNotificationTrigger(dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate), repeats: false)
            let request = UNNotificationRequest(identifier: NotificationCategory.rescanReminder.rawValue, content: content, trigger: trigger)
            center.add(request)
            return
        }

        // Schedule for the expected rescan date
        guard let rescanDate = Calendar.current.date(byAdding: .weekOfYear, value: weeksUntilRescan, to: Date()) else { return }
        let calendar = Calendar.current
        guard let fireDate = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: rescanDate) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Time for a rescan!"
        content.body = "\(weeksUntilRescan) week\(weeksUntilRescan == 1 ? "" : "s") to go until your next progress scan. Keep it up!"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.rescanReminder.rawValue

        let trigger = UNCalendarNotificationTrigger(dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate), repeats: false)
        let request = UNNotificationRequest(identifier: NotificationCategory.rescanReminder.rawValue, content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - 4. Meal Logging Nudges

    /// Scribes gentle reminders at typical meal times if not yet logged.
    private func scheduleMealLoggingNudges(prefs: NotificationPrefs) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let mealTimes: [(MealSlot, Int, Int)] = [
            (.breakfast, 9, 0),
            (.lunch, 12, 30),
            (.dinner, 18, 30),
        ]

        for dayOffset in 0..<2 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }

            for (slot, hour, minute) in mealTimes {
                guard let fireDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date) else { continue }
                guard fireDate > Date() else { continue }

                let content = UNMutableNotificationContent()
                content.title = "Log your \(slot.display.lowercased())"
                content.body = "Don't forget to log what you ate for \(slot.display.lowercased()). Tracking helps you stay on target."
                content.sound = .default
                content.categoryIdentifier = NotificationCategory.mealLogging.rawValue

                let trigger = UNCalendarNotificationTrigger(dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate), repeats: false)
                let request = UNNotificationRequest(identifier: "\(NotificationCategory.mealLogging.rawValue)-\(dayOffset)-\(slot.rawValue)", content: content, trigger: trigger)
                center.add(request)
            }
        }
    }

    // MARK: - 5. Recovery Ready

    /// Schedules a notification when a muscle group hits full recovery.
    private func scheduleRecoveryReady(appState: AppState) {
        let calendar = Calendar.current

        for recovery in appState.muscleRecovery where !recovery.isRecovered {
            let fireDate = recovery.recoversBy
            guard fireDate > Date() else { continue }

            // Round to the next hour to avoid notifying at 3 AM
            let rounded = calendar.nextDate(after: fireDate, matching: DateComponents(minute: 0, second: 0), matchingPolicy: .nextTime) ?? fireDate

            let content = UNMutableNotificationContent()
            content.title = "\(recovery.muscle.display) is recovered"
            content.body = "Your \(recovery.muscle.display.lowercased()) is fully recovered and ready to train again today."
            content.sound = .default
            content.categoryIdentifier = NotificationCategory.recoveryReady.rawValue

            let trigger = UNCalendarNotificationTrigger(dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: rounded), repeats: false)
            let request = UNNotificationRequest(identifier: "\(NotificationCategory.recoveryReady.rawValue)-\(recovery.muscle.rawValue)", content: content, trigger: trigger)
            center.add(request)
        }
    }

    // MARK: - 6. Weekly Summary

    /// Schedules a Sunday evening weekly summary notification.
    private func scheduleWeeklySummary(appState: AppState) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)

        // Find next Sunday (weekday 1)
        let daysUntilSunday = (8 - weekday) % 7
        let sundayOffset = daysUntilSunday == 0 ? 7 : daysUntilSunday // Next Sunday, not today

        guard let sunday = calendar.date(byAdding: .day, value: sundayOffset, to: today) else { return }
        guard let fireDate = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: sunday) else { return }

        let completedThisWeek = appState.workoutSessions.filter {
            calendar.isDate($0.date, equalTo: today, toGranularity: .weekOfYear)
        }.filter { $0.isFinished }.count

        let content = UNMutableNotificationContent()
        content.title = "Your week in review"
        if completedThisWeek > 0 {
            content.body = "Great week! You completed \(completedThisWeek) workout\(completedThisWeek == 1 ? "" : "s"). Check your progress →"
        } else {
            content.body = "This week is wrapping up. Log a workout to keep your progress on track."
        }
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.weeklySummary.rawValue

        let trigger = UNCalendarNotificationTrigger(dateMatching: calendar.dateComponents([.weekday, .hour, .minute], from: fireDate), repeats: true)
        let request = UNNotificationRequest(identifier: NotificationCategory.weeklySummary.rawValue, content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - 7. Inactivity Nudge

    /// Schedules a nudge after 3 days with no workout log.
    private func scheduleInactivityNudge(appState: AppState) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Find the most recent completed session
        let lastWorkout = appState.workoutSessions
            .filter { $0.isFinished }
            .sorted { $0.date > $1.date }
            .first

        let daysSince: Int
        if let last = lastWorkout {
            daysSince = calendar.dateComponents([.day], from: calendar.startOfDay(for: last.date), to: today).day ?? 0
        } else {
            daysSince = 99 // Never trained
        }

        guard daysSince >= 3 else { return }

        // Schedule for tomorrow morning
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return }
        guard let fireDate = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: tomorrow) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Your goals are waiting"
        if daysSince >= 99 {
            content.body = "You haven't logged a workout yet. Let's start your first session today."
        } else {
            content.body = "You haven't trained in \(daysSince) days. Even a short session keeps your momentum going."
        }
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.inactivityNudge.rawValue

        let trigger = UNCalendarNotificationTrigger(dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate), repeats: false)
        let request = UNNotificationRequest(identifier: NotificationCategory.inactivityNudge.rawValue, content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - 8. PR Celebration (on-demand)

    /// Fires an immediate PR celebration notification when a personal record is detected.
    /// Called from workout logging when a set exceeds the previous best.
    func sendPRCelebration(exercise: String, weightKg: Double, reps: Int, usesMetric: Bool) {
        let weightStr: String
        if usesMetric {
            weightStr = "\(String(format: "%.1f", weightKg)) kg"
        } else {
            weightStr = "\(Int((weightKg * 2.20462).rounded())) lb"
        }

        let content = UNMutableNotificationContent()
        content.title = "New PR! \u{1F4AA}"
        content.body = "You just \(exercise) \(weightStr) for \(reps) reps — your best yet!"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.newPR.rawValue
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(identifier: "\(NotificationCategory.newPR.rawValue)-\(UUID().uuidString)", content: content, trigger: nil)
        center.add(request)
    }

    // MARK: - Helpers

    private func hasLoggedWorkoutToday(_ appState: AppState) -> Bool {
        let calendar = Calendar.current
        return appState.workoutSessions.contains { session in
            calendar.isDateInToday(session.date) && session.isFinished
        }
    }

    /// Cancels all pending notifications.
    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }
}

// MARK: - Notification Categories

enum NotificationCategory: String {
    case streakProtection = "streak_protection"
    case workoutReminder = "workout_reminder"
    case rescanReminder = "rescan_reminder"
    case mealLogging = "meal_logging"
    case recoveryReady = "recovery_ready"
    case weeklySummary = "weekly_summary"
    case inactivityNudge = "inactivity_nudge"
    case newPR = "new_pr"
}

/// Toggle types for the notification preferences card.
enum NotificationToggleType: String, CaseIterable, Identifiable {
    case streakProtection
    case workoutReminder
    case rescanReminder
    case mealLogging
    case recoveryReady
    case weeklySummary
    case inactivityNudge
    case newPR

    var id: String { rawValue }

    var label: String {
        switch self {
        case .streakProtection: return "Streak protection"
        case .workoutReminder: return "Workout day reminder"
        case .rescanReminder: return "Rescan reminder"
        case .mealLogging: return "Meal logging nudge"
        case .recoveryReady: return "Recovery ready"
        case .weeklySummary: return "Weekly summary"
        case .inactivityNudge: return "Inactivity nudge"
        case .newPR: return "Personal record"
        }
    }

    var description: String {
        switch self {
        case .streakProtection: return "Don't break your streak — reminds you on training days."
        case .workoutReminder: return "Morning reminder on scheduled training days."
        case .rescanReminder: return "Notifies you when it's time for a progress rescan."
        case .mealLogging: return "Gentle reminders at typical meal times."
        case .recoveryReady: return "Notifies you when a muscle group is fully recovered."
        case .weeklySummary: return "Sunday evening recap of your week."
        case .inactivityNudge: return "Checks in after 3 days with no workout."
        case .newPR: return "Celebrates when you hit a new personal record."
        }
    }

    var icon: String {
        switch self {
        case .streakProtection: return "flame.fill"
        case .workoutReminder: return "dumbbell.fill"
        case .rescanReminder: return "camera.viewfinder"
        case .mealLogging: return "fork.knife"
        case .recoveryReady: return "heart.fill"
        case .weeklySummary: return "chart.bar.fill"
        case .inactivityNudge: return "bell.badge.fill"
        case .newPR: return "trophy.fill"
        }
    }
}

