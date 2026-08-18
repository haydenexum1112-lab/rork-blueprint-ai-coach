import SwiftUI

/// Sheet for logging a food entry: pick from catalog, from today's meal plan, or type your own.
struct AddFoodSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let date: Date

    @State private var showBarcode: Bool = false
    @State private var mealSlot: MealSlot = .breakfast
    @State private var search: String = ""
    @State private var customName: String = ""
    @State private var customEmoji: String = "🍽️"
    @State private var servings: Double = 1
    @State private var showCustomEntry: Bool = false
    @State private var customCalories: String = ""
    @State private var customProtein: String = ""
    @State private var customCarbs: String = ""
    @State private var customFat: String = ""

    private var filteredFoods: [FoodItem] {
        let base = FoodCatalog.items
        if search.isEmpty { return base }
        return base.filter { $0.name.lowercased().contains(search.lowercased()) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    mealSlotPicker
                    barcodeButton
                    quickAddFromPlanSection
                    catalogSection
                    customEntrySection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(Theme.bg)
            .navigationTitle("Log food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .sheet(isPresented: $showBarcode) {
                BarcodeScanSheet(date: date, initialMealSlot: mealSlot)
            }
        }
    }

    // MARK: - Barcode button

    private var barcodeButton: some View {
        Button {
            Haptics.impact(.light)
            showBarcode = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.black)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Scan barcode")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.black)
                    Text("Look up packaged foods by barcode")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.black.opacity(0.7))
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.black)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.accent.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Theme.accent.opacity(0.4), lineWidth: 1.5)
                    )
            )
        }
    }

    // MARK: - Meal slot

    private var mealSlotPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MEAL")
                .font(.system(size: 11, weight: .black))
                .tracking(2)
                .foregroundStyle(Theme.textSecondary)
            HStack(spacing: 8) {
                ForEach(MealSlot.allCases) { slot in
                    Button {
                        Haptics.impact(.light)
                        mealSlot = slot
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: slot.icon)
                                .font(.system(size: 14))
                            Text(slot.display)
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(mealSlot == slot ? Color.black : Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(mealSlot == slot ? Theme.accent : Theme.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(mealSlot == slot ? Color.clear : Theme.hairline, lineWidth: 1)
                                )
                        )
                    }
                }
            }
        }
    }

    // MARK: - Quick add from today's plan

    private var quickAddFromPlanSection: some View {
        Group {
            if appState.hasNutrition && appState.hasNutritionPreferences,
               let prefs = appState.nutritionPreferences {
                let weekIndex = (Calendar.current.component(.weekday, from: date) + 5) % 7
                let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
                let plan = MealPlanGenerator.generateDay(prefs: prefs, dayName: dayNames[weekIndex], dayIndex: weekIndex)
                VStack(alignment: .leading, spacing: 10) {
                    Text("FROM YOUR PLAN")
                        .font(.system(size: 11, weight: .black))
                        .tracking(2)
                        .foregroundStyle(Theme.textSecondary)
                    VStack(spacing: 8) {
                        ForEach(plan.meals) { meal in
                            Button {
                                Haptics.success()
                                appState.addFoodEntry(
                                    FoodLogEntry(
                                        name: meal.title,
                                        emoji: "🍽️",
                                        mealSlot: slotForName(meal.mealName),
                                        calories: meal.calories,
                                        proteinGrams: meal.proteinGrams,
                                        carbsGrams: meal.carbsGrams,
                                        fatGrams: meal.fatGrams,
                                        servings: 1,
                                        loggedAt: Date()
                                    ),
                                    on: date
                                )
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: slotForName(meal.mealName).icon)
                                        .font(.system(size: 16))
                                        .foregroundStyle(Theme.accent)
                                        .frame(width: 28)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(meal.title)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(Theme.textPrimary)
                                            .lineLimit(2
)
                                        Text("\(meal.calories) kcal · \(meal.proteinGrams)g P")
                                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(Theme.accent)
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Theme.surface)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .strokeBorder(Theme.hairline, lineWidth: 1)
                                        )
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private func slotForName(_ name: String) -> MealSlot {
        let lower = name.lowercased()
        if lower.contains("breakfast") { return .breakfast }
        if lower.contains("lunch") { return .lunch }
        if lower.contains("dinner") { return .dinner }
        return .snack
    }

    // MARK: - Catalog

    private var catalogSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("FROM FOOD LIBRARY")
                .font(.system(size: 11, weight: .black))
                .tracking(2)
                .foregroundStyle(Theme.textSecondary)
            TextField("Search foods", text: $search)
                .font(.system(size: 15))
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.surface)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.hairline, lineWidth: 1))
                )

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(filteredFoods) { food in
                    Button {
                        Haptics.success()
                        let estimates = macroEstimates(for: food)
                        appState.addFoodEntry(
                            FoodLogEntry(
                                name: food.name,
                                emoji: food.emoji,
                                mealSlot: mealSlot,
                                calories: estimates.calories,
                                proteinGrams: estimates.protein,
                                carbsGrams: estimates.carbs,
                                fatGrams: estimates.fat,
                                servings: 1,
                                loggedAt: Date()
                            ),
                            on: date
                        )
                        dismiss()
                    } label: {
                        VStack(spacing: 6) {
                            Text(food.emoji).font(.system(size: 28))
                            Text(food.name)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Theme.accent)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 90)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Theme.surface)
                                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.hairline, lineWidth: 1))
                        )
                    }
                }
            }
        }
    }

    // MARK: - Custom entry

    private var customEntrySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.3)) { showCustomEntry.toggle() }
            } label: {
                HStack {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 15, weight: .bold))
                    Text("Log a custom food")
                        .font(.system(size: 15, weight: .bold))
                    Spacer()
                    Image(systemName: showCustomEntry ? "chevron.down" : "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(Theme.accent)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Theme.accent.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.accent.opacity(0.3), lineWidth: 1))
                )
            }

            if showCustomEntry {
                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NAME")
                            .font(.system(size: 11, weight: .black))
                            .tracking(2)
                            .foregroundStyle(Theme.textSecondary)
                        TextField("e.g. Protein shake", text: $customName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Theme.surface)
                                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.hairline, lineWidth: 1))
                            )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("MACROS (optional)")
                            .font(.system(size: 11, weight: .black))
                            .tracking(2)
                            .foregroundStyle(Theme.textSecondary)
                        HStack(spacing: 10) {
                            macroField(label: "kcal", text: $customCalories)
                            macroField(label: "P (g)", text: $customProtein)
                            macroField(label: "C (g)", text: $customCarbs)
                            macroField(label: "F (g)", text: $customFat)
                        }
                    }

                    Button {
                        guard !customName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        Haptics.success()
                        appState.addFoodEntry(
                            FoodLogEntry(
                                name: customName.trimmingCharacters(in: .whitespaces),
                                emoji: customEmoji.isEmpty ? "🍽️" : customEmoji,
                                mealSlot: mealSlot,
                                calories: Int(customCalories) ?? 0,
                                proteinGrams: Int(customProtein) ?? 0,
                                carbsGrams: Int(customCarbs) ?? 0,
                                fatGrams: Int(customFat) ?? 0,
                                servings: 1,
                                loggedAt: Date()
                            ),
                            on: date
                        )
                        dismiss()
                    } label: {
                        Text("Add to log")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(customName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(customName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Theme.surface)
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.hairline, lineWidth: 1))
                )
            }
        }
    }

    private func macroField(label: String, text: Binding<String>) -> some View {
        VStack(spacing: 4) {
            TextField(label, text: text)
                .keyboardType(.numberPad)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Theme.surfaceHi)
                )
        }
    }

    /// Rough macro estimates for catalog foods (per serving).
    private func macroEstimates(for food: FoodItem) -> (calories: Int, protein: Int, carbs: Int, fat: Int) {
        let isProtein = food.tags.contains("protein")
        let isCarb = food.tags.contains("carb")
        let isFat = food.tags.contains("fat")
        let isProduce = food.tags.contains("vegetable") || food.tags.contains("fruit")

        if isProtein {
            if food.id.contains("chicken") || food.id.contains("tuna") || food.id.contains("salmon") {
                return (220, 35, 0, 7)
            }
            if food.id.contains("beef") { return (250, 26, 0, 16) }
            if food.id.contains("eggs") { return (140, 12, 1, 10) }
            if food.id.contains("yogurt") || food.id.contains("cottage") { return (120, 18, 6, 4) }
            if food.id.contains("tofu") || food.id.contains("beans") || food.id.contains("lentils") {
                return (180, 14, 20, 5)
            }
            return (200, 25, 5, 8)
        }
        if isCarb {
            if food.id.contains("rice") || food.id.contains("pasta") || food.id.contains("quinoa") {
                return (220, 4, 45, 2)
            }
            if food.id.contains("oats") { return (150, 5, 27, 3) }
            if food.id.contains("potato") || food.id.contains("sweet_potato") {
                return (160, 3, 37, 0)
            }
            if food.id.contains("bread") { return (120, 4, 22, 2) }
            return (180, 4, 38, 2)
        }
        if isFat {
            if food.id.contains("avocado") { return (240, 3, 12, 22) }
            if food.id.contains("nuts") { return (200, 6, 7, 18) }
            if food.id.contains("olive_oil") { return (120, 0, 0, 14) }
            return (180, 3, 6, 16)
        }
        if isProduce {
            if food.id.contains("berries") || food.id.contains("banana") || food.id.contains("apple") {
                return (90, 1, 23, 0)
            }
            return (40, 2, 8, 0)
        }
        if food.tags.contains("treat") { return (170, 2, 20, 10) }
        return (100, 3, 15, 3)
    }
}
