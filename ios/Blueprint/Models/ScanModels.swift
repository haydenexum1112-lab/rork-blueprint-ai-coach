import Foundation

nonisolated enum ScanPose: String, Codable, CaseIterable, Identifiable {
    case front
    case side
    case back

    var id: String { rawValue }

    var display: String {
        switch self {
        case .front: return "Front"
        case .side: return "Side"
        case .back: return "Back"
        }
    }

    var guidance: String {
        switch self {
        case .front: return "Face the camera, arms relaxed at your sides"
        case .side: return "Turn 90° to your left, arms relaxed"
        case .back: return "Turn away from the camera, arms relaxed"
        }
    }
}

/// One uploaded goal-physique reference photo with an optional caption.
nonisolated struct TargetImage: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var fileName: String
    var caption: String
}

/// The user's target physique — 1 to 3 reference images.
nonisolated struct TargetReference: Codable, Identifiable {
    var id: UUID = UUID()
    var images: [TargetImage]
    var createdAt: Date = Date()
}

/// A physique scan: three frames (front / side / back) plus the AI analysis.
nonisolated struct Scan: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var date: Date
    /// Ordered file names: [front, side, back] stored on-device.
    var frameFileNames: [String]
    var analysis: AnalysisResult?
    var rawJSON: String?
    /// Weeks completed at the time this scan was taken.
    var weekTaken: Int = 0
}

nonisolated struct ProgressLog: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var weekNumber: Int
    var completed: Bool
    var date: Date
}

/// Small persisted metadata: exercise swaps, re-scan tracking, and feature prefs.
nonisolated struct AppMeta: Codable {
    var lastScanWeek: Int = 0
    var swappedExerciseKeys: Set<String> = []
    var hasSeenPaywall: Bool = false
    /// User's preference for the between-set rest timer. nil = not yet asked.
    var restTimerEnabled: Bool? = nil
    /// Notification preferences. nil = not yet asked (prompts on first opportunity).
    var notificationPrefs: NotificationPrefs? = nil
    /// PAR-Q health screener result. nil = not yet completed.
    var parqPassed: Bool? = nil
    var parqCompletedAt: Date? = nil
    /// Cloud backup preferences.
    var cloudBackupEnabled: Bool = false
    var cloudBackupDate: Date? = nil
}

/// Per-type notification toggles persisted in AppMeta.
nonisolated struct NotificationPrefs: Codable {
    var streakProtection: Bool = true
    var workoutReminder: Bool = true
    var rescanReminder: Bool = true
    var mealLogging: Bool = true
    var recoveryReady: Bool = false
    var weeklySummary: Bool = true
    var inactivityNudge: Bool = true
    var newPR: Bool = true
    /// Hour (0-23) for morning workout reminders.
    var reminderHour: Int = 9
    /// Whether the user has granted notification authorization.
    var hasAuthorized: Bool = false
}
