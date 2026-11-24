import Foundation

/// Generates a daily meal plan from saved nutrition preferences and the
/// user's body stats. Daily calories/macros come from
/// `NutritionTargetsCalculator` (Mifflin-St Jeor + goal adjustment); each
/// meal gets a proportional share and portion labels scale to match.
///
/// The plan is built from ALL foods the user is okay with (catalog minus
/// disliked, allergen-blocked, and diet-blocked foods). Liked foods are
/// prioritized — featured in about half the meal slots — but never limit
/// the plan, so meals stay varied.
enum MealPlanGenerator {

    static func generateWeek(prefs: NutritionPreferences, profile: UserProfile?) -> [DailyMealPlan] {
        let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        return dayNames.enumerated().map { index, name in
            generateDay(prefs: prefs, profile: profile, dayName: name, dayIndex: index)
        }
    }

    /// Filtered food pools shared by the plan builder and the swap-alternatives
    /// generator so both obey the same diet/allergen/dislike rules.
    static func allowedFoods(prefs: NutritionPreferences) -> (all: [FoodItem], liked: [FoodItem]) {
        let dislikedIds = Set(prefs.dislikedFoodIds)
        let blockedTags = Set(prefs.allergens.flatMap { allergenTags(for: $0) })
        let customAllergensLower = prefs.customAllergens.map { $0.lowercased() }

        let allowed = FoodCatalog.items.filter { food in
            !dislikedIds.contains(food.id) &&
            !blockedByDiet(food, diet: prefs.dietStyle, allergens: blockedTags) &&
            !blockedByCustomAllergens(food, custom: customAllergensLower)
        }
        let likedIds = Set(prefs.likedFoodIds)
        return (allowed, allowed.filter { likedIds.contains($0.id) })
    }

    static func generateDay(prefs: NutritionPreferences, profile: UserProfile?, dayName: String, dayIndex: Int) -> DailyMealPlan {
        let targets = profile.map { NutritionTargetsCalculator.targets(for: $0) } ?? NutritionTargetsCalculator.fallback
        let pools = allowedFoods(prefs: prefs)
        let allowed = pools.all

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
            likedFoods: pools.liked,
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
        likedFoods: [FoodItem],
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

        // Day-level dedupe: never serve the same food twice in one day.
        var usedIds = Set<String>()

        for (i, name) in names.enumerated() {
            // Feature the user's liked foods in about half the meal slots;
            // the rest rotate through the full allowed pool for variety.
            let slot: MealSlot = name == "Breakfast" ? .breakfast : (name == "Snack" ? .snack : .main)
            let meal = makeMeal(
                name: name,
                time: times[i],
                calories: calorieShares[i],
                proteinG: proteinShares[i],
                slot: slot,
                lowCarb: isLowCarb,
                proteinFoods: proteinFoods,
                carbFoods: carbFoods,
                fatFoods: fatFoods,
                produceFoods: produceFoods,
                likedFoods: likedFoods,
                preferLiked: i % 2 == 1,
                offset: dayIndex + i,
                used: &usedIds
            )
            meals.append(meal)
        }

        return meals
    }

