import SwiftUI

/// Survey to capture diet style, allergens (preset + custom), liked/disliked foods, and meal frequency.
struct NutritionSurveyView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    private enum Step: Int, CaseIterable {
        case diet
        case allergens
        case likes
        case dislikes
        case frequency
        case cooking
    }

    @State private var step: Step = .diet
    @State private var dietStyle: DietStyle = .omnivore
    @State private var allergens: Set<Allergen> = []
    @State private var customAllergenInput: String = ""
    @State private var customAllergens: [String] = []
    @State private var likedFoodIds: Set<String> = []
    @State private var dislikedFoodIds: Set<String> = []
    @State private var mealFrequency: MealFrequency = .four
    @State private var cookingTime: CookingTime = .moderate

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    stepHeader
                    stepContent
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(step == .cooking ? "Save preferences" : "Continue") {
                    Haptics.impact(.light)
                    if step == .cooking {
                        save()
                    } else {
                        advance()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Theme.bg.opacity(0.95))
            }
        }
    }

    private var progressFraction: CGFloat {
        switch step {
        case .diet: return 0.17
        case .allergens: return 0.34
        case .likes: return 0.51
        case .dislikes: return 0.68
        case .frequency: return 0.85
        case .cooking: return 1
        }
    }

    private var stepHeader: some View {
        VStack(spacing: 14) {
            HStack {
                Button {
                    Haptics.impact(.light)
                    goBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Theme.surface))
                }
                .opacity(step == .diet ? 0 : 1)
                .disabled(step == .diet)
                Spacer()
                Text("NUTRITION SURVEY")
                    .font(.system(size: 13, weight: .black))
                    .tracking(4)
                    .foregroundStyle(Theme.accent)
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 16)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.surfaceHi)
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: geo.size.width * progressFraction)
                        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: step)
                }
            }
            .frame(height: 5)
            .padding(.horizontal, 24)
        }
        .padding(.top, 8)
        .padding(.bottom, 20)
    }

    @ViewBuilder
    private var stepContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                switch step {
                case .diet:
                    dietStep
                case .allergens:
                    allergensStep
                case .likes:
                    likesStep
                case .dislikes:
                    dislikesStep
                case .frequency:
                    frequencyStep
                case .cooking:
                    cookingStep
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Diet

    private var dietStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            SurveyStepTitle(title: "How do you eat?", subtitle: "Your plan will only include foods that fit your style. Pick the one that matches you best.")
            VStack(spacing: 18) {
                ForEach(dietGroups, id: \.self) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(group.uppercased())
                            .font(.system(size: 11, weight: .black))
                            .tracking(2)
                            .foregroundStyle(Theme.textSecondary)
                        VStack(spacing: 10) {
                            ForEach(DietStyle.allCases.filter { $0.group == group }) { style in
                                SurveySelectableRow(
                                    title: style.display,
                                    subtitle: style.subtitle,
                                    icon: style.icon,
                                    isSelected: dietStyle == style
                                ) {
                                    dietStyle = style
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var dietGroups: [String] {
        // Preserve insertion order from DietStyle.group
        var seen: Set<String> = []
        var ordered: [String] = []
        for style in DietStyle.allCases {
            if !seen.contains(style.group) {
                seen.insert(style.group)
                ordered.append(style.group)
            }
        }
        return ordered
    }

    // MARK: - Allergens (preset chips + custom text entry)

    private var allergensStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            SurveyStepTitle(title: "Anything to avoid?", subtitle: "Select common allergens and add anything else we should keep out of your plan.")

            VStack(alignment: .leading, spacing: 10) {
                Text("COMMON ALLERGENS")
                    .font(.system(size: 11, weight: .black))
                    .tracking(2)
                    .foregroundStyle(Theme.textSecondary)
                VStack(spacing: 10) {
                    ForEach(Allergen.allCases) { allergen in
                        SurveySelectableRow(
                            title: allergen.display,
                            subtitle: nil,
                            icon: allergens.contains(allergen) ? "checkmark.circle.fill" : "circle",
                            isSelected: allergens.contains(allergen)
                        ) {
                            if allergens.contains(allergen) {
                                allergens.remove(allergen)
                            } else {
                                allergens.insert(allergen)
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("YOUR OWN RESTRICTIONS")
                    .font(.system(size: 11, weight: .black))
                    .tracking(2)
                    .foregroundStyle(Theme.textSecondary)
                Text("Type anything else you're allergic to or avoid — pork, coriander, nightshades, FODMAP, anything.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)

                HStack(spacing: 10) {
                    TextField("e.g. coriander", text: $customAllergenInput)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Theme.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Theme.hairline, lineWidth: 1)
                                )
                        )
                        .submitLabel(.done)
                        .onSubmit { addCustomAllergen() }

                    Button {
                        addCustomAllergen()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(customAllergenInput.trimmingCharacters(in: .whitespaces).isEmpty ? Theme.textTertiary : Theme.accent)
                    }
                    .disabled(customAllergenInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                if !customAllergens.isEmpty {
                    FlowingChips(items: customAllergens) { item in
                        Button {
                            Haptics.impact(.light)
                            customAllergens.removeAll { $0.caseInsensitiveCompare(item) == .orderedSame }
                        } label: {
                            HStack(spacing: 6) {
                                Text(item)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(Theme.accent.opacity(0.12))
                                    .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.4), lineWidth: 1))
                            )
                        }
                    }
                }
            }

            Text("Optional — tap Continue if nothing applies.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func addCustomAllergen() {
        let trimmed = customAllergenInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard !customAllergens.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
            customAllergenInput = ""
            return
        }
        Haptics.impact(.light)
        customAllergens.append(trimmed)
        customAllergenInput = ""
    }

    // MARK: - Likes / Dislikes

    private var likesStep: some View {
        foodGridStep(
            title: "What do you love?",
            subtitle: "Tap every food you enjoy. These anchor your meal plan.",
            selectedIds: $likedFoodIds,
            tint: Theme.success,
            emptyIcon: "heart"
        )
    }

    private var dislikesStep: some View {
        foodGridStep(
            title: "What won't you eat?",
            subtitle: "Tap anything you'd rather avoid. We'll build around it.",
            selectedIds: $dislikedFoodIds,
            tint: Theme.warning,
            emptyIcon: "heart.slash"
        )
    }

    private func foodGridStep(title: String, subtitle: String, selectedIds: Binding<Set<String>>, tint: Color, emptyIcon: String) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            SurveyStepTitle(title: title, subtitle: subtitle)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(FoodCatalog.items) { food in
                    let isOn = selectedIds.wrappedValue.contains(food.id)
                    Button {
                        Haptics.impact(.light)
                        if isOn {
                            selectedIds.wrappedValue.remove(food.id)
                        } else {
                            selectedIds.wrappedValue.insert(food.id)
                        }
                    } label: {
                        VStack(spacing: 8) {
                            Text(food.emoji)
                                .font(.system(size: 32))
                            Text(food.name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Image(systemName: isOn ? "checkmark.circle.fill" : emptyIcon)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(isOn ? tint : Theme.textSecondary.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 100)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Theme.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(isOn ? tint.opacity(0.6) : Theme.hairline, lineWidth: isOn ? 1.5 : 1)
                                )
                        )
                    }
                    .accessibilityLabel("\(food.name), \(isOn ? "selected" : "not selected")")
                }
            }
        }
    }

    // MARK: - Frequency

    private var frequencyStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            SurveyStepTitle(title: "How often do you eat?", subtitle: "We'll split your daily intake across these meals.")
            VStack(spacing: 10) {
                ForEach(MealFrequency.allCases) { freq in
                    SurveySelectableRow(
                        title: freq.display,
                        subtitle: freq.subtitle,
                        icon: "calendar",
                        isSelected: mealFrequency == freq
                    ) {
                        mealFrequency = freq
                    }
                }
            }
        }
    }

    // MARK: - Cooking

    private var cookingStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            SurveyStepTitle(title: "How long can you cook?", subtitle: "We'll match recipe complexity to your time.")
            VStack(spacing: 10) {
                ForEach(CookingTime.allCases) { time in
                    SurveySelectableRow(
                        title: time.display,
                        subtitle: time.subtitle,
                        icon: time.icon,
                        isSelected: cookingTime == time
                    ) {
                        cookingTime = time
                    }
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("YOUR SELECTIONS")
                    .font(.system(size: 11, weight: .black))
                    .tracking(2)
                    .foregroundStyle(Theme.textSecondary)
                Text("\(dietStyle.display) · \(mealFrequency.display) · \(cookingTime.display)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                if !allergens.isEmpty || !customAllergens.isEmpty {
                    let all = allergens.map(\.display) + customAllergens
                    Text("Avoiding: \(all.joined(separator: ", "))")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                }
                Text("\(likedFoodIds.count) liked · \(dislikedFoodIds.count) avoided")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .blueprintCard()
        }
    }

    // MARK: - Navigation

    private func advance() {
        withAnimation {
            switch step {
            case .diet: step = .allergens
            case .allergens: step = .likes
            case .likes: step = .dislikes
            case .dislikes: step = .frequency
            case .frequency: step = .cooking
            case .cooking: break
            }
        }
    }

    private func goBack() {
        withAnimation {
            switch step {
            case .diet: break
            case .allergens: step = .diet
            case .likes: step = .allergens
            case .dislikes: step = .likes
            case .frequency: step = .dislikes
            case .cooking: step = .frequency
            }
        }
    }

    private func save() {
        let prefs = NutritionPreferences(
            dietStyle: dietStyle,
            allergens: Array(allergens),
            customAllergens: customAllergens,
            likedFoodIds: Array(likedFoodIds),
            dislikedFoodIds: Array(dislikedFoodIds),
            mealFrequency: mealFrequency,
            cookingTime: cookingTime
        )
        Haptics.success()
        appState.saveNutritionPreferences(prefs)
        dismiss()
    }
}

