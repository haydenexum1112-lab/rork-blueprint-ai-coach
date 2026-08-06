import Foundation

/// One logged set: weight lifted and reps completed.
nonisolated struct WorkoutSet: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var weightKg: Double
    var reps: Int
    var completed: Bool

    /// Volume for this set (weight × reps).
    var volume: Double { completed ? weightKg * Double(reps) : 0 }
}

/// Log for a single exercise within a workout session: planned vs performed sets.
nonisolated struct ExerciseLog: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var exerciseName: String
    var plannedSets: Int
    var plannedReps: String
    var sets: [WorkoutSet]

    /// Best set by volume.
    var bestSet: WorkoutSet? {
        sets.filter { $0.completed }.max(by: { $0.volume < $1.volume })
    }

    /// Total volume across all completed sets.
    var totalVolume: Double {
        sets.reduce(0) { $0 + $1.volume }
    }

    /// True if every planned set is completed.
    var isComplete: Bool {
        !sets.isEmpty && sets.allSatisfy { $0.completed }
    }
}

/// A completed (or in-progress) workout session for a specific day of a specific week.
nonisolated struct WorkoutSession: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var weekNumber: Int
    var dayIndex: Int
    var dayName: String
    var date: Date
    var exercises: [ExerciseLog]
    var isDeload: Bool
    /// Non-nil for freeform workouts logged from the calendar (not tied to the weekly plan).
    var customTitle: String? = nil

    /// True if all exercises are fully logged.
    var isFinished: Bool {
        !exercises.isEmpty && exercises.allSatisfy { $0.isComplete }
    }

    /// Total volume across all exercises.
    var totalVolume: Double {
        exercises.reduce(0) { $0 + $1.totalVolume }
    }

    /// Estimated duration in minutes (3 min per set + 2 min rest buffer).
    var estimatedMinutes: Int {
        let totalSets = exercises.reduce(0) { $0 + $1.sets.filter { $0.completed }.count }
        return max(1, totalSets * 3)
    }
}

/// Weekly progression snapshot describing what changed vs the prior week.
nonisolated struct WeekProgression: Codable, Hashable {
    var weekNumber: Int
    var isDeload: Bool
    /// Human-readable deltas, e.g. ["Bench Press: +1 rep", "Squat: +2.5 kg"].
    var changes: [String]
}
