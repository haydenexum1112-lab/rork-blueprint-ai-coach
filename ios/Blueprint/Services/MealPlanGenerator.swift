import Foundation

/// Generates a daily meal plan from saved nutrition preferences.
/// Sample-based for v1 — swap with AI generation later.
enum MealPlanGenerator {

    static func generateWeek(prefs: NutritionPreferences) -> [DailyMealPlan] {
        let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        return dayNames.enumerated().map { index, name in
            generateDay(prefs: prefs, dayName: name, dayIndex: index)
        }
    }

    static func generateDay(prefs: NutritionPreferences, dayName: String, dayIndex: Int) -> DailyMealPlan {
        let liked = foods(from: prefs.likedFoodIds)
        let dislikedIds = Set(prefs.dislikedFoodIds)
        let blockedTags = Set(prefs.allergens.flatMap { allergenTags(for: $0) })
        let customAllergensLower = prefs.customAllergens.map { $0.lowercased() }

        let allowed = liked.isEmpty
            ? FoodCatalog.items.filter { food in
                !dislikedIds.contains(food.id) &&
                !blockedByDiet(food, diet: prefs.dietStyle, allergens: blockedTags) &&
                !blockedByCustomAllergens(food, custom: customAllergensLower)
            }
            : liked.filter { food in
                !dislikedIds.contains(food.id) &&
                !blockedByDiet(food, diet: prefs.dietStyle, allergens: blockedTags) &&
                !blockedByCustomAllergens(food, custom: customAllergensLower)
            }

        let proteinFoods = allowed.filter { $0.tags.contains("protein") }
        let carbFoods = allowed.filter { $0.tags.contains("carb") }.filter { _ in !lowCarbDiet(prefs.dietStyle) }
        let fatFoods = allowed.filter { $0.tags.contains("fat") }
        let produceFoods = allowed.filter { $0.tags.contains("vegetable") || $0.tags.contains("fruit") }

        let meals = buildMeals(
            frequency: prefs.mealFrequency,
            proteinFoods: proteinFoods,
            carbFoods: carbFoods,
            fatFoods: fatFoods,
            produceFoods: produceFoods,
            dayIndex: dayIndex,
            dietStyle: prefs.dietStyle
        )

        let totalCalories = meals.reduce(0) { $0 + $1.calories }
        let totalProtein = meals.reduce(0) { $0 + $1.proteinGrams }
        let totalCarbs = meals.reduce(0) { $0 + $1.carbsGrams }
        let totalFat = meals.reduce(0) { $0 + $1.fatGrams }

        return DailyMealPlan(
            dayName: dayName,
            meals: meals,
            totalCalories: totalCalories,
            totalProtein: totalProtein,
            totalCarbs: totalCarbs,
            totalFat: totalFat
        )
    }

    private static func buildMeals(
        frequency: MealFrequency,
        proteinFoods: [FoodItem],
        carbFoods: [FoodItem],
        fatFoods: [FoodItem],
        produceFoods: [FoodItem],
        dayIndex: Int,
        dietStyle: DietStyle
    ) -> [MealPlanEntry] {
        var meals: [MealPlanEntry] = []
        let times: [String]
        let names: [String]
        switch frequency {
        case .three:
            names = ["Breakfast", "Lunch", "Dinner"]
            times = ["7:30 AM", "1:00 PM", "7:00 PM"]
        case .four:
            names = ["Breakfast", "Lunch", "Snack", "Dinner"]
            times = ["7:30 AM", "1:00 PM", "4:00 PM", "7:00 PM"]
        case .five:
            names = ["Breakfast", "Snack", "Lunch", "Snack", "Dinner"]
            times = ["7:30 AM", "10:30 AM", "1:00 PM", "4:00 PM", "7:00 PM"]
        }

        for (i, name) in names.enumerated() {
            let protein = pick(proteinFoods, offset: dayIndex + i, fallback: FoodItem(id: "eggs", name: "Eggs", emoji: "🥚", tags: ["protein"]))
            let carb = pick(carbFoods.isEmpty ? produceFoods : carbFoods, offset: dayIndex + i + 1, fallback: FoodItem(id: "rice", name: "Rice", emoji: "🍚", tags: ["carb"]))
            let produce = pick(produceFoods, offset: dayIndex + i + 2, fallback: FoodItem(id: "spinach", name: "Spinach", emoji: "🥬", tags: ["vegetable"]))
            let fat = pick(fatFoods, offset: dayIndex + i + 3, fallback: FoodItem(id: "olive_oil", name: "Olive oil", emoji: "🫒", tags: ["fat"]))

            let isBreakfast = i == 0
            let isSnack = name == "Snack"
            let isLowCarb = lowCarbDiet(dietStyle)

            let title: String
            if isSnack {
                title = "\(protein.emoji) \(protein.name) & \(carb.emoji) \(carb.name)"
            } else if isBreakfast {
                title = "\(carb.emoji) \(carb.name) with \(protein.emoji) \(protein.name)"
            } else {
                title = "\(protein.emoji) \(protein.name) with \(carb.emoji) \(carb.name) & \(produce.emoji) \(produce.name)"
            }

            let items: [String]
            let calories: Int
            let proteinG: Int
            let carbsG: Int
            let fatG: Int

            if isSnack {
                items = [
                    "\(protein.name) (1 serving)",
                    "\(carb.name) (1 serving)"
                ]
                calories = isLowCarb ? 340 : 320
                proteinG = isLowCarb ? 32 : 28
                carbsG = isLowCarb ? 10 : 34
                fatG = isLowCarb ? 20 : 10
            } else if isBreakfast {
                items = [
                    "\(carb.name) (1 serving)",
                    "\(protein.name) (1 serving)",
                    "\(produce.name) (½ cup)"
                ]
                calories = isLowCarb ? 460 : 480
                proteinG = isLowCarb ? 38 : 35
                carbsG = isLowCarb ? 14 : 55
                fatG = isLowCarb ? 28 : 14
            } else {
                items = [
                    "\(protein.name) (5 oz)",
                    "\(carb.name) (1 cup)",
                    "\(produce.name) (1 cup)",
                    "\(fat.name) (1 tbsp)"
                ]
                calories = isLowCarb ? 580 : 560
                proteinG = isLowCarb ? 46 : 42
                carbsG = isLowCarb ? 16 : 52
                fatG = isLowCarb ? 32 : 18
            }

            meals.append(MealPlanEntry(
                mealName: name,
                time: times[i],
                title: title,
                items: items,
                calories: calories,
                proteinGrams: proteinG,
                carbsGrams: carbsG,
                fatGrams: fatG
            ))
        }

        return meals
    }

