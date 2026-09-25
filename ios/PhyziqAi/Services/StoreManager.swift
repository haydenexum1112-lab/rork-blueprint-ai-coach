import Foundation
import StoreKit

/// Product identifiers for PhyziqAi's three subscription tiers (monthly + annual).
/// These must match exactly the product IDs configured in App Store Connect.
nonisolated enum ProductID {
    static let workoutsMonthly  = "app.rork.65qn5mmc0o8br1jaq624d.workouts.monthly2"
    static let workoutsAnnual   = "app.rork.65qn5mmc0o8br1jaq624d.workouts.annual2"
    static let nutritionMonthly = "app.rork.65qn5mmc0o8br1jaq624d.nutrition.monthly2"
    static let nutritionAnnual  = "app.rork.65qn5mmc0o8br1jaq624d.nutrition.annual2"
    static let everythingMonthly = "app.rork.65qn5mmc0o8br1jaq624d.everything.monthly2"
    static let everythingAnnual  = "app.rork.65qn5mmc0o8br1jaq624d.everything.annual2"

    static let all: Set<String> = [
        workoutsMonthly, workoutsAnnual,
        nutritionMonthly, nutritionAnnual,
        everythingMonthly, everythingAnnual,
    ]

    /// Maps a product ID to its subscription tier.
    static func tier(for id: String) -> SubscriptionTier? {
        if id.contains(".workouts.") { return .workouts }
        if id.contains(".nutrition.") { return .nutrition }
        if id.contains(".everything.") { return .everything }
        return nil
    }

    /// Product ID for a given tier + billing period.
    static func id(tier: SubscriptionTier, annual: Bool) -> String {
        switch tier {
        case .workouts:   return annual ? workoutsAnnual : workoutsMonthly
        case .nutrition:  return annual ? nutritionAnnual : nutritionMonthly
        case .everything: return annual ? everythingAnnual : everythingMonthly
        }
    }
}

/// Central StoreKit 2 manager: fetches products, handles purchases, tracks entitlements.
/// Shared as a single `@State` instance from the app root.
@Observable
@MainActor
final class StoreManager {
    /// All fetched products keyed by product ID.
    private(set) var products: [String: Product] = [:]

    /// True while products are being fetched from the App Store.
    var isLoading: Bool = false

    /// True while a purchase is in progress.
    var isPurchasing: Bool = false

    /// Last error message shown to the user (nil = no error).
    var errorMessage: String?

    /// Current entitlements derived from StoreKit transaction state.
    private(set) var activeEntitlements: Set<SubscriptionTier> = []

    /// Whether any tier is currently active.
    var isSubscribed: Bool { !activeEntitlements.isEmpty }

    /// The highest tier the user is subscribed to (everything > workouts/nutrition).
    var currentTier: SubscriptionTier? {
        if activeEntitlements.contains(.everything) { return .everything }
        if activeEntitlements.contains(.workouts) { return .workouts }
        if activeEntitlements.contains(.nutrition) { return .nutrition }
        return nil
    }

    /// Whether the user is in a free trial (introductory offer).
    private(set) var isInTrial: Bool = false

    /// Expiration date of the current subscription (if any).
    private(set) var expirationDate: Date?

    private var transactionListener: Task<Void, Never>?