private struct SurveyStepTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.displayFont(30))
                .foregroundStyle(Theme.textPrimary)
            Text(subtitle)
                .font(.system(size: 15))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(3)
        }
    }
}

private struct SurveySelectableRow: View {
    let title: String
    let subtitle: String?
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.impact(.light)
            action()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(isSelected ? Theme.accent.opacity(0.6) : Theme.hairline, lineWidth: 1)
                    )
            )
        }
    }
}

/// Simple wrapping chip layout.
private struct FlowingChips<Item: Hashable, Content: View>: View {
    let items: [Item]
    @ViewBuilder let content: (Item) -> Content

    var body: some View {
        GeometryReader { geo in
            self.generateContent(in: geo.size)
        }
        .frame(minHeight: 36)
    }

    private func generateContent(in size: CGSize) -> some View {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rows: [[Item]] = [[]]
        let padding: CGFloat = 8
        // Estimate widths
        for item in items {
            let label = String(describing: item)
            let width = label.size(withFont: UIFont.systemFont(ofSize: 13, weight: .semibold)).width + 44
            if x + width > size.width {
                rows.append([item])
                x = width + padding
                y += 36
            } else {
                rows[rows.count - 1].append(item)
                x += width + padding
            }
        }
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { item in
                        content(item)
                    }
                    Spacer()
                }
            }
        }
    }
}

private extension String {
    func size(withFont font: UIFont) -> CGSize {
        let attributes = [NSAttributedString.Key.font: font]
        return (self as NSString).size(withAttributes: attributes)
    }
}

