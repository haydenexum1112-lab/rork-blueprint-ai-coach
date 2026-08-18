import Foundation

/// Major muscle groups used for recovery tracking.
nonisolated enum MuscleGroup: String, Codable, CaseIterable, Identifiable {
    case chest
    case back
    case shoulders
    case biceps
    case triceps
    case quads
    case hamstrings
    case glutes
    case core
    case calves

    var id: String { rawValue }

    var display: String {
        switch self {
        case .chest: return "Chest"
        case .back: return "Back"
        case .shoulders: return "Shoulders"
        case .biceps: return "Biceps"
        case .triceps: return "Triceps"
        case .quads: return "Quads"
        case .hamstrings: return "Hamstrings"
        case .glutes: return "Glutes"
        case .core: return "Core"
        case .calves: return "Calves"
        }
    }

    var icon: String {
        switch self {
        case .chest: return "figure.strengthtraining.traditional"
        case .back: return "figure.rower"
        case .shoulders: return "figure.arm.opercule.raise"
        case .biceps: return "figure.arm.opercule.lift"
        case .triceps: return "figure.arm.opercule.push"
        case .quads: return "figure.strengthtraining.functional"
        case .hamstrings: return "figure.flexibilityrest"
        case .glutes: return "figure.strengthtraining.traditional"
        case .core: return "figure.core.training"
        case .calves: return "figure.stair.stepper"
        }
    }

    /// Typical recovery time in hours for a trained adult.
    var recoveryHours: Int {
        switch self {
        case .calves, .core, .biceps, .triceps, .shoulders: return 48
        case .chest, .back, .glutes: return 72
        case .quads, .hamstrings: return 72
        }
    }
}

/// Recovery status snapshot for a muscle group.
nonisolated struct MuscleRecovery: Codable, Identifiable, Hashable {
    var id: String { muscle.rawValue }
    let muscle: MuscleGroup
    /// Date of the last session that hit this muscle.
    let lastTrained: Date
    /// Estimated recovery completion date.
    let recoversBy: Date

    /// Progress 0–1 toward full recovery.
    var progress: Double {
        let now = Date()
        let total = recoversBy.timeIntervalSince(lastTrained)
        let elapsed = now.timeIntervalSince(lastTrained)
        guard total > 0 else { return 1 }
        return min(1, max(0, elapsed / total))
    }

    var isRecovered: Bool { Date() >= recoversBy }

    /// Remaining hours until recovered (0 if already recovered).
    var hoursRemaining: Int {
        let remaining = recoversBy.timeIntervalSince(Date())
        return max(0, Int(ceil(remaining / 3600)))
    }

    /// Short status label.
    var statusLabel: String {
        if isRecovered { return "Recovered" }
        let h = hoursRemaining
        if h < 1 { return "Almost ready" }
        if h < 24 { return "\(h)h left" }
        let d = h / 24
        return "\(d)d left"
    }
}

/// Maps exercise names to the muscle groups they primarily hit.
/// Used by recovery tracking after a session is logged.
nonisolated enum ExerciseMuscleMap {
    /// Returns the primary muscle groups trained by an exercise name.
    /// Matching is case-insensitive on substrings — falls back to [] if unknown.
    static func muscles(for exerciseName: String) -> [MuscleGroup] {
        let lower = exerciseName.lowercased()
        var groups: [MuscleGroup] = []

        // Chest
        if lower.contains("bench") || lower.contains("press") && !lower.contains("leg") && !lower.contains("shoulder") && !lower.contains("row") && !lower.contains("pull") && !lower.contains("curl") && !lower.contains("extension") && !lower.contains("squat") && !lower.contains("deadlift") && !lower.contains("hip") && !lower.contains("calf") || lower.contains("incline") && !lower.contains("row") || lower.contains("dumbbell press") || lower.contains("machine press") || lower.contains("fly") || lower.contains("push") && !lower.contains("up") && !lower.contains("press leg") {
            groups.append(.chest)
        }
        // Back
        if lower.contains("row") || lower.contains("pull") && !lower.contains("push") && !lower.contains("down leg") || lower.contains("pulldown") || lower.contains("chin") || lower.contains("deadlift") && !lower.contains("romanian") && !lower.contains("rdl") || lower.contains("lat") {
            groups.append(.back)
        }
        // Shoulders
        if lower.contains("shoulder") || lower.contains("press") && (lower.contains("overhead") || lower.contains("military") || lower.contains("arnold")) || lower.contains("lateral raise") || lower.contains("lateral") || lower.contains("delt") || lower.contains("upright row") {
            groups.append(.shoulders)
        }
        // Biceps
        if lower.contains("bicep") || lower.contains("curl") && !lower.contains("leg") && !lower.contains("hamstring") && !lower.contains("cable row") {
            groups.append(.biceps)
        }
        // Triceps
        if lower.contains("tricep") || lower.contains("pushdown") || lower.contains("dip") && !lower.contains("hip") || lower.contains("skull crusher") || lower.contains("extension") && !lower.contains("leg") && !lower.contains("back") {
            groups.append(.triceps)
        }
        // Quads
        if lower.contains("squat") || lower.contains("leg press") || lower.contains("leg extension") || lower.contains("lunge") || lower.contains("step") && !lower.contains("up right") || lower.contains("split squat") || lower.contains("goblet") {
            groups.append(.quads)
        }
        // Hamstrings
        if lower.contains("hamstring") || lower.contains("romanian") || lower.contains("rdl") || lower.contains("leg curl") || lower.contains("stiff leg") || lower.contains("good morning") {
            groups.append(.hamstrings)
        }
        // Glutes
        if lower.contains("glute") || lower.contains("hip thrust") || lower.contains("hip bridge") || lower.contains("kickback") || lower.contains("abduction") || lower.contains("deadlift") && (lower.contains("sumo") || lower.contains("romanian") || lower.contains("rdl")) {
            groups.append(.glutes)
        }
        // Core
        if lower.contains("plank") || lower.contains("sit") && lower.contains("up") || lower.contains("crunch") || lower.contains("hanging leg raise") || lower.contains("hanging knee") || lower.contains("ab") || lower.contains("core") || lower.contains("cable woodchop") || lower.contains("pallof") || lower.contains("dead bug") || lower.contains("russian twist") {
            groups.append(.core)
        }
        // Calves
        if lower.contains("calf") || lower.contains("calve") {
            groups.append(.calves)
        }

        // Fallback: if nothing matched, use chest as a sensible default for upper-body presses
        if groups.isEmpty && (lower.contains("press") || lower.contains("push")) {
            groups.append(.chest)
        }
        return groups
    }
}
