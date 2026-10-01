import Foundation

/// Error thrown by the AI meal plan service.
nonisolated enum MealPlanAIError: LocalizedError {
    case missingConfig
    case badStatus(Int)
    case emptyResponse
    case parsing(String)

    var errorDescription: String? {
        switch self {
        case .missingConfig:
            return "Meal planning isn't configured yet. Please try again later."
        case .badStatus(let code):
            return "The meal planner returned an error (\(code)). Please try again."
        case .emptyResponse:
            return "The meal plan came back empty. Please try again."
        case .parsing:
            return "We couldn't read the meal plan. Please try again."
        }
    }
}

/// Cached AI-generated week, invalidated when preferences or targets change.
nonisolated struct CachedMealPlan: Codable {
    var fingerprint: String
    var generatedAt: Date
    var days: [DailyMealPlan]
}

/// Generates realistic daily meal plans with GPT-4o through the Rork Toolkit
/// proxy (same endpoint as the food scanner). Falls back to the deterministic
/// `MealPlanGenerator` whenever AI is unavailable, so the plan view never breaks.
nonisolated enum AIMealPlanService {
    static let modelId = "openai/gpt-4o"

    private static let cacheFileName = "meal_plan_ai.json"
    private static let schemaVersion = 2
    private static let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    // MARK: - Public API

    /// True when the cached AI week matches the current preferences and targets.
    static func hasFreshCache(prefs: NutritionPreferences, profile: UserProfile?) -> Bool {
        cachedWeek(prefs: prefs, profile: profile) != nil
    }

    /// Sync cache lookup — used by views that render instantly (calendar, quick add).
    static func cachedWeek(prefs: NutritionPreferences, profile: UserProfile?) -> [DailyMealPlan]? {
        guard let cached = loadCache() else { return nil }
        guard cached.fingerprint == fingerprint(prefs: prefs, profile: profile) else { return nil }
        guard cached.days.count == dayNames.count else { return nil }
        return cached.days
    }

    /// Generates a fresh AI week and caches it.
    static func generateAndCache(prefs: NutritionPreferences, profile: UserProfile?) async throws -> [DailyMealPlan] {
        let days = try await requestWeek(prefs: prefs, profile: profile)
        let cached = CachedMealPlan(
            fingerprint: fingerprint(prefs: prefs, profile: profile),
            generatedAt: Date(),
            days: days
        )
        saveCache(cached)
        return days
    }

    /// Drops the cached week (used by "Regenerate").
    static func clearCache() {
        try? FileManager.default.removeItem(at: cacheURL)
    }

    /// Best available plan day: cached AI day if fresh, else the deterministic
    /// generator. Used by calendar/quick-add surfaces that render synchronously.
    static func planDay(prefs: NutritionPreferences, profile: UserProfile?, dayName: String, dayIndex: Int) -> DailyMealPlan {
        if let week = cachedWeek(prefs: prefs, profile: profile), dayIndex >= 0, dayIndex < week.count {
            return week[dayIndex]
        }
        return MealPlanGenerator.generateDay(prefs: prefs, profile: profile, dayName: dayName, dayIndex: dayIndex)
    }

    // MARK: - Fingerprint

    /// Hash of everything that should invalidate the cached plan.
    static func fingerprint(prefs: NutritionPreferences, profile: UserProfile?) -> String {
        let targets = targets(for: profile)
        let components: [String] = [
            "v\(schemaVersion)",
            prefs.dietStyle.rawValue,
            prefs.allergens.map { $0.rawValue }.sorted().joined(separator: ","),
            prefs.customAllergens.joined(separator: ","),
            prefs.likedFoodIds.sorted().joined(separator: ","),
            prefs.dislikedFoodIds.sorted().joined(separator: ","),
            "\(prefs.mealFrequency.rawValue)",
            prefs.cookingTime.rawValue,
            "\(targets.calories)",
            "\(targets.proteinGrams)",
        ]
        return Self.stableHash(components.joined(separator: "|"))
    }

    private static func stableHash(_ string: String) -> String {
        var hash: UInt64 = 5381
        for byte in string.utf8 {
            hash = (hash &* 33) &+ UInt64(byte)
        }
        return String(format: "%016llx", hash)
    }

    static func targets(for profile: UserProfile?) -> DailyNutritionTargets {
        profile.map { NutritionTargetsCalculator.targets(for: $0) } ?? NutritionTargetsCalculator.fallback
    }

    // MARK: - AI request

    private static let systemPrompt = """
    You are PhyziqAi Meal Planner, an expert chef-nutritionist. You design weekly meal plans of REALISTIC, appealing meals that real people actually eat.

    REALISM RULES — MOST IMPORTANT:
    - Every meal must be a coherent, culturally normal combination that people genuinely eat — a real dish, not a random assortment of foods.
    - Breakfast must be breakfast foods (eggs, oatmeal, yogurt, toast, smoothies, pancakes...). Lunch and dinner must be typical meals people cook or order. Snacks must be actual snacks (protein shake, fruit + nuts, cottage cheese, hummus + veggies...).
    - NEVER pair foods that don't belong together (no "pasta and apple" for breakfast, no "eggs with rice and banana" for dinner).
    - Vary the meals across the week: no repeated dinners, no repeated lunches; breakfasts may repeat at most twice.
    - Portion sizes must be realistic for the calorie target — if the target is low, use smaller portions and lighter cooking methods; if high, use larger portions and calorie-dense additions.
    - Respect the user's cooking time: "Under 15 min" means simple meals with few components; "30+ min" allows proper cooked meals.
    - Estimating macros: count cooking oil, dressings, and sauces. Macros must be plausible for the foods listed.

    DIET RULES:
    - Strictly respect the user's diet style. Never include excluded ingredient groups.
    - NEVER include any listed allergen, in any form (check sauces, batters, oils, garnishes).
    - NEVER include disliked foods anywhere in the plan.
    - Feature the user's liked foods often — they chose them.
    - Every meal must contain a meaningful protein source appropriate to the diet.

    OUTPUT: Respond with ONLY a single valid JSON object. No markdown, no code fences, no commentary.

    OUTPUT SCHEMA (exact keys, no extras):
    {
      "days": [
        {
          "dayName": "Monday",
          "meals": [
            {
              "title": "Spinach & feta omelette with whole-grain toast",
              "items": ["3-egg omelette with spinach and feta", "2 slices whole-grain toast", "1 tsp olive oil"],
              "calories": 430,
              "proteinGrams": 32,
              "carbsGrams": 36,
              "fatGrams": 18
            }
          ]
        }
      ]
    }

    - Exactly 7 days, named Monday through Sunday in order.
    - Each day contains exactly the meals requested, in order (breakfast first, dinner last, snacks between meals).
    - "items" lists each component with its portion in plain language ("5 oz grilled chicken breast", "1 cup cooked rice").
    - Each day's meal macros must sum to approximately the daily targets (within ~5%).
    """

    private static func requestWeek(prefs: NutritionPreferences, profile: UserProfile?) async throws -> [DailyMealPlan] {
        let toolkitURL = RuntimeConfig.toolkitURL
        let secret = RuntimeConfig.rorkToolkitSecretKey
        guard !toolkitURL.isEmpty, !secret.isEmpty else {
            throw MealPlanAIError.missingConfig
        }

        let targets = Self.targets(for: profile)
        let mealNames = mealNames(for: prefs.mealFrequency)
        let likedNames = foodNames(from: prefs.likedFoodIds)
        let dislikedNames = foodNames(from: prefs.dislikedFoodIds)

        var restrictions: [String] = prefs.allergens.map { "NEVER include any form of \($0.display.lowercased())" }
        for custom in prefs.customAllergens where !custom.trimmingCharacters(in: .whitespaces).isEmpty {
            restrictions.append("NEVER include: \(custom.trimmingCharacters(in: .whitespaces))")
        }
        if !dislikedNames.isEmpty {
            restrictions.append("NEVER include these disliked foods: \(dislikedNames.joined(separator: ", "))")
        }

        let userPrompt = """
        Create a 7-day meal plan with these requirements:

        DAILY TARGETS (per day, all meals combined): about \(targets.calories) kcal and \(targets.proteinGrams) g protein. Carbs and fat should make up the remaining calories in plausible proportions.

        DIET STYLE: \(prefs.dietStyle.display) — \(prefs.dietStyle.subtitle). Follow it strictly.

        \(restrictions.isEmpty ? "" : "RESTRICTIONS:\n- " + restrictions.joined(separator: "\n- "))

        LIKED FOODS (feature these often): \(likedNames.isEmpty ? "no strong preferences" : likedNames.joined(separator: ", "))

        MEALS PER DAY, in this exact order: \(mealNames.joined(separator: ", "))

        COOKING TIME: \(prefs.cookingTime.display) per meal — \(prefs.cookingTime.subtitle).

        Return the JSON exactly per the schema. JSON only.
        """

        let body: [String: Any] = [
            "model": modelId,
            "max_tokens": 8000,
            "temperature": 0.7,
            "stream": false,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt],
            ],
        ]

        guard let url = URL(string: "\(toolkitURL)/v2/vercel/v1/chat/completions") else {
            throw MealPlanAIError.missingConfig
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 120
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            print("[AIMealPlan] Network error: \(error.localizedDescription)")
            throw MealPlanAIError.emptyResponse
        }

        guard let http = response as? HTTPURLResponse else {
            throw MealPlanAIError.emptyResponse
        }
        guard (200 ..< 300).contains(http.statusCode) else {
            print("[AIMealPlan] Bad status \(http.statusCode): \(String(data: data, encoding: .utf8)?.prefix(400) ?? "")")
            throw MealPlanAIError.badStatus(http.statusCode)
        }

        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any]
        else {
            print("[AIMealPlan] Failed to parse response envelope: \(String(data: data, encoding: .utf8)?.prefix(500) ?? "")")
            throw MealPlanAIError.emptyResponse
        }

        // Content can be a plain string (OpenAI) or an array of blocks (Anthropic).
        let content: String
        if let str = message["content"] as? String, !str.isEmpty {
            content = str
        } else if let blocks = message["content"] as? [[String: Any]] {
            content = blocks.compactMap { $0["text"] as? String }.joined()
        } else {
            throw MealPlanAIError.emptyResponse
        }
        guard !content.isEmpty else { throw MealPlanAIError.emptyResponse }

        let cleaned = FoodScanService.extractJSON(from: content)
        guard let cleanedData = cleaned.data(using: .utf8) else {
            throw MealPlanAIError.parsing("cleaned JSON not convertible to Data")
        }
        return try parseWeek(from: cleanedData, prefs: prefs)
    }

    // MARK: - Parsing

    /// Tolerant parse + validation: numbers may arrive as strings/doubles;
    /// day names and meal times are normalized locally so the rest of the
    /// app can rely on canonical values. Totals are always recomputed from meals.
    private static func parseWeek(from data: Data, prefs: NutritionPreferences) throws -> [DailyMealPlan] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MealPlanAIError.parsing("root is not a dictionary")
        }
        guard let rawDays = root["days"] as? [[String: Any]] else {
            throw MealPlanAIError.parsing("missing days array")
        }
        guard rawDays.count == dayNames.count else {
            throw MealPlanAIError.parsing("expected \(dayNames.count) days, got \(rawDays.count)")
        }

        let expectedMeals = mealNames(for: prefs.mealFrequency)

        func asInt(_ value: Any?) -> Int {
            if let i = value as? Int { return i }
            if let d = value as? Double { return Int(d.rounded()) }
            if let s = value as? String, let i = Int(s) { return i }
            return 0
        }

        var days: [DailyMealPlan] = []
        for (dayIndex, rawDay) in rawDays.enumerated() {
            guard let rawMeals = rawDay["meals"] as? [[String: Any]] else {
                throw MealPlanAIError.parsing("day \(dayIndex) has no meals array")
            }
            guard rawMeals.count == expectedMeals.count else {
                throw MealPlanAIError.parsing("day \(dayIndex) has \(rawMeals.count) meals, expected \(expectedMeals.count)")
            }

            let times = mealTimes(for: prefs.mealFrequency)
            var meals: [MealPlanEntry] = []
            for (mealIndex, rawMeal) in rawMeals.enumerated() {
                let title = (rawMeal["title"] as? String) ?? (rawMeal["name"] as? String) ?? ""
                let rawItems = rawMeal["items"] as? [Any] ?? []
                let items = rawItems.compactMap { $0 as? String }.filter { !$0.isEmpty }
                guard !title.isEmpty, !items.isEmpty else {
                    throw MealPlanAIError.parsing("day \(dayIndex) meal \(mealIndex) has no title or items")
                }
                let calories = asInt(rawMeal["calories"])
                guard calories > 0 else {
                    throw MealPlanAIError.parsing("day \(dayIndex) meal \(mealIndex) has zero calories")
                }
                meals.append(MealPlanEntry(
                    mealName: expectedMeals[mealIndex],
                    time: times[mealIndex],
                    title: title,
                    items: items,
                    calories: calories,
                    proteinGrams: asInt(rawMeal["proteinGrams"]),
                    carbsGrams: asInt(rawMeal["carbsGrams"]),
                    fatGrams: asInt(rawMeal["fatGrams"])
                ))
            }

            let totalCalories = meals.reduce(0) { $0 + $1.calories }
            guard totalCalories > 0 else {
                throw MealPlanAIError.parsing("day \(dayIndex) totals zero calories")
            }
            days.append(DailyMealPlan(
                dayName: dayNames[dayIndex],
                meals: meals,
                totalCalories: totalCalories,
                totalProtein: meals.reduce(0) { $0 + $1.proteinGrams },
                totalCarbs: meals.reduce(0) { $0 + $1.carbsGrams },
                totalFat: meals.reduce(0) { $0 + $1.fatGrams }
            ))
        }
        return days
    }

    // MARK: - Meal structure (canonical names/times shared with the fallback generator)

    private static func mealNames(for frequency: MealFrequency) -> [String] {
        switch frequency {
        case .three: return ["Breakfast", "Lunch", "Dinner"]
        case .four: return ["Breakfast", "Lunch", "Snack", "Dinner"]
        case .five: return ["Breakfast", "Snack", "Lunch", "Snack", "Dinner"]
        }
    }

    private static func mealTimes(for frequency: MealFrequency) -> [String] {
        switch frequency {
        case .three: return ["7:30 AM", "1:00 PM", "7:00 PM"]
        case .four: return ["7:30 AM", "1:00 PM", "4:00 PM", "7:00 PM"]
        case .five: return ["7:30 AM", "10:30 AM", "1:00 PM", "4:00 PM", "7:00 PM"]
        }
    }

    private static func foodNames(from ids: [String]) -> [String] {
        FoodCatalog.items.filter { ids.contains($0.id) }.map { $0.name }
    }

    // MARK: - Cache

    private static var cacheURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(cacheFileName)
    }

    private static func loadCache() -> CachedMealPlan? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? JSONDecoder().decode(CachedMealPlan.self, from: data)
    }

    private static func saveCache(_ cached: CachedMealPlan) {
        if let data = try? JSONEncoder().encode(cached) {
            try? data.write(to: cacheURL, options: .atomic)
        }
    }
}
