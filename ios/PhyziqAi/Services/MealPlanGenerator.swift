import Foundation

/// Generates a daily meal plan from saved nutrition preferences and the
/// user's body stats. Daily calories/macros come from
/// `NutritionTargetsCalculator` (Mifflin-St Jeor + goal adjustment); each
/// meal gets a proportional share and portion labels scale to match.
enum MealPlanGenerator {

    static func generateWeek(prefs: NutritionPreferences, profile: UserProfile?) -> [DailyMealPlan] {
        let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        return dayNames.enumerated().map { index, name in
            generateDay(prefs: prefs, profile: profile, dayName: name, dayIndex: index)
        }
    }

    static func generateDay(prefs: NutritionPreferences, profile: UserProfile?, dayName: String, dayIndex: Int) -> DailyMealPlan {
        let targets = profile.map { NutritionTargetsCalculator.targets(for: $0) } ?? NutritionTargetsCalculator.fallback
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
            targets: targets,
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
        targets: DailyNutritionTargets,
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

        // Calorie distribution across the day — breakfast ~25%, lunch ~30%,
        // dinner ~30%, snacks split the rest (fractions sum to 1.0).
        let snackCount = names.filter { $0 == "Snack" }.count
        let snackShare = 0.15 / Double(max(snackCount, 1))
        let fractions: [Double] = names.map { name in
            switch name {
            case "Breakfast": return 0.25
            case "Lunch": return 0.30
            case "Dinner": return snackCount == 0 ? 0.40 : 0.30
            default: return snackShare
            }
        }

        let calorieShares = allocate(targets.calories, fractions: fractions)
        let proteinShares = allocate(targets.proteinGrams, fractions: fractions)
        let isLowCarb = lowCarbDiet(dietStyle)

        for (i, name) in names.enumerated() {
            let protein = pick(proteinFoods, offset: dayIndex + i, fallback: FoodItem(id: "eggs", name: "Eggs", emoji: "🥚", tags: ["protein"]))
            let carb = pick(carbFoods.isEmpty ? produceFoods : carbFoods, offset: dayIndex + i + 1, fallback: FoodItem(id: "rice", name: "Rice", emoji: "🍚", tags: ["carb"]))
            let produce = pick(produceFoods, offset: dayIndex + i + 2, fallback: FoodItem(id: "spinach", name: "Spinach", emoji: "🥬", tags: ["vegetable"]))
            let fat = pick(fatFoods, offset: dayIndex + i + 3, fallback: FoodItem(id: "olive_oil", name: "Olive oil", emoji: "🫒", tags: ["fat"]))

            let isBreakfast = i == 0
            let isSnack = name == "Snack"

            let title: String
            if isSnack {
                title = "\(protein.emoji) \(protein.name) & \(carb.emoji) \(carb.name)"
            } else if isBreakfast {
                title = "\(carb.emoji) \(carb.name) with \(protein.emoji) \(protein.name)"
            } else {
                title = "\(protein.emoji) \(protein.name) with \(carb.emoji) \(carb.name) & \(produce.emoji) \(produce.name)"
            }

            let template = templateMacros(isSnack: isSnack, isBreakfast: isBreakfast, lowCarb: isLowCarb)
            let calories = calorieShares[i]
            let proteinG = proteinShares[i]
            // Fill remaining calories with carbs + fat, preserving the template's
            // macro shape so keto/low-carb plans stay low-carb at any calorie level.
            let remaining = max(calories - proteinG * 4, 0)
            let baseRemaining = max(template.calories - template.protein * 4, 1)
            let scale = Double(remaining) / Double(baseRemaining)
            let carbsG = Int((Double(template.carbs) * scale).rounded())
            let fatG = Int((Double(template.fat) * scale).rounded())

            let items: [String]
            if isSnack {
                items = [
                    "\(protein.name) (\(servingLabel(scaleTo: calories, base: template.calories)))",
                    "\(carb.name) (\(servingLabel(scaleTo: calories, base: template.calories)))"
                ]
            } else if isBreakfast {
                items = [
                    "\(carb.name) (\(servingLabel(scaleTo: calories, base: template.calories)))",
                    "\(protein.name) (\(servingLabel(scaleTo: calories, base: template.calories)))",
                    "\(produce.name) (½ cup)"
                ]
            } else {
                items = [
                    "\(protein.name) (\(ounceLabel(scaleTo: calories, base: template.calories)))",
                    "\(carb.name) (\(cupLabel(scaleTo: calories, base: template.calories)))",
                    "\(produce.name) (1 cup)",
                    "\(fat.name) (\(tbspLabel(scaleTo: calories, base: template.calories)))"
                ]
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

    // MARK: - Template macros (shape used for scaling)

    private struct TemplateMacros {
        let calories: Int
        let protein: Int
        let carbs: Int
        let fat: Int
    }

    /// Base macros at reference portions; used to keep macro ratios stable
    /// while calories scale to the personalized target.
    private static func templateMacros(isSnack: Bool, isBreakfast: Bool, lowCarb: Bool) -> TemplateMacros {
        if isSnack {
            return lowCarb
                ? TemplateMacros(calories: 340, protein: 32, carbs: 10, fat: 20)
                : TemplateMacros(calories: 320, protein: 28, carbs: 34, fat: 10)
        } else if isBreakfast {
            return lowCarb
                ? TemplateMacros(calories: 460, protein: 38, carbs: 14, fat: 28)
                : TemplateMacros(calories: 480, protein: 35, carbs: 55, fat: 14)
        } else {
            return lowCarb
                ? TemplateMacros(calories: 580, protein: 46, carbs: 16, fat: 32)
                : TemplateMacros(calories: 560, protein: 42, carbs: 52, fat: 18)
        }
    }

    // MARK: - Allocation & portion helpers

    /// Splits `total` across `fractions` (must sum to ~1.0) with integer
    /// rounding; the last share absorbs rounding drift so the sum matches.
    private static func allocate(_ total: Int, fractions: [Double]) -> [Int] {
        var result: [Int] = []
        var assigned = 0
        for (i, fraction) in fractions.enumerated() {
            if i == fractions.count - 1 {
                result.append(max(total - assigned, 0))
            } else {
                let value = Int((Double(total) * fraction).rounded())
                assigned += value
                result.append(value)
            }
        }
        return result
    }

    private static func scaleFactor(scaleTo calories: Int, base: Int) -> Double {
        Double(calories) / Double(max(base, 1))
    }

    /// "1 serving", "1½ servings", "2 servings" — rounded to the nearest half.
    private static func servingLabel(scaleTo calories: Int, base: Int) -> String {
        let amount = max((scaleFactor(scaleTo: calories, base: base) * 2).rounded() / 2, 0.5)
        let label = fractionLabel(amount)
        return amount > 1 ? "\(label) servings" : "\(label) serving"
    }

    /// "3 oz", "5 oz", "6½ oz" — protein portions for main meals, min 3 oz.
    private static func ounceLabel(scaleTo calories: Int, base: Int) -> String {
        let ounces = max((scaleFactor(scaleTo: calories, base: base) * 5 * 2).rounded() / 2, 3)
        return "\(fractionLabel(ounces)) oz"
    }

    /// "1 cup", "1½ cups" — carb portions for main meals, min ½ cup.
    private static func cupLabel(scaleTo calories: Int, base: Int) -> String {
        let cups = max((scaleFactor(scaleTo: calories, base: base) * 4).rounded() / 4, 0.5)
        let label = fractionLabel(cups)
        return cups > 1 ? "\(label) cups" : "\(label) cup"
    }

    /// "1 tbsp", "1½ tbsp", "2 tbsp" — fat portions, min ½ tbsp.
    private static func tbspLabel(scaleTo calories: Int, base: Int) -> String {
        let tbsp = max((scaleFactor(scaleTo: calories, base: base) * 2).rounded() / 2, 0.5)
        return "\(fractionLabel(tbsp)) tbsp"
    }

    /// Rounds to the nearest quarter and renders as a friendly fraction ("1½").
    private static func fractionLabel(_ amount: Double) -> String {
        let quarter = (amount * 4).rounded() / 4
        let whole = Int(quarter.rounded(.down))
        let frac = quarter - Double(whole)
        let fracSymbol: String
        switch frac {
        case 0.26..<0.5: fracSymbol = "¼"
        case 0.51..<0.75: fracSymbol = "½"
        case 0.76..<1.0: fracSymbol = "¾"
        default: fracSymbol = ""
        }
        if whole == 0 { return fracSymbol.isEmpty ? "0" : fracSymbol }
        return "\(whole)\(fracSymbol)"
    }

    // MARK: - Catalog filtering (unchanged)

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
