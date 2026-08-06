import SwiftUI

/// Nutrition tab — weekly meal plan gated behind a monthly add-on subscription.
struct NutritionTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(StoreManager.self) private var store

    @State private var selectedDayIndex: Int = 0
    @State private var showSurvey: Bool = false
    @State private var showPaywall: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                BlueprintGridBackground().ignoresSafeArea()

                if !appState.hasNutrition {
                    lockedView
                } else if !appState.hasNutritionPreferences {
                    needsSurveyView
                } else {
                    planView
                }
            }
            .navigationTitle("Nutrition")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showSurvey) {
                NutritionSurveyView()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
                    .environment(appState)
                    .environment(store)
            }
        }
    }

    // MARK: - Locked (no subscription)

    private var lockedView: some View {
        ScrollView {
            VStack(spacing: 28) {
                ZStack {
                    Circle()
                        .fill(Theme.surface)
                        .overlay(Circle().strokeBorder(Theme.accent.opacity(0.3), lineWidth: 1))
                        .frame(width: 92, height: 92)
                    Image(systemName: "fork.knife")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }
                .padding(.top, 20)

                VStack(spacing: 10) {
                    Text("Nutrition")
                        .font(.displayFont(30))
                        .foregroundStyle(Theme.textPrimary)
                    Text("BLUEPRINT ADD-ON")
                        .font(.system(size: 11, weight: .black))
                        .tracking(4)
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Theme.accent))
                }

                VStack(spacing: 14) {
                    lockedBenefit(icon: "fork.knife", text: "Daily meal plans matched to your training split")
                    lockedBenefit(icon: "heart.fill", text: "Built from foods you like — never what you don't")
                    lockedBenefit(icon: "exclamationmark.shield.fill", text: "Allergens and diet style respected")
                    lockedBenefit(icon: "chart.bar.fill", text: "Protein, carbs, and fat targets per meal")
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: Theme.cardRadius)
                        .fill(Theme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.cardRadius)
                                .strokeBorder(Theme.hairline, lineWidth: 1)
                        )
                )

                VStack(spacing: 8) {
                    Text("$7.99")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Text("per month · 3 days free")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }

                Button {
                    Haptics.impact(.light)
                    showPaywall = true
                } label: {
                    Text("Unlock Nutrition")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 20)

                Text("3-day free trial, then $7.99/month. Cancel anytime.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
    }

    private func lockedBenefit(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 26)
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Subscribed but no survey yet

    private var needsSurveyView: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.12))
                    .frame(width: 92, height: 92)
                Image(systemName: "list.clipboard.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(Theme.accent)
            }
            .padding(.top, 20)

            VStack(spacing: 10) {
                Text("Tell us what you eat")
                    .font(.displayFont(28))
                    .foregroundStyle(Theme.textPrimary)
                Text("A quick survey builds your meal plan around your tastes — the foods you love, the ones you avoid, and how much time you have to cook.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
                    .lineSpacing(3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Button {
                Haptics.impact(.light)
                showSurvey = true
            } label: {
                Text("Start survey")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 20)

            Text("Takes about 2 minutes. You can retake it anytime.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary.opacity(0.7))
        }
    }

    // MARK: - Trial banner

    private func trialBanner(daysLeft: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.black)
            VStack(alignment: .leading, spacing: 2) {
                Text("Nutrition trial")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.black)
                Text(daysLeft == 1 ? "1 day left — subscribe to keep it" : "\(daysLeft) days left — subscribe to keep it")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.black.opacity(0.75))
            }
            Spacer()
            Button {
                Haptics.impact(.light)
                showPaywall = true
            } label: {
                Text("Subscribe")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.white))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.accent.opacity(0.18))
    }

    // MARK: - Plan view

    private var planView: some View {
        Group {
            if let prefs = appState.nutritionPreferences {
                let week = MealPlanGenerator.generateWeek(prefs: prefs)
                let day = week[selectedDayIndex]
                VStack(spacing: 0) {
                    if let daysLeft = appState.trialDaysLeft, appState.hasNutritionAccess {
                        trialBanner(daysLeft: daysLeft)
                    }
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            summaryCard(day: day, prefs: prefs)
                            dayPicker(week: week)
                            mealList(day: day)
                            FoodLogView()
                            DisclaimerFooter()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 100)
                    }
                    .scrollIndicators(.hidden)

                    bottomBar
                }
            } else {
                Text("No preferences saved.")
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private func summaryCard(day: DailyMealPlan, prefs: NutritionPreferences) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DAILY TARGETS")
                        .font(.system(size: 11, weight: .black))
                        .tracking(2)
                        .foregroundStyle(Theme.accent)
                    Text(day.dayName)
                        .font(.displayFont(26))
                        .foregroundStyle(Theme.textPrimary)
                }
                Spacer()
                Button {
                    Haptics.impact(.light)
                    showSurvey = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Theme.surface))
                }
                .accessibilityLabel("Retake survey")
            }

            HStack(spacing: 12) {
                macroTile(value: "\(day.totalCalories)", label: "kcal", tint: Theme.accent)
                macroTile(value: "\(day.totalProtein)g", label: "Protein", tint: Theme.success)
                macroTile(value: "\(day.totalCarbs)g", label: "Carbs", tint: Theme.warning)
                macroTile(value: "\(day.totalFat)g", label: "Fat", tint: Color.purple)
            }

            HStack(spacing: 8) {
                Image(systemName: prefs.dietStyle.icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.accent)
                Text(prefs.dietStyle.display)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                if !prefs.allergens.isEmpty {
                    Text("·")
                        .foregroundStyle(Theme.textSecondary.opacity(0.5))
                    Text(prefs.allergens.map(\.display).joined(separator: ", "))
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cardRadius)
                        .strokeBorder(Theme.accent.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func macroTile(value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(tint)
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .tracking(1)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.bg)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                )
        )
    }

    private func dayPicker(week: [DailyMealPlan]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(week.indices, id: \.self) { index in
                    let day = week[index]
                    Button {
                        Haptics.impact(.light)
                        withAnimation { selectedDayIndex = index }
                    } label: {
                        VStack(spacing: 4) {
                            Text(String(day.dayName.prefix(3)).uppercased())
                                .font(.system(size: 11, weight: .black))
                                .tracking(1)
                            Text("\(day.meals.count)")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundStyle(selectedDayIndex == index ? Color.black : Theme.textPrimary)
                        .frame(width: 52, height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedDayIndex == index ? Theme.accent : Theme.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(selectedDayIndex == index ? Color.clear : Theme.hairline, lineWidth: 1)
                                )
                        )
                    }
                    .accessibilityLabel(day.dayName)
                }
            }
            .padding(.horizontal, 0)
        }
        .contentMargins(.horizontal, 0)
    }

    private func mealList(day: DailyMealPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Today's meals", icon: "fork.knife", tint: Theme.accent)
            VStack(spacing: 10) {
                ForEach(day.meals) { meal in
                    mealCard(meal)
                }
            }
        }
    }

    private func mealCard(_ meal: MealPlanEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(meal.mealName.uppercased())
                        .font(.system(size: 11, weight: .black))
                        .tracking(2)
                        .foregroundStyle(Theme.accent)
                    Text(meal.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Text(meal.time)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(meal.items, id: \.self) { item in
                    HStack(spacing: 8) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 4))
                            .foregroundStyle(Theme.accent.opacity(0.6))
                        Text(item)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textPrimary)
                    }
                }
            }

            HStack(spacing: 16) {
                macroChip(value: "\(meal.calories)", label: "kcal")
                macroChip(value: "\(meal.proteinGrams)g", label: "P")
                macroChip(value: "\(meal.carbsGrams)g", label: "C")
                macroChip(value: "\(meal.fatGrams)g", label: "F")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cardRadius)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                )
        )
    }

    private func macroChip(value: String, label: String) -> some View {
        HStack(spacing: 3) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button {
                Haptics.impact(.light)
                showSurvey = true
            } label: {
                Label("Retake survey", systemImage: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Theme.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(Theme.hairline, lineWidth: 1)
                            )
                    )
            }
            Button {
                Haptics.impact(.light)
                showPaywall = true
            } label: {
                Label("Manage", systemImage: "creditcard.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Theme.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(Theme.hairline, lineWidth: 1)
                            )
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Theme.bg.opacity(0.95))
    }
}
