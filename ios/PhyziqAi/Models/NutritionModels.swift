import Foundation

/// Dietary style the user follows.
nonisolated enum DietStyle: String, Codable, CaseIterable, Identifiable {
    case omnivore
    case pescatarian
    case vegetarian
    case vegan
    case keto
    case paleo
    case mediterranean
    case lowCarb
    case halal
    case kosher

    var id: String { rawValue }

    var display: String {
        switch self {
        case .omnivore: return "I eat everything"
        case .pescatarian: return "Pescatarian"
        case .vegetarian: return "Vegetarian"
        case .vegan: return "Vegan"
        case .keto: return "Keto"
        case .paleo: return "Paleo"
        case .mediterranean: return "Mediterranean"
        case .lowCarb: return "Low-carb"
        case .halal: return "Halal"
        case .kosher: return "Kosher"
        }
    }

    var subtitle: String {
        switch self {
        case .omnivore: return "Meat, fish, dairy, eggs"
        case .pescatarian: return "Fish + plant-based, no meat"
        case .vegetarian: return "Dairy + eggs, no meat or fish"
        case .vegan: return "Plant-based only"
        case .keto: return "High fat, very low carbs"
        case .paleo: return "Whole foods, no grains or dairy"
        case .mediterranean: return "Fish, olive oil, veg, little red meat"
        case .lowCarb: return "Moderate carbs, higher protein"
        case .halal: return "No pork or alcohol"
        case .kosher: return "No pork, shellfish, or meat + dairy mix"
        }
    }

    var icon: String {
        switch self {
        case .omnivore: return "fork.knife"
        case .pescatarian: return "fish.fill"
        case .vegetarian: return "leaf.fill"
        case .vegan: return "sprout"
        case .keto: return "flame.fill"
        case .paleo: return "fork.knife.circle"
        case .mediterranean: return "sun.max.fill"
        case .lowCarb: return "scalemass"
        case .halal: return "moon.fill"
        case .kosher: return "star.fill"
        }
    }

    /// Quick category tag for grouping in the picker.
    var group: String {
        switch self {
        case .omnivore, .pescatarian, .vegetarian, .vegan: return "By lifestyle"
        case .keto, .paleo, .mediterranean, .lowCarb: return "By program"
        case .halal, .kosher: return "By faith"
        }
    }
}

/// Common allergens / restrictions the user can exclude.
nonisolated enum Allergen: String, Codable, CaseIterable, Identifiable {
    case gluten
    case dairy
    case eggs
    case nuts
    case soy
    case shellfish

    var id: String { rawValue }

    var display: String {
        switch self {
        case .gluten: return "Gluten"
        case .dairy: return "Dairy"
        case .eggs: return "Eggs"
        case .nuts: return "Tree nuts"
        case .soy: return "Soy"
        case .shellfish: return "Shellfish"
        }
    }
}

/// A food the user can mark as liked or disliked in the survey.
nonisolated struct FoodItem: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let emoji: String
    let tags: [String]
}

