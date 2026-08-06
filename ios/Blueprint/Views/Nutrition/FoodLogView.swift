import SwiftUI

/// Today's food log: macro ring summary, meal slots, entries, and add button.
struct FoodLogView: View {
    @Environment(AppState.self) private var appState

    @State private var showAddFood: Bool = false
    @State private var showScan: Bool = false
    @State private var showBarcode: Bool = false
    @State private var entryToDelete: FoodLogEntry?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                macroSummary
                scanBanner
                entriesList
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(Theme.bg)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 8) {
                Button {
                    Haptics.impact(.light)
                    showScan = true
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 18, weight: .bold))
                        Text("Photo")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.accent))
                }
                Button {
                    Haptics.impact(.light)
                    showBarcode = true
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "barcode.viewfinder")
                            .font(.system(size: 18, weight: .bold))
                        Text("Barcode")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.accent.opacity(0.25)))
                }
                Button {
                    Haptics.impact(.light)
                    showAddFood = true
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                        Text("Manual")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Theme.surface)
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.hairline, lineWidth: 1))
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Theme.bg.opacity(0.95))
        }
        .sheet(isPresented: $showAddFood) {
            AddFoodSheet(date: Date())
        }
        .sheet(isPresented: $showScan) {
            FoodScanView(date: Date())
        }
        .sheet(isPresented: $showBarcode) {
            BarcodeScanSheet(date: Date())
        }
    }

    // MARK: - Scan banner

    private var scanBanner: some View {
        Button {
            Haptics.impact(.light)
            showScan = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.black)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Scan a meal")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.black)
                    Text("Snap a photo — AI identifies the food and macros")
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

    // MARK: - Macro summary

    private var macroSummary: some View {
        VStack(spacing: 14) {
            HStack(spacing: 20) {
                MacroRing(
                    value: appState.todaysCalories,
                    target: dailyCalorieTarget,
                    label: "CALORIES",
                    unit: "kcal",
                    color: Theme.accent
                )
                VStack(alignment: .leading, spacing: 10) {
                    MacroBar(value: appState.todaysProtein, target: dailyProteinTarget, label: "Protein", color: Theme.success)
                    MacroBar(value: appState.todaysCarbs, target: dailyCarbTarget, label: "Carbs", color: Theme.warning)
                    MacroBar(value: appState.todaysFat, target: dailyFatTarget, label: "Fat", color: Color.purple)
                }
            }
            if appState.todaysEntries().isEmpty {
                Text("Tap **Log food** to start tracking what you eat today.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
        .padding(18)
        .blueprintCard()
    }

    /// Rough calorie target derived from bodyweight + profile (not a medical prescription).
    private var dailyCalorieTarget: Int {
        guard let p = appState.profile else { return 2400 }
        // Maintenance ≈ bodyweight (kg) × 33 for active adults
        return Int(p.weightKg * 33)
    }

    private var dailyProteinTarget: Int {
        guard let p = appState.profile else { return 150 }
        // 1.8 g/kg for muscle building
        return Int(p.weightKg * 1.8)
    }

    private var dailyCarbTarget: Int {
        guard let p = appState.profile else { return 250 }
        // 3 g/kg
        return Int(p.weightKg * 3)
    }

    private var dailyFatTarget: Int {
        guard let p = appState.profile else { return 70 }
        // 0.8 g/kg
        return Int(p.weightKg * 0.8)
    }

    // MARK: - Entries list

    private var entriesList: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Today's log", icon: "list.bullet.rectangle")
            let grouped = appState.todaysFoodLog().entriesBySlot()
            if grouped.isEmpty {
                Text("Nothing logged yet.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 16) {
                    ForEach(grouped, id: \.0) { slot, entries in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: slot.icon)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Theme.accent)
                                Text(slot.display.uppercased())
                                    .font(.system(size: 12, weight: .black))
                                    .tracking(2)
                                    .foregroundStyle(Theme.textSecondary)
                                Spacer()
                                let slotCalories = entries.reduce(0) { $0 + $1.calories }
                                Text("\(slotCalories) kcal")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            ForEach(entries) { entry in
                                FoodEntryRow(entry: entry) {
                                    entryToDelete = entry
                                    appState.removeFoodEntry(id: entry.id)
                                    Haptics.impact(.light)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Macro ring

private struct MacroRing: View {
    let value: Int
    let target: Int
    let label: String
    let unit: String
    let color: Color

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(1, Double(value) / Double(target))
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.surfaceHi, lineWidth: 10)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: progress)
            VStack(spacing: 2) {
                Text("\(value)")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text(unit)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Theme.textSecondary)
                Text(label)
                    .font(.system(size: 9, weight: .black))
                    .tracking(1)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(width: 110, height: 110)
    }
}

// MARK: - Macro bar

private struct MacroBar: View {
    let value: Int
    let target: Int
    let label: String
    let color: Color

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(1, Double(value) / Double(target))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("\(value)/\(target)g")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.textPrimary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.surfaceHi).frame(height: 6)
                    Capsule().fill(color).frame(width: geo.size.width * progress, height: 6)
                        .animation(.spring(response: 0.4), value: progress)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Food entry row

private struct FoodEntryRow: View {
    let entry: FoodLogEntry
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(entry.emoji)
                .font(.system(size: 24))
                .frame(width: 36, height: 36)
                .background(Circle().fill(Theme.surface))
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                HStack(spacing: 10) {
                    if entry.calories > 0 {
                        Text("\(entry.calories) kcal")
                    }
                    if entry.proteinGrams > 0 {
                        Text("\(entry.proteinGrams)g P")
                    }
                    if entry.carbsGrams > 0 {
                        Text("\(entry.carbsGrams)g C")
                    }
                    if entry.fatGrams > 0 {
                        Text("\(entry.fatGrams)g F")
                    }
                }
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Button {
                onDelete()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.warning.opacity(0.8))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.surface)
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.hairline, lineWidth: 1))
        )
    }
}