    private static func pick(_ items: [FoodItem], offset: Int, fallback: FoodItem) -> FoodItem {
        guard !items.isEmpty else { return fallback }
        return items[(offset % items.count + items.count) % items.count]
    }

    private static func foods(from ids: [String]) -> [FoodItem] {
        FoodCatalog.items.filter { ids.contains($0.id) }
    }

    private static func blockedByDiet(_ food: FoodItem, diet: DietStyle, allergens: Set<String>) -> Bool {
        if food.tags.contains(where: { allergens.contains($0) }) { return true }
        switch diet {
        case .omnivore:
            return false
        case .pescatarian:
            return food.tags.contains("meat")
        case .vegetarian:
            return food.tags.contains("meat") || food.tags.contains("fish") || food.tags.contains("shellfish")
        case .vegan:
            return food.tags.contains("meat") || food.tags.contains("fish") || food.tags.contains("shellfish") || food.tags.contains("dairy")
        case .keto:
            // High fat, very low carb: drop grains/starchy carbs
            return food.tags.contains("grain") || food.id == "potato" || food.id == "sweet_potato" || food.id == "banana"
        case .paleo:
            // Whole foods: no grains, dairy, or legumes
            return food.tags.contains("grain") || food.tags.contains("dairy") || food.id == "beans" || food.id == "lentils" || food.id == "tofu"
        case .mediterranean:
            // Mostly plant + fish; drop red meat
            return food.id == "beef"
        case .lowCarb:
            // Keep protein + fat + produce; drop dense carbs
            return food.tags.contains("grain") || food.id == "potato" || food.id == "sweet_potato"
        case .halal:
            return food.id == "beef" && false // beef is halal; pork would be blocked but isn't in catalog
        case .kosher:
            // No pork, no shellfish, no meat+dairy mix (simplify: block shellfish)
            return food.tags.contains("shellfish")
        }
    }

    /// Returns true for diets that restrict carbs (keto, low-carb, paleo-ish).
    private static func lowCarbDiet(_ diet: DietStyle) -> Bool {
        switch diet {
        case .keto, .lowCarb, .paleo: return true
        default: return false
        }
    }

    /// Case-insensitive match of a user-typed allergen against a food's name and tags.
    private static func blockedByCustomAllergens(_ food: FoodItem, custom: [String]) -> Bool {
        guard !custom.isEmpty else { return false }
        let nameLower = food.name.lowercased()
        let tagsLower = food.tags.map { $0.lowercased() }
        for term in custom {
            let trimmed = term.trimmingCharacters(in: .whitespaces).lowercased()
            guard !trimmed.isEmpty else { continue }
            if nameLower.contains(trimmed) { return true }
            if tagsLower.contains(where: { $0.contains(trimmed) }) { return true }
        }
        return false
    }

    private static func allergenTags(for allergen: Allergen) -> [String] {
        switch allergen {
        case .gluten: return ["grain"]
        case .dairy: return ["dairy"]
        case .eggs: return ["eggs"]
        case .nuts: return ["nuts"]
        case .soy: return ["soy"]
        case .shellfish: return ["shellfish"]
        }
    }
}
