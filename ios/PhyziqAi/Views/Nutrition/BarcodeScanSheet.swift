import SwiftUI

/// Sheet that wraps the barcode scanner: shows the camera, then looks up the product
/// via OpenFoodFacts, then shows an editable result the user can log.
struct BarcodeScanSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let date: Date
    let initialMealSlot: MealSlot

    @State private var scannedBarcode: String?
    @State private var isLookingUp: Bool = false
    @State private var product: BarcodeProduct?
    @State private var errorMessage: String?
    @State private var mealSlot: MealSlot
    @State private var servings: Double = 1
    @State private var showManualEntry: Bool = false

    // Manual entry fields (used when barcode not found in database)
    @State private var manualName: String = ""
    @State private var manualBrand: String = ""
    @State private var manualCalories: String = ""
    @State private var manualProtein: String = ""
    @State private var manualCarbs: String = ""
    @State private var manualFat: String = ""
    @State private var manualServing: String = "1 serving"

    // Editable macros for products found via UPCItemDB (has name/brand but no nutrition)
    @State private var editCalories: String = ""
    @State private var editProtein: String = ""
    @State private var editCarbs: String = ""
    @State private var editFat: String = ""

    init(date: Date, initialMealSlot: MealSlot = .snack) {
        self.date = date
        self.initialMealSlot = initialMealSlot
        _mealSlot = State(initialValue: initialMealSlot)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()

                if let barcode = scannedBarcode {
                    // After scan: show lookup state or result
                    resultContent(barcode)
                } else {
                    // Camera scanner
                    BarcodeScannerView(
                        onDetected: { barcode in
                            Haptics.success()
                            scannedBarcode = barcode
                            Task { await lookupBarcode(barcode) }
                        },
                        onClose: {
                            dismiss()
                        }
                    )
                    .ignoresSafeArea()
                }
            }
            .navigationBarHidden(scannedBarcode == nil)
            .navigationTitle("Scan barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if scannedBarcode != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { dismiss() }
                            .foregroundStyle(Theme.textSecondary)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Haptics.impact(.light)
                            scannedBarcode = nil
                            product = nil
                            errorMessage = nil
                        } label: {
                            Label("Rescan", systemImage: "barcode.viewfinder")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Theme.accent)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Result content

    @ViewBuilder
    private func resultContent(_ barcode: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if isLookingUp {
                    lookingUpView(barcode)
                } else if let product = product {
                    productView(product)
                } else if showManualEntry {
                    manualEntryView(barcode)
                } else if let error = errorMessage {
                    errorView(error, barcode: barcode)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 60)
        }
        .scrollIndicators(.hidden)
        .background(Theme.bg)
    }

    // MARK: - Looking up

    private func lookingUpView(_ barcode: String) -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(Theme.accent)
                .scaleEffect(1.3)
            Text("Looking up product…")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text(barcode)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(Theme.surface))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .blueprintCard()
    }

    // MARK: - Product found

    private func productView(_ p: BarcodeProduct) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Product card
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    Text(p.emoji)
                        .font(.system(size: 40))
                        .frame(width: 64, height: 64)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.bg))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(p.name)
                            .font(.displayFont(18))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(2)
                        if let brand = p.brand, !brand.isEmpty {
                            Text(brand)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Text(p.barcode)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Theme.textSecondary.opacity(0.7))
                    }
                    Spacer()
                }

                Divider().background(Theme.hairline)

                // Serving info
                Text("Per serving: \(p.servingDescription)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)

                if p.hasNutritionData {
                    // Show macros from the database
                    let scaled = scaledMacros(p)
                    HStack(spacing: 14) {
                        macroTile(value: "\(scaled.cal)", label: "kcal", color: Theme.accent)
                        macroTile(value: "\(scaled.p)g", label: "Protein", color: Theme.success)
                        macroTile(value: "\(scaled.c)g", label: "Carbs", color: Theme.warning)
                        macroTile(value: "\(scaled.f)g", label: "Fat", color: Color.purple)
                    }
                } else {
                    // Product found but no nutrition data — prompt user to enter from label
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.warning)
                        Text("Found in product database. Enter the nutrition info from the label below.")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .padding(16)
            .blueprintCard()

            // Editable macros (only for products without nutrition data)
            if !p.hasNutritionData {
                VStack(alignment: .leading, spacing: 8) {
                    Text("NUTRITION PER SERVING")
                        .font(.system(size: 11, weight: .black))
                        .tracking(2)
                        .foregroundStyle(Theme.textSecondary)

                    HStack(spacing: 10) {
                        manualMacroField(label: "Calories", value: $editCalories, unit: "kcal", color: Theme.accent)
                        manualMacroField(label: "Protein", value: $editProtein, unit: "g", color: Theme.success)
                    }
                    HStack(spacing: 10) {
                        manualMacroField(label: "Carbs", value: $editCarbs, unit: "g", color: Theme.warning)
                        manualMacroField(label: "Fat", value: $editFat, unit: "g", color: Color.purple)
                    }
                }
            }

            // Servings stepper
            VStack(alignment: .leading, spacing: 10) {
                Text("SERVINGS")
                    .font(.system(size: 11, weight: .black))
                    .tracking(2)
                    .foregroundStyle(Theme.textSecondary)
                HStack {
                    Button {
                        Haptics.impact(.light)
                        if servings > 0.25 { servings -= 0.25 }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .disabled(servings <= 0.25)

                    Text(String(format: "%.2f", servings))
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity)

                    Button {
                        Haptics.impact(.light)
                        if servings < 10 { servings += 0.25 }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Theme.accent)
                    }
                    .disabled(servings >= 10)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Theme.surface)
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.hairline, lineWidth: 1))
                )
            }

            // Meal slot picker
            VStack(alignment: .leading, spacing: 8) {
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
                            .frame(height: 52)
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

            // Log button
            Button {
                logProduct(p)
            } label: {
                Label("Log this food", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Theme.accent))
            }
        }
    }

    private func scaledMacros(_ p: BarcodeProduct) -> (cal: Int, p: Int, c: Int, f: Int) {
        let multiplier = servings
        return (
            cal: Int(Double(p.caloriesPerServing) * multiplier),
            p: Int(Double(p.proteinGrams) * multiplier),
            c: Int(Double(p.carbsGrams) * multiplier),
            f: Int(Double(p.fatGrams) * multiplier)
        )
    }

    private func macroTile(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.08)))
    }

    // MARK: - Error

    private func errorView(_ message: String, barcode: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(Theme.warning)
            Text("Product not found")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Text(barcode)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.textSecondary.opacity(0.7))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Capsule().fill(Theme.surface))

            // Primary: enter manually
            Button {
                Haptics.impact(.light)
                showManualEntry = true
                errorMessage = nil
            } label: {
                Label("Enter manually", systemImage: "square.and.pencil")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.accent))
            }

            HStack(spacing: 10) {
                Button {
                    Haptics.impact(.light)
                    scannedBarcode = nil
                    product = nil
                    errorMessage = nil
                } label: {
                    Label("Rescan", systemImage: "barcode.viewfinder")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Theme.surface)
                                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.hairline, lineWidth: 1))
                        )
                }
                Button {
                    Haptics.impact(.light)
                    dismiss()
                } label: {
                    Text("Close")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Theme.surface)
                                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.hairline, lineWidth: 1))
                        )
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .blueprintCard()
    }

    // MARK: - Manual entry

    private func manualEntryView(_ barcode: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(spacing: 6) {
                Text("Enter product info")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("This product isn't in the food database yet. Check the label and enter the nutrition info per serving.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                Text(barcode)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary.opacity(0.6))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Theme.surface))
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 4)

            // Product name
            VStack(alignment: .leading, spacing: 8) {
                Text("PRODUCT NAME")
                    .font(.system(size: 11, weight: .black))
                    .tracking(2)
                    .foregroundStyle(Theme.textSecondary)
                TextField("e.g. Propel Water", text: $manualName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Theme.surface)
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.hairline, lineWidth: 1))
                    )
                    .textInputAutocapitalization(.words)
            }

            // Brand
            VStack(alignment: .leading, spacing: 8) {
                Text("BRAND (OPTIONAL)")
                    .font(.system(size: 11, weight: .black))
                    .tracking(2)
                    .foregroundStyle(Theme.textSecondary)
                TextField("e.g. Gatorade", text: $manualBrand)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Theme.surface)
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.hairline, lineWidth: 1))
                    )
                    .textInputAutocapitalization(.words)
            }

            // Serving description
            VStack(alignment: .leading, spacing: 8) {
                Text("SERVING SIZE")
                    .font(.system(size: 11, weight: .black))
                    .tracking(2)
                    .foregroundStyle(Theme.textSecondary)
                TextField("e.g. 1 bottle (20 fl oz)", text: $manualServing)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Theme.surface)
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.hairline, lineWidth: 1))
                    )
            }

            // Macros
            VStack(alignment: .leading, spacing: 8) {
                Text("NUTRITION PER SERVING")
                    .font(.system(size: 11, weight: .black))
                    .tracking(2)
                    .foregroundStyle(Theme.textSecondary)

                HStack(spacing: 10) {
                    manualMacroField(label: "Calories", value: $manualCalories, unit: "kcal", color: Theme.accent)
                    manualMacroField(label: "Protein", value: $manualProtein, unit: "g", color: Theme.success)
                }
                HStack(spacing: 10) {
                    manualMacroField(label: "Carbs", value: $manualCarbs, unit: "g", color: Theme.warning)
                    manualMacroField(label: "Fat", value: $manualFat, unit: "g", color: Color.purple)
                }
            }

            // Meal slot picker
            VStack(alignment: .leading, spacing: 8) {
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
                            .frame(height: 52)
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

            // Servings stepper
            VStack(alignment: .leading, spacing: 10) {
                Text("SERVINGS")
                    .font(.system(size: 11, weight: .black))
                    .tracking(2)
                    .foregroundStyle(Theme.textSecondary)
                HStack {
                    Button {
                        Haptics.impact(.light)
                        if servings > 0.25 { servings -= 0.25 }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .disabled(servings <= 0.25)

                    Text(String(format: "%.2f", servings))
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity)

                    Button {
                        Haptics.impact(.light)
                        if servings < 10 { servings += 0.25 }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Theme.accent)
                    }
                    .disabled(servings >= 10)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Theme.surface)
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.hairline, lineWidth: 1))
                )
            }

            // Log button
            Button {
                logManualProduct(barcode)
            } label: {
                Label("Log this food", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Theme.accent))
            }
            .disabled(manualName.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(manualName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
        }
        .padding(16)
        .blueprintCard()
    }

    private func manualMacroField(label: String, value: Binding<String>, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.textSecondary)
            HStack(spacing: 6) {
                TextField("0", text: value)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.leading)
                Text(unit)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.hairline, lineWidth: 1))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Logic

    private func lookupBarcode(_ barcode: String) async {
        isLookingUp = true
        errorMessage = nil
        product = nil
        do {
            let p = try await BarcodeService.lookup(barcode)
            isLookingUp = false
            product = p
            Haptics.success()
        } catch let error as BarcodeError {
            isLookingUp = false
            errorMessage = error.errorDescription
            Haptics.warning()
        } catch {
            isLookingUp = false
            errorMessage = "Something went wrong. Please try again."
            Haptics.warning()
        }
    }

    private func logProduct(_ p: BarcodeProduct) {
        let cal: Int
        let protein: Int
        let carbs: Int
        let fat: Int

        if p.hasNutritionData {
            let scaled = scaledMacros(p)
            cal = scaled.cal
            protein = scaled.p
            carbs = scaled.c
            fat = scaled.f
        } else {
            // Use user-entered macros from the editable fields
            let multiplier = servings
            cal = Int(Double(Int(editCalories) ?? 0) * multiplier)
            protein = Int(Double(Int(editProtein) ?? 0) * multiplier)
            carbs = Int(Double(Int(editCarbs) ?? 0) * multiplier)
            fat = Int(Double(Int(editFat) ?? 0) * multiplier)
        }

        appState.addFoodEntry(
            FoodLogEntry(
                name: p.name,
                emoji: p.emoji,
                mealSlot: mealSlot,
                calories: cal,
                proteinGrams: protein,
                carbsGrams: carbs,
                fatGrams: fat,
                servings: servings,
                loggedAt: Date()
            ),
            on: date
        )
        Haptics.success()
        dismiss()
    }

    private func logManualProduct(_ barcode: String) {
        let cal = Int(manualCalories) ?? 0
        let protein = Int(manualProtein) ?? 0
        let carbs = Int(manualCarbs) ?? 0
        let fat = Int(manualFat) ?? 0
        let multiplier = servings

        appState.addFoodEntry(
            FoodLogEntry(
                name: manualName.trimmingCharacters(in: .whitespaces),
                emoji: "📦",
                mealSlot: mealSlot,
                calories: Int(Double(cal) * multiplier),
                proteinGrams: Int(Double(protein) * multiplier),
                carbsGrams: Int(Double(carbs) * multiplier),
                fatGrams: Int(Double(fat) * multiplier),
                servings: servings,
                loggedAt: Date()
            ),
            on: date
        )
        Haptics.success()
        dismiss()
    }
}
