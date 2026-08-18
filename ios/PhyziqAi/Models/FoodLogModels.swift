import Foundation

/// One logged food entry: what you ate, when, and its macros.
/// Users can log from their meal plan, the food catalog, or free-text.
nonisolated struct FoodLogEntry: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    /// Display name, e.g. "Chicken & rice bowl" or "Protein shake".
    var name: String
    /// Emoji from the food catalog, or a generic fork icon if custom.
    var emoji: String
    /// Which meal slot this belongs to (breakfast, lunch, dinner, snack).
    var mealSlot: MealSlot
    /// Logged calories (kcal). 0 if unknown.
    var calories: Int
    /// Logged protein in grams. 0 if unknown.
    var proteinGrams: Int
    /// Logged carbs in grams. 0 if unknown.
    var carbsGrams: Int
    /// Logged fat in grams. 0 if unknown.
    var fatGrams: Int
    /// Number of servings/portions.
    var servings: Double
    /// Timestamp when logged.
    var loggedAt: Date
}

/// Meal slots used to group food log entries within a day.
nonisolated enum MealSlot: String, Codable, CaseIterable, Identifiable {
    case breakfast
    case lunch
    case dinner
    case snack

    var id: String { rawValue }

    var display: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .snack: return "Snack"
        }
    }

    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .snack: return "cup.and.saucer.fill"
        }
    }

    /// Rough default time-of-day for sorting.
    var sortOrder: Int {
        switch self {
        case .breakfast: return 0
        case .lunch: return 1
        case .snack: return 2
        case .dinner: return 3
        }
    }
}

/// A day's full food log: all entries for one calendar day plus macro totals.
nonisolated struct DailyFoodLog: Codable, Identifiable, Hashable {
    var id: String { dateKey }
    /// "yyyy-MM-dd" key for the calendar day.
    let dateKey: String
    var entries: [FoodLogEntry]

    var totalCalories: Int { entries.reduce(0) { $0 + $1.calories } }
    var totalProtein: Int { entries.reduce(0) { $0 + $1.proteinGrams } }
    var totalCarbs: Int { entries.reduce(0) { $0 + $1.carbsGrams } }
    var totalFat: Int { entries.reduce(0) { $0 + $1.fatGrams } }

    /// Entries grouped by meal slot, sorted by slot order then time.
    func entriesBySlot() -> [(MealSlot, [FoodLogEntry])] {
        let grouped = Dictionary(grouping: entries) { $0.mealSlot }
        return MealSlot.allCases
            .filter { grouped[$0] != nil }
            .map { slot in
                (slot, (grouped[slot] ?? []).sorted { $0.loggedAt < $1.loggedAt })
            }
    }
}