/// Catalog of foods shown in the like/dislike survey.
nonisolated enum FoodCatalog {
    static let items: [FoodItem] = [
        FoodItem(id: "chicken", name: "Chicken", emoji: "🍗", tags: ["meat", "protein"]),
        FoodItem(id: "beef", name: "Beef", emoji: "🥩", tags: ["meat", "protein"]),
        FoodItem(id: "salmon", name: "Salmon", emoji: "🐟", tags: ["fish", "protein"]),
        FoodItem(id: "tuna", name: "Tuna", emoji: "🐠", tags: ["fish", "protein"]),
        FoodItem(id: "shrimp", name: "Shrimp", emoji: "🦐", tags: ["shellfish", "protein"]),
        FoodItem(id: "eggs", name: "Eggs", emoji: "🥚", tags: ["dairy", "protein"]),
        FoodItem(id: "greek_yogurt", name: "Greek yogurt", emoji: "🥛", tags: ["dairy", "protein"]),
        FoodItem(id: "cottage_cheese", name: "Cottage cheese", emoji: "🧀", tags: ["dairy", "protein"]),
        FoodItem(id: "tofu", name: "Tofu", emoji: "🍱", tags: ["soy", "protein"]),
        FoodItem(id: "beans", name: "Beans", emoji: "🫘", tags: ["plant", "protein"]),
        FoodItem(id: "lentils", name: "Lentils", emoji: "🥣", tags: ["plant", "protein"]),
        FoodItem(id: "rice", name: "Rice", emoji: "🍚", tags: ["grain", "carb"]),
        FoodItem(id: "oats", name: "Oats", emoji: "🥘", tags: ["grain", "carb"]),
        FoodItem(id: "potato", name: "Potatoes", emoji: "🥔", tags: ["vegetable", "carb"]),
        FoodItem(id: "sweet_potato", name: "Sweet potato", emoji: "🍠", tags: ["vegetable", "carb"]),
        FoodItem(id: "pasta", name: "Pasta", emoji: "🍝", tags: ["grain", "carb"]),
        FoodItem(id: "bread", name: "Bread", emoji: "🍞", tags: ["grain", "carb"]),
        FoodItem(id: "quinoa", name: "Quinoa", emoji: "🌾", tags: ["grain", "carb"]),
        FoodItem(id: "avocado", name: "Avocado", emoji: "🥑", tags: ["plant", "fat"]),
        FoodItem(id: "nuts", name: "Mixed nuts", emoji: "🥜", tags: ["nuts", "fat"]),
        FoodItem(id: "olive_oil", name: "Olive oil", emoji: "🫒", tags: ["plant", "fat"]),
        FoodItem(id: "spinach", name: "Spinach", emoji: "🥬", tags: ["vegetable"]),
        FoodItem(id: "broccoli", name: "Broccoli", emoji: "🥦", tags: ["vegetable"]),
        FoodItem(id: "berries", name: "Berries", emoji: "🫐", tags: ["fruit"]),
        FoodItem(id: "banana", name: "Banana", emoji: "🍌", tags: ["fruit"]),
        FoodItem(id: "apple", name: "Apple", emoji: "🍎", tags: ["fruit"]),
        FoodItem(id: "dark_chocolate", name: "Dark chocolate", emoji: "🍫", tags: ["treat"])
    ]
}

/// How many meals the user wants per day.
nonisolated enum MealFrequency: Int, Codable, CaseIterable, Identifiable {
    case three = 3
    case four = 4
    case five = 5

    var id: Int { rawValue }

    var display: String {
        switch self {
        case .three: return "3 meals"
        case .four: return "4 meals"
        case .five: return "5 meals"
        }
    }

    var subtitle: String {
        switch self {
        case .three: return "Breakfast, lunch, dinner"
        case .four: return "Add a snack"
        case .five: return "Two snacks between meals"
        }
    }
}

/// How much time the user can spend cooking.
nonisolated enum CookingTime: String, Codable, CaseIterable, Identifiable {
    case quick
    case moderate
    case elaborate

    var id: String { rawValue }

    var display: String {
        switch self {
        case .quick: return "Under 15 min"
        case .moderate: return "15–30 min"
        case .elaborate: return "30+ min"
        }
    }

    var subtitle: String {
        switch self {
        case .quick: return "Fast and simple"
        case .moderate: return "Balanced effort"
        case .elaborate: return "I enjoy cooking"
        }
    }

    var icon: String {
        switch self {
        case .quick: return "bolt.fill"
        case .moderate: return "clock.fill"
        case .elaborate: return "flame.fill"
        }
    }
}

/// Saved nutrition preferences from the survey.
nonisolated struct NutritionPreferences: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var dietStyle: DietStyle
    var allergens: [Allergen]
    /// Free-text allergens / restrictions the user typed in themselves
    /// (e.g. "coriander", "pork", "nightshades"). Matched case-insensitively
    /// against food names when filtering the meal plan.
    var customAllergens: [String]
    var likedFoodIds: [String]
    var dislikedFoodIds: [String]
    var mealFrequency: MealFrequency
    var cookingTime: CookingTime
    var savedAt: Date = Date()
}

/// A single meal in the generated daily plan.
nonisolated struct MealPlanEntry: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    let mealName: String
    let time: String
    let title: String
    let items: [String]
    let calories: Int
    let proteinGrams: Int
    let carbsGrams: Int
    let fatGrams: Int
}

/// A day's worth of meals.
nonisolated struct DailyMealPlan: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    let dayName: String
    let meals: [MealPlanEntry]
    let totalCalories: Int
    let totalProtein: Int
    let totalCarbs: Int
    let totalFat: Int
}

/// Nutrition subscription status — separate from Pro.
nonisolated enum NutritionSubscriptionStatus: Codable, Hashable {
    case none
    case trial(expires: Date)
    case active
}
