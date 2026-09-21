import Foundation

/// Personalized daily nutrition targets derived from the user's profile.
nonisolated struct DailyNutritionTargets: Codable, Hashable {
    let bmr: Int
    let tdee: Int
    let calories: Int
    let proteinGrams: Int
    /// Combined goal adjustment applied to TDEE as a fraction (e.g. -0.2 = 20% deficit).
    let goalAdjustment: Double
}

/// Computes daily calorie and protein targets from profile data using the
/// Mifflin-St Jeor equation (general informational use, not medical advice).
nonisolated enum NutritionTargetsCalculator {

    /// Activity multiplier — users train regularly, so moderately active.
    private static let activityFactor = 1.5

    /// Protein target: ~1.8 g per kg of bodyweight (≈0.8 g per lb).
    private static let proteinGramsPerKg = 1.8

    /// Safety floor so a heavy deficit never dips below a sane minimum.
    private static let minimumCalories = 1200

    /// Used when no profile exists yet (should be rare — profile is captured in onboarding).
    static let fallback = DailyNutritionTargets(
        bmr: 1650,
        tdee: 2475,
        calories: 2200,
        proteinGrams: 150,
        goalAdjustment: -0.1
    )

    static func targets(for profile: UserProfile) -> DailyNutritionTargets {
        // Mifflin-St Jeor: men +5, women -161; "other" uses the midpoint.
        let sexConstant: Double
        switch profile.sex {
        case .male: sexConstant = 5
        case .female: sexConstant = -161
        case .other: sexConstant = -78
        }

        let bmr = (10 * profile.weightKg) + (6.25 * profile.heightCm) - (5 * Double(profile.age)) + sexConstant
        let tdee = bmr * activityFactor

        // Multiple goals: average the adjustments.
        let adjustment = profile.goalTags.isEmpty
            ? 0
            : profile.goalTags.map { Self.adjustment(for: $0) }.reduce(0, +) / Double(profile.goalTags.count)

        let calories = max(tdee * (1 + adjustment), Double(minimumCalories))
        let protein = profile.weightKg * proteinGramsPerKg

        return DailyNutritionTargets(
            bmr: Int(bmr.rounded()),
            tdee: Int(tdee.rounded()),
            calories: Int(calories.rounded()),
            proteinGrams: Int(protein.rounded()),
            goalAdjustment: adjustment
        )
    }

    private static func adjustment(for goal: GoalTag) -> Double {
        switch goal {
        case .muscleSize: return 0.15   // surplus for building
        case .definition: return -0.20  // deficit for leaning out
        case .athletic: return 0        // maintenance
        case .recomposition: return -0.05
        }
    }
}
