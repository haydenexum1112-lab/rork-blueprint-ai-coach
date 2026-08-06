import Foundation
import SwiftUI

/// Lenient Int wrapper — the model occasionally returns numbers as strings or doubles.
nonisolated struct FlexInt: Codable, Hashable {
    let value: Int

    init(_ value: Int) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = Int(doubleValue)
        } else if let stringValue = try? container.decode(String.self),
                  let parsed = Int(stringValue.trimmingCharacters(in: .whitespaces)) {
            value = parsed
        } else {
            value = 0
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

/// Lenient String wrapper — reps like "8-12" may occasionally arrive as a bare number.
nonisolated struct FlexString: Codable, Hashable {
    let value: String

    init(_ value: String) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let intValue = try? container.decode(Int.self) {
            value = String(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            value = String(Int(doubleValue))
        } else {
            value = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

nonisolated struct PhysiqueScore: Codable, Hashable {
    let overall: FlexInt
    let byRegion: [String: FlexInt]
}

nonisolated enum ConfidenceLevel: String, Codable, Hashable {
    case low, medium, high

    var display: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}

nonisolated struct AnalysisResult: Codable, Hashable {
    let summary: String
    let assessment: Assessment
    let gapToGoal: [GapItem]
    let plan: WorkoutPlan
    let physiqueScore: PhysiqueScore?
    let confidence: String

    init(summary: String, assessment: Assessment, gapToGoal: [GapItem], plan: WorkoutPlan, physiqueScore: PhysiqueScore? = nil, confidence: String = "medium") {
        self.summary = summary
        self.assessment = assessment
        self.gapToGoal = gapToGoal
        self.plan = plan
        self.physiqueScore = physiqueScore
        self.confidence = confidence
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        summary = try c.decode(String.self, forKey: .summary)
        assessment = try c.decode(Assessment.self, forKey: .assessment)
        gapToGoal = try c.decode([GapItem].self, forKey: .gapToGoal)
        plan = try c.decode(WorkoutPlan.self, forKey: .plan)
        physiqueScore = try c.decodeIfPresent(PhysiqueScore.self, forKey: .physiqueScore)
        confidence = try c.decodeIfPresent(String.self, forKey: .confidence) ?? "medium"
    }

    var confidenceLevel: ConfidenceLevel {
        switch confidence.lowercased() {
        case "high": return .high
        case "low": return .low
        default: return .medium
        }
    }
}

nonisolated struct Assessment: Codable, Hashable {
    let strengths: [String]
    let focusAreas: [FocusArea]
}

nonisolated struct FocusArea: Codable, Hashable {
    let region: String
    let note: String
}

nonisolated struct GapItem: Codable, Hashable {
    let region: String
    let priority: FlexInt
    let rationale: String
}

nonisolated struct WorkoutPlan: Codable, Hashable {
    let splitName: String
    let daysPerWeek: FlexInt
    let days: [WorkoutDay]

    /// Days 0-2 are free; if the plan has fewer than 3 days, all are free.
    func isDayFree(_ index: Int) -> Bool {
        index < 3 && index < days.count
    }

    var splitDescription: String {
        let lower = splitName.lowercased()
        if lower.contains("push") && lower.contains("pull") && lower.contains("leg") {
            return "Chest/shoulders/triceps, back/biceps, and legs rotated across the week."
        } else if lower.contains("upper") && lower.contains("lower") {
            return "Upper body sessions alternate with lower body sessions for balanced frequency."
        } else if lower.contains("full body") {
            return "Every major muscle group trained in each session."
        } else if lower.contains("bro") || lower.contains("body part") {
            return "One or two muscle groups per session with plenty of volume per body part."
        } else if lower.contains("ppl") {
            return "Push, pull, and legs rotated across the training week."
        } else if daysPerWeek.value <= 3 {
            return "A compact split that hits each major muscle group every session."
        } else {
            return "A balanced split matched to your training days and recovery."
        }
    }
}

nonisolated struct WorkoutDay: Codable, Hashable {
    let day: String
    let targets: [String]
    let exercises: [Exercise]
}

nonisolated struct Exercise: Codable, Hashable {
    let name: String
    let sets: FlexInt
    let reps: FlexString
    let restSec: FlexInt
    let why: String
    let alt: String?
    let cues: [String]?
}