    /// Builds one meal entry for a slot. Shared by the week builder and the
    /// swap-alternatives generator so alternatives follow the same rules and
    /// portion-scaling as the main plan.
    private static func makeMeal(
        name: String,
        time: String,
        calories: Int,
        proteinG: Int,
        slot: MealSlot,
        lowCarb: Bool,
        proteinFoods: [FoodItem],
        carbFoods: [FoodItem],
        fatFoods: [FoodItem],
        produceFoods: [FoodItem],
        likedFoods: [FoodItem],
        preferLiked: Bool,
        offset: Int,
        used: inout Set<String>
    ) -> MealPlanEntry {
        let isSnack = slot == .snack
        let isBreakfast = slot == .breakfast
        let template = templateMacros(isSnack: isSnack, isBreakfast: isBreakfast, lowCarb: lowCarb)
        // Fill remaining calories with carbs + fat, preserving the template's
        // macro shape so keto/low-carb plans stay low-carb at any calorie level.
        let remaining = max(calories - proteinG * 4, 0)
        let baseRemaining = max(template.calories - template.protein * 4, 1)
        let scale = Double(remaining) / Double(baseRemaining)
        let carbsG = Int((Double(template.carbs) * scale).rounded())
        let fatG = Int((Double(template.fat) * scale).rounded())

        // Slot-specific eligibility: a breakfast slot only draws from
        // breakfast foods, snacks only from snack foods, and lunch/dinner
        // only from proper main-meal foods — so yogurt never becomes dinner.
        var proteinIds: Set<String>
        var carbIds: Set<String>
        var produceIds: Set<String>
        var fatIds: Set<String>
        var produceTags: Set<String>
        var carbTags: Set<String>
        var carbSource: [FoodItem]
        var fallbackProtein: FoodItem
        var fallbackCarb: FoodItem
        var fallbackProduce: FoodItem
        var fallbackFat: FoodItem
        switch slot {
        case .breakfast:
            proteinIds = breakfastProteinIds
            carbIds = breakfastCarbIds
            produceIds = breakfastProduceIds
            fatIds = breakfastFatIds
            produceTags = ["fruit", "vegetable"]
            carbTags = ["carb", "fruit"]
            carbSource = carbFoods + produceFoods
            fallbackProtein = FoodItem(id: "eggs", name: "Eggs", emoji: "🥚", tags: ["protein"])
            fallbackCarb = FoodItem(id: "oats", name: "Oats", emoji: "🥣", tags: ["carb"])
            fallbackProduce = FoodItem(id: "berries", name: "Berries", emoji: "🫐", tags: ["fruit"])
            fallbackFat = FoodItem(id: "avocado", name: "Avocado", emoji: "🥑", tags: ["fat"])
        case .main:
            proteinIds = mainProteinIds
            carbIds = []
            produceIds = []
            fatIds = []
            produceTags = ["vegetable"]
            carbTags = ["carb"]
            carbSource = carbFoods
            fallbackProtein = FoodItem(id: "chicken", name: "Chicken", emoji: "🍗", tags: ["meat", "protein"])
            fallbackCarb = FoodItem(id: "rice", name: "Rice", emoji: "🍚", tags: ["carb"])
            fallbackProduce = FoodItem(id: "spinach", name: "Spinach", emoji: "🥬", tags: ["vegetable"])
            fallbackFat = FoodItem(id: "olive_oil", name: "Olive oil", emoji: "🫒", tags: ["fat"])
        case .snack:
            proteinIds = snackProteinIds
            carbIds = snackCarbIds
            produceIds = []
            fatIds = snackFatIds
            produceTags = ["fruit"]
            carbTags = ["carb", "fruit"]
            carbSource = carbFoods + produceFoods
            fallbackProtein = FoodItem(id: "greek_yogurt", name: "Greek yogurt", emoji: "🥛", tags: ["dairy", "protein"])
            fallbackCarb = FoodItem(id: "banana", name: "Banana", emoji: "🍌", tags: ["fruit"])
            fallbackProduce = FoodItem(id: "apple", name: "Apple", emoji: "🍎", tags: ["fruit"])
            fallbackFat = FoodItem(id: "nuts", name: "Mixed nuts", emoji: "🥜", tags: ["nuts", "fat"])
        }

        let protein = pickPreferring(
            slotPool(likedFoods.filter { $0.tags.contains("protein") }, ids: proteinIds),
            from: slotPool(proteinFoods, ids: proteinIds),
            preferLiked: preferLiked,
            offset: offset,
            used: &used,
            fallback: fallbackProtein
        )
        let carb = pickPreferring(
            slotPool(likedFoods.filter { $0.tags.contains(where: carbTags.contains) }, ids: carbIds),
            from: slotPool(carbSource, ids: carbIds),
            preferLiked: preferLiked,
            offset: offset + 1,
            used: &used,
            fallback: fallbackCarb
        )
        let produce = pickPreferring(
            slotPool(likedFoods.filter { $0.tags.contains(where: produceTags.contains) }, ids: produceIds),
            from: slotPool(produceFoods.filter { $0.tags.contains(where: produceTags.contains) }, ids: produceIds),
            preferLiked: preferLiked,
            offset: offset + 2,
            used: &used,
            fallback: fallbackProduce
        )
        let fat = pickPreferring(
            slotPool(likedFoods.filter { $0.tags.contains("fat") }, ids: fatIds),
            from: slotPool(fatFoods, ids: fatIds),
            preferLiked: preferLiked,
            offset: offset + 3,
            used: &used,
            fallback: fallbackFat
        )

        let title: String
        if isSnack {
            title = "\(protein.emoji) \(protein.name) & \(carb.emoji) \(carb.name)"
        } else if isBreakfast {
            title = "\(carb.emoji) \(carb.name) with \(protein.emoji) \(protein.name)"
        } else {
            title = "\(protein.emoji) \(protein.name) with \(carb.emoji) \(carb.name) & \(produce.emoji) \(produce.name)"
        }

        let items: [String]
        if isSnack {
            items = [
                "\(protein.name) (\(servingLabel(scaleTo: calories, base: template.calories)))",
                "\(carb.name) (\(servingLabel(scaleTo: calories, base: template.calories)))",
                "\(fat.name) (small serving)",
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

        return MealPlanEntry(
            mealName: name,
            time: time,
            title: title,
            items: items,
            calories: calories,
            proteinGrams: proteinG,
            carbsGrams: carbsG,
            fatGrams: fatG
        )
    }

    /// Picks the next unused food, prioritizing the user's liked foods when
    /// `preferLiked` is true. Skips foods already served that day; only repeats
    /// when the pool is exhausted. Falls back when the pool is empty.
    private static func pickPreferring(
        _ preferred: [FoodItem],
        from pool: [FoodItem],
        preferLiked: Bool,
        offset: Int,
        used: inout Set<String>,
        fallback: FoodItem
    ) -> FoodItem {
        func nextUnused(_ items: [FoodItem]) -> FoodItem? {
            guard !items.isEmpty else { return nil }
            let start = ((offset % items.count) + items.count) % items.count
            for step in 0..<items.count {
                let candidate = items[(start + step) % items.count]
                if !used.contains(candidate.id) { return candidate }
            }
            return items[start]
        }

        if preferLiked, let liked = nextUnused(preferred) {
            used.insert(liked.id)
            return liked
        }
        let chosen = nextUnused(pool) ?? fallback
        used.insert(chosen.id)
        return chosen
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

    // MARK: - Swap alternatives

    /// 2–3 alternative meals with the same calories and macro shape as `meal`
    /// for the meal-swap sheet. Same diet/allergen/disliked-food rules as the
    /// main plan; only the food combination (and portions) change.
    static func alternatives(for meal: MealPlanEntry, prefs: NutritionPreferences, profile: UserProfile?) -> [MealPlanEntry] {
        let pools = allowedFoods(prefs: prefs)
        let allowed = pools.all

        let proteinFoods = allowed.filter { $0.tags.contains("protein") }
        let carbFoods = allowed.filter { $0.tags.contains("carb") }.filter { _ in !lowCarbDiet(prefs.dietStyle) }
        let fatFoods = allowed.filter { $0.tags.contains("fat") }
        let produceFoods = allowed.filter { $0.tags.contains("vegetable") || $0.tags.contains("fruit") }

        let isLowCarb = lowCarbDiet(prefs.dietStyle)
        let slot: MealSlot = meal.mealName == "Breakfast" ? .breakfast : (meal.mealName == "Snack" ? .snack : .main)

        // Deterministic seed so the same meal always offers the same swaps.
        var seed: Int = 0
        for scalar in meal.title.unicodeScalars { seed = seed &* 31 &+ Int(scalar.value) }
        seed = abs(seed)

        var results: [MealPlanEntry] = []
        var seenTitles: Set<String> = [meal.title]

        var attempt = 0
        while results.count < 3 && attempt < 15 {
            var usedIds = Set<String>()
            let candidate = makeMeal(
                name: meal.mealName,
                time: meal.time,
                calories: meal.calories,
                proteinG: meal.proteinGrams,
                slot: slot,
                lowCarb: isLowCarb,
                proteinFoods: proteinFoods,
                carbFoods: carbFoods,
                fatFoods: fatFoods,
                produceFoods: produceFoods,
                likedFoods: pools.liked,
                preferLiked: attempt % 2 == 1,
                offset: seed + attempt * 7,
                used: &usedIds
            )
            if seenTitles.insert(candidate.title).inserted {
                results.append(candidate)
            }
            attempt += 1
        }
        return results
    }

    // MARK: - Meal slots

    /// Time-of-day slot for a meal; drives which foods are eligible so
    /// breakfast and snack foods never land in main meals (and vice versa).
    enum MealSlot {
        case breakfast, main, snack
    }

    // Catalog food ids appropriate for each slot. Used as an intersection
    // with the diet/allergen-filtered pools; a slot whose pool empties after
    // filtering falls back to the full pool so restricted diets still get
    // complete meals.
    private static let breakfastProteinIds: Set<String> = ["eggs", "greek_yogurt", "cottage_cheese", "tofu"]
    private static let mainProteinIds: Set<String> = ["chicken", "beef", "salmon", "tuna", "shrimp", "tofu", "beans", "lentils"]
    private static let snackProteinIds: Set<String> = ["greek_yogurt", "cottage_cheese", "eggs"]

    private static let breakfastCarbIds: Set<String> = ["oats", "bread", "quinoa", "sweet_potato"]
    private static let snackCarbIds: Set<String> = ["berries", "banana", "apple"]

    private static let breakfastProduceIds: Set<String> = ["berries", "banana", "apple", "spinach"]
    private static let breakfastFatIds: Set<String> = ["avocado", "nuts"]
    private static let snackFatIds: Set<String> = ["nuts", "avocado"]

    /// Slot-filtered subset of a pool. An empty id set means "no extra
    /// restriction"; if the id-filtered pool empties (diet/allergen rules),
    /// the full pool is used so the slot never runs out of food.
    private static func slotPool(_ pool: [FoodItem], ids: Set<String>) -> [FoodItem] {
        guard !ids.isEmpty else { return pool }
        let filtered = pool.filter { ids.contains($0.id) }
        return filtered.isEmpty ? pool : filtered
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

    // MARK: - Catalog filtering

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