    init() {
        transactionListener = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = result {
                    await self.updateEntitlements()
                    await transaction.finish()
                }
            }
        }
        Task {
            await fetchProducts()
            await updateEntitlements()
        }
    }

    // MARK: - Fetch Products

    func fetchProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let storeProducts = try await Product.products(for: ProductID.all)
            for product in storeProducts {
                products[product.id] = product
            }
            print("[StoreManager] Fetched \(storeProducts.count) products")
            await refreshIntroOfferEligibility()
        } catch {
            print("[StoreManager] Failed to fetch products: \(error.localizedDescription)")
            errorMessage = "Couldn't load subscription options. Try again later."
        }
    }

    // MARK: - Pricing & Trial (all display text comes from StoreKit)

    /// Intro-offer eligibility per product ID ("can this user get the free trial?").
    private(set) var introOfferEligibility: [String: Bool] = [:]

    /// Refreshes eligibility for every product that has an introductory offer.
    func refreshIntroOfferEligibility() async {
        var result: [String: Bool] = [:]
        for (id, product) in products {
            guard let subscription = product.subscription,
                  subscription.introductoryOffer != nil else { continue }
            result[id] = await subscription.isEligibleForIntroOffer
        }
        introOfferEligibility = result
    }

    /// Whether the given product's free trial actually applies to this user.
    func isEligibleForTrial(_ product: Product) -> Bool {
        introOfferEligibility[product.id] ?? false
    }

    /// Trial length in days from the product's introductory offer (1 week → 7 days).
    func introOfferDays(for product: Product) -> Int? {
        guard let offer = product.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        let period = offer.period
        switch period.unit {
        case .day: return period.value
        case .week: return period.value * 7
        case .month: return period.value * 30
        case .year: return period.value * 365
        @unknown default: return nil
        }
    }

    /// "7-day free trial" — derived from StoreKit so it always matches ASC.
    func trialText(for product: Product) -> String? {
        guard let offer = product.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        let period = offer.period
        let unit: String
        let value: Int
        switch period.unit {
        case .day:
            unit = "day"; value = period.value
        case .week:
            if period.value == 1 { return "7-day free trial" }
            unit = "week"; value = period.value
        case .month:
            unit = "month"; value = period.value
        case .year:
            unit = "year"; value = period.value
        @unknown default:
            return nil
        }
        return "\(value)-\(unit) free trial"
    }

    /// Short billing suffix for plan cards: "/yr", "/mo", "/wk", "/day".
    func billingSuffix(for product: Product) -> String {
        guard let period = product.subscription?.subscriptionPeriod else { return "" }
        switch period.unit {
        case .day: return "/day"
        case .week: return "/wk"
        case .month: return "/mo"
        case .year: return "/yr"
        @unknown default: return ""
        }
    }

    /// Full billing period word for the disclosure line: "year", "month", …
    func periodWord(for product: Product) -> String {
        guard let period = product.subscription?.subscriptionPeriod else { return "" }
        let base: String
        switch period.unit {
        case .day: base = "day"
        case .week: base = "week"
        case .month: base = "month"
        case .year: base = "year"
        @unknown default: return ""
        }
        return period.value > 1 ? "\(base)s" : base
    }

    /// Annual price per month (e.g. "$6.58/mo billed yearly") — computed from the real price.
    func effectiveMonthlyText(for tier: SubscriptionTier) -> String? {
        guard let product = product(for: tier, annual: true) else { return nil }
        let monthly = product.price / 12
        return "\(monthly.formatted(product.priceFormatStyle))/mo billed yearly"
    }

    /// Real savings vs buying Workouts + Nutrition separately at monthly prices.
    func savingsText(for tier: SubscriptionTier) -> String? {
        guard tier == .everything,
              let workouts = product(for: .workouts, annual: false)?.price,
              let nutrition = product(for: .nutrition, annual: false)?.price,
              let everything = product(for: .everything, annual: false)?.price else { return nil }
        let workoutsValue = NSDecimalNumber(decimal: workouts).doubleValue
        let nutritionValue = NSDecimalNumber(decimal: nutrition).doubleValue
        let everythingValue = NSDecimalNumber(decimal: everything).doubleValue
        let combined = workoutsValue + nutritionValue
        guard combined > 0 else { return nil }
        let percent = Int(((combined - everythingValue) / combined * 100).rounded())
        return percent > 0 ? "Save \(percent)% vs separate" : nil
    }

    // MARK: - Purchase

    /// Initiates a purchase for the selected tier + billing period.
    func purchase(tier: SubscriptionTier, annual: Bool) async -> Bool {
        let productID = ProductID.id(tier: tier, annual: annual)
        guard let product = products[productID] else {
            errorMessage = "This plan isn't available right now. Try again later."
            print("[StoreManager] Product not found: \(productID)")
            return false
        }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await updateEntitlements()
                    await transaction.finish()
                    print("[StoreManager] Purchase success — entitlements: \(activeEntitlements)")
                    return true
                } else {
                    errorMessage = "The purchase couldn't be verified. Please try again."
                    return false
                }

            case .userCancelled:
                print("[StoreManager] User cancelled purchase")
                return false

            case .pending:
                errorMessage = "Purchase is pending approval. You'll get access once it's approved."
                print("[StoreManager] Purchase pending")
                return false

            @unknown default:
                print("[StoreManager] Unknown purchase result")
                return false
            }
        } catch {
            print("[StoreManager] Purchase error: \(error.localizedDescription)")
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Restore

    /// Restores previous purchases by syncing with the App Store.
    func restore() async -> Bool {
        do {
            try await AppStore.sync()
            await updateEntitlements()
            print("[StoreManager] Restore complete — entitlements: \(activeEntitlements)")
            if activeEntitlements.isEmpty {
                errorMessage = "No previous purchases found to restore."
                return false
            }
            return true
        } catch {
            print("[StoreManager] Restore error: \(error.localizedDescription)")
            errorMessage = "Restore failed: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Entitlements

    /// Checks all StoreKit transactions and derives active entitlements.
    func updateEntitlements() async {
        var tiers: Set<SubscriptionTier> = []
        var hasTrial = false
        var latestExpiry: Date?

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }

            if let tier = ProductID.tier(for: transaction.productID) {
                let isActive = transaction.expirationDate.map { $0 > Date() } ?? true
                if isActive {
                    tiers.insert(tier)
                }

                if transaction.offerType == .introductory {
                    hasTrial = true
                }
                if let expiry = transaction.expirationDate, expiry > latestExpiry ?? .distantPast {
                    latestExpiry = expiry
                }
            }
        }

        activeEntitlements = tiers
        isInTrial = hasTrial
        expirationDate = latestExpiry
        print("[StoreManager] Entitlements — tiers: \(tiers), trial: \(hasTrial), expiry: \(String(describing: latestExpiry))")
    }

    // MARK: - Helpers

    /// Gets the StoreKit product for a tier + billing period.
    func product(for tier: SubscriptionTier, annual: Bool) -> Product? {
        products[ProductID.id(tier: tier, annual: annual)]
    }

    /// Localized price string for a tier + billing period.
    func priceString(for tier: SubscriptionTier, annual: Bool) -> String? {
        product(for: tier, annual: annual)?.displayPrice
    }

    /// Clears the current error message.
    func clearError() {
        errorMessage = nil
    }

    /// Whether StoreKit products have been loaded.
    var hasProducts: Bool { !products.isEmpty }
}
