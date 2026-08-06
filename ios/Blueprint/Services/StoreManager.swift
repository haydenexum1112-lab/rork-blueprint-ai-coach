import Foundation
import StoreKit

/// Product identifiers for Blueprint's three subscription tiers (monthly + annual).
nonisolated enum ProductID {
    static let workoutsMonthly  = "app.rork.blueprint.workouts.monthly"
    static let workoutsAnnual   = "app.rork.blueprint.workouts.annual"
    static let nutritionMonthly = "app.rork.blueprint.nutrition.monthly"
    static let nutritionAnnual  = "app.rork.blueprint.nutrition.annual"
    static let everythingMonthly = "app.rork.blueprint.everything.monthly"
    static let everythingAnnual  = "app.rork.blueprint.everything.annual"

    static let all: Set<String> = [
        workoutsMonthly, workoutsAnnual,
        nutritionMonthly, nutritionAnnual,
        everythingMonthly, everythingAnnual,
    ]

    /// Maps a product ID to its subscription tier.
    static func tier(for id: String) -> SubscriptionTier? {
        if id.hasPrefix("app.rork.blueprint.workouts") { return .workouts }
        if id.hasPrefix("app.rork.blueprint.nutrition") { return .nutrition }
        if id.hasPrefix("app.rork.blueprint.everything") { return .everything }
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
        } catch {
            print("[StoreManager] Failed to fetch products: \(error.localizedDescription)")
            errorMessage = "Couldn't load subscription options. Try again later."
        }
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
