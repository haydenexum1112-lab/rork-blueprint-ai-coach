import SwiftUI
import StoreKit

/// Unified paywall — "Choose Your Plan" with 3 tiers and 7-day free trial.
/// Wired to StoreKit 2 via StoreManager for real in-app purchases.
struct PaywallView: View {
    @Environment(AppState.self) private var appState
    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss

    private enum BillingPeriod: String, CaseIterable, Identifiable {
        case monthly, annual
        var id: String { rawValue }
        var display: String { self == .annual ? "Annual" : "Monthly" }
    }

    @State private var selectedTier: SubscriptionTier = .everything
    @State private var billing: BillingPeriod = .annual
    @State private var appeared: Bool = false

    /// Live price from StoreKit, falling back to hardcoded display if products not yet fetched.
    private var priceForTier: String {
        let annual = billing == .annual
        if let price = store.priceString(for: selectedTier, annual: annual) {
            return annual ? "\(price)/yr" : "\(price)/mo"
        }
        switch (selectedTier, billing) {
        case (.workouts, .monthly): return "$12.99/mo"
        case (.workouts, .annual): return "$79/yr"
        case (.nutrition, .monthly): return "$7.99/mo"
        case (.nutrition, .annual): return "$49/yr"
        case (.everything, .monthly): return "$16.99/mo"
        case (.everything, .annual): return "$99/yr"
        }
    }

    private var effectiveMonthly: String? {
        guard billing == .annual else { return nil }
        switch selectedTier {
        case .workouts: return "$6.58/mo"
        case .nutrition: return "$4.08/mo"
        case .everything: return "$8.25/mo"
        }
    }

    private var savingsText: String? {
        guard selectedTier == .everything else { return nil }
        return "Save 18% vs separate"
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            BlueprintGridBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(Theme.surface))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("CHOOSE YOUR PLAN")
                                .font(.system(size: 12, weight: .black))
                                .tracking(5)
                                .foregroundStyle(Theme.accent)
                            Text("7 days free.\nThen unlock everything.")
                                .font(.displayFont(34))
                                .foregroundStyle(Theme.textPrimary)
                                .lineSpacing(2)
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 14)

                        Picker("", selection: $billing) {
                            ForEach(BillingPeriod.allCases) { period in
                                Text(period.display).tag(period)
                            }
                        }
                        .pickerStyle(.segmented)
                        .opacity(appeared ? 1 : 0)

                        VStack(spacing: 12) {
                            tierCard(.workouts)
                            tierCard(.nutrition)
                            tierCard(.everything)
                        }
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 14)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .scrollIndicators(.hidden)

                VStack(spacing: 12) {
                    Button {
                        Task {
                            Haptics.success()
                            let success = await store.purchase(
                                tier: selectedTier,
                                annual: billing == .annual
                            )
                            if success {
                                appState.syncFromStoreKit(store)
                                dismiss()
                            }
                        }
                    } label: {
                        Group {
                            if store.isPurchasing {
                            ProgressView()
                                .tint(.white)
                            } else {
                            Text("Start 7-day free trial")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(store.isPurchasing || store.isLoading)

                    Button("Restore purchases") {
                        Task {
                            Haptics.impact(.light)
                            let success = await store.restore()
                            if success {
                                appState.syncFromStoreKit(store)
                                dismiss()
                            }
                        }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .disabled(store.isPurchasing)

                    Text("Free for 7 days, then \(priceForTier). Cancel anytime in Settings.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary.opacity(0.7))
                        .multilineTextAlignment(.center)

                    HStack(spacing: 16) {
                        Link("Terms of Use", destination: URL(string: "https://65qn5mmc0o8br1jaq624d-web.rork.live/terms")!)
                        Link("Privacy Policy", destination: URL(string: "https://65qn5mmc0o8br1jaq624d-web.rork.live/privacy")!)
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textSecondary.opacity(0.6))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.1)) {
                appeared = true
            }
        }
        .alert("Purchase Error", isPresented: .init(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.clearError() } }
        )) {
            Button("OK") { store.clearError() }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private func tierCard(_ tier: SubscriptionTier) -> some View {
        let isSelected = selectedTier == tier
        let benefits = tierBenefits(tier)
        let badge = tierBadge(tier)

        Button {
            Haptics.impact(.light)
            withAnimation(.spring(response: 0.3)) { selectedTier = tier }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(tier.display)
                                .font(.system(size: 18, weight: .heavy))
                                .foregroundStyle(Theme.textPrimary)
                            if let badge {
                                Text(badge)
                                    .font(.system(size: 9, weight: .black))
                                    .tracking(1)
                                    .foregroundStyle(Color.black)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Theme.accent))
                            }
                        }
                        Text(tier.subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(benefits, id: \.self) { benefit in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Theme.accent)
                            Text(benefit)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.textPrimary)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(tierPriceText(tier))
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    if let savingsText, tier == .everything {
                        Text(savingsText)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.success)
                    }
                    Spacer()
                    if let eff = effectiveMonthlyFor(tier) {
                        Text(eff)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(.top, 2)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(isSelected ? Theme.accent : Theme.hairline, lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func tierBenefits(_ tier: SubscriptionTier) -> [String] {
        switch tier {
        case .workouts:
            return [
                "All training days unlocked, every week",
                "Unlimited re-scans to track your transformation",
                "Progress timeline & side-by-side comparisons",
                "Rest timer between sets",
            ]
        case .nutrition:
            return [
                "Daily meal plans matched to your training",
                "Food photo scanning with AI macro estimation",
                "Barcode scanning for packaged foods",
                "Protein, carbs, and fat targets per meal",
            ]
        case .everything:
            return [
                "Everything in Workouts + Nutrition",
                "Full-body coaching: train, eat, track",
                "Priority AI analysis updates",
            ]
        }
    }

    private func tierBadge(_ tier: SubscriptionTier) -> String? {
        tier == .everything ? "BEST VALUE" : nil
    }

    private func tierPriceText(_ tier: SubscriptionTier) -> String {
        let annual = billing == .annual
        if let price = store.priceString(for: tier, annual: annual) {
            return annual ? "\(price)/yr" : "\(price)/mo"
        }
        switch (tier, billing) {
        case (.workouts, .monthly): return "$12.99/mo"
        case (.workouts, .annual): return "$79/yr"
        case (.nutrition, .monthly): return "$7.99/mo"
        case (.nutrition, .annual): return "$49/yr"
        case (.everything, .monthly): return "$16.99/mo"
        case (.everything, .annual): return "$99/yr"
        }
    }

    private func effectiveMonthlyFor(_ tier: SubscriptionTier) -> String? {
        guard billing == .annual else { return nil }
        switch tier {
        case .workouts: return "$6.58/mo billed yearly"
        case .nutrition: return "$4.08/mo billed yearly"
        case .everything: return "$8.25/mo billed yearly"
        }
    }
}
