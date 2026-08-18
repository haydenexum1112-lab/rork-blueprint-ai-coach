import Foundation

/// Error thrown by the barcode lookup service.
nonisolated enum BarcodeError: LocalizedError {
    case invalidBarcode
    case network(String)
    case badStatus(Int)
    case notFound
    case parsing
    case noNutrition

    var errorDescription: String? {
        switch self {
        case .invalidBarcode:
            return "That barcode doesn't look valid. Try scanning again."
        case .network(let message):
            return "Network issue: \(message). Check your connection and try again."
        case .badStatus(let code):
            return "The lookup service returned an error (\(code)). Please try again."
        case .notFound:
            return "We couldn't find that product in any food database. Try logging it manually."
        case .parsing:
            return "We couldn't read the product info. Please try again."
        case .noNutrition:
            return "This product doesn't have nutrition data available. Try logging it manually."
        }
    }
}

/// A product looked up from a barcode, with macro info.
nonisolated struct BarcodeProduct: Codable, Hashable {
    var name: String
    var brand: String?
    var emoji: String
    var caloriesPerServing: Int
    var proteinGrams: Int
    var carbsGrams: Int
    var fatGrams: Int
    var servingDescription: String
    var imageUrl: String?
    var barcode: String
    /// True when macros came from a database (vs. user-entered).
    var hasNutritionData: Bool
}

/// Looks up food products by barcode using multiple databases.
/// 1. OpenFoodFacts (free, global, no key required)
/// 2. UPCItemDB (free, US-focused, no key required for trial tier)
nonisolated enum BarcodeService {

    /// Looks up a product by its barcode (EAN-13, UPC-A, etc.).
    /// Tries OpenFoodFacts first, then UPCItemDB as a fallback.
    static func lookup(_ barcode: String) async throws -> BarcodeProduct {
        let trimmed = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.allSatisfy({ $0.isNumber }), trimmed.count >= 8 else {
            throw BarcodeError.invalidBarcode
        }

        // Try OpenFoodFacts first (has nutrition data)
        do {
            let product = try await lookupOpenFoodFacts(trimmed)
            return product
        } catch BarcodeError.notFound {
            // Fall through to UPCItemDB
        } catch BarcodeError.noNutrition {
            // Fall through to UPCItemDB — maybe it has a better match
        }

        // Fallback: UPCItemDB (product info only, no macros)
        let upcProduct = try await lookupUPCItemDB(trimmed)
        return upcProduct
    }

    // MARK: - OpenFoodFacts

    /// Looks up a product via the OpenFoodFacts API.
    /// Allows zero-macro products (water, diet soda, black coffee) through.
    private static func lookupOpenFoodFacts(_ barcode: String) async throws -> BarcodeProduct {
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json") else {
            throw BarcodeError.invalidBarcode
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("PhyziqAi/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw BarcodeError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw BarcodeError.network("invalid response")
        }
        guard (200 ..< 300).contains(http.statusCode) else {
            throw BarcodeError.badStatus(http.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BarcodeError.parsing
        }

        // Status: 1 = found, 0 = not found
        let status = json["status"] as? Int ?? 0
        guard status == 1 else {
            throw BarcodeError.notFound
        }

        guard let product = json["product"] as? [String: Any] else {
            throw BarcodeError.notFound
        }

        let name = (product["product_name"] as? String)
            ?? (product["product_name_en"] as? String)
            ?? (product["generic_name"] as? String)
            ?? "Unknown product"
        let brand = product["brands"] as? String

        let servingSize = (product["serving_size"] as? String) ?? "per 100g"

        let nutriments = (product["nutriments"] as? [String: Any]) ?? [:]

        // Energy: prefer kcal, then kJ converted
        var calories = 0
        if let energyKcal = nutriments["energy-kcal_serving"] as? Double {
            calories = Int(energyKcal)
        } else if let energyKcal = nutriments["energy-kcal"] as? Double {
            calories = Int(energyKcal)
        } else if let energyKj = nutriments["energy_serving"] as? Double {
            calories = Int(energyKj / 4.184)
        } else if let energyKj = nutriments["energy"] as? Double {
            calories = Int(energyKj / 4.184)
        }

        var protein = 0
        if let val = nutriments["proteins_serving"] as? Double {
            protein = Int(val)
        } else if let val = nutriments["proteins"] as? Double {
            protein = Int(val)
        }

        var carbs = 0
        if let val = nutriments["carbohydrates_serving"] as? Double {
            carbs = Int(val)
        } else if let val = nutriments["carbohydrates"] as? Double {
            carbs = Int(val)
        }

        var fat = 0
        if let val = nutriments["fat_serving"] as? Double {
            fat = Int(val)
        } else if let val = nutriments["fat"] as? Double {
            fat = Int(val)
        }

        let imageUrl = (product["image_front_small_url"] as? String)
            ?? (product["image_thumb_url"] as? String)
            ?? (product["image_url"] as? String)

        let categories = (product["categories"] as? String) ?? ""
        let emoji = emojiForCategory(categories, name: name)

        // Check if nutriments object exists at all (even if all zeros)
        let hasNutriments = !nutriments.isEmpty

        // Allow zero-macro products through (water, diet soda, black coffee)
        // Only reject if there are no nutriments at all
        if !hasNutriments {
            throw BarcodeError.noNutrition
        }

        return BarcodeProduct(
            name: name,
            brand: brand,
            emoji: emoji,
            caloriesPerServing: calories,
            proteinGrams: protein,
            carbsGrams: carbs,
            fatGrams: fat,
            servingDescription: servingSize,
            imageUrl: imageUrl,
            barcode: barcode,
            hasNutritionData: true
        )
    }

    // MARK: - UPCItemDB (fallback)

    /// Looks up a product via UPCItemDB trial API.
    /// Returns product name/brand but no nutrition data — macros default to 0
    /// and the user can edit them before logging.
    private static func lookupUPCItemDB(_ barcode: String) async throws -> BarcodeProduct {
        guard let url = URL(string: "https://api.upcitemdb.com/prod/trial/lookup?upc=\(barcode)") else {
            throw BarcodeError.invalidBarcode
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw BarcodeError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw BarcodeError.network("invalid response")
        }
        guard (200 ..< 300).contains(http.statusCode) else {
            // Rate limited or other error — treat as not found so user can manual entry
            throw BarcodeError.notFound
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BarcodeError.parsing
        }

        let code = json["code"] as? String ?? ""
        guard code == "OK" else {
            throw BarcodeError.notFound
        }

        let items = (json["items"] as? [[String: Any]]) ?? []
        guard let firstItem = items.first else {
            throw BarcodeError.notFound
        }

        let name = (firstItem["title"] as? String) ?? "Unknown product"
        let brand = firstItem["brand"] as? String
        let category = (firstItem["category"] as? String) ?? ""
        let desc = (firstItem["description"] as? String) ?? ""

        // Try to extract an image
        let images = (firstItem["images"] as? [[String: Any]]) ?? []
        let imageUrl = images.first?["thumbnail"] as? String

        let emoji = emojiForCategory(category, name: name + " " + desc)

        return BarcodeProduct(
            name: name,
            brand: brand,
            emoji: emoji,
            caloriesPerServing: 0,
            proteinGrams: 0,
            carbsGrams: 0,
            fatGrams: 0,
            servingDescription: "1 serving",
            imageUrl: imageUrl,
            barcode: barcode,
            hasNutritionData: false
        )
    }

    /// Picks a representative emoji based on product category tags.
    private static func emojiForCategory(_ categories: String, name: String) -> String {
        let lower = (categories + " " + name).lowercased()
        if lower.contains("beverage") || lower.contains("drink") || lower.contains("soda") || lower.contains("juice") { return "🥤" }
        if lower.contains("water") { return "💧" }
        if lower.contains("coffee") { return "☕️" }
        if lower.contains("tea") { return "🫖" }
        if lower.contains("milk") || lower.contains("yogurt") || lower.contains("dairy") { return "🥛" }
        if lower.contains("cheese") { return "🧀" }
        if lower.contains("bread") || lower.contains("bakery") || lower.contains("biscuit") || lower.contains("cookie") { return "🍞" }
        if lower.contains("chocolate") || lower.contains("candy") || lower.contains("sweet") { return "🍫" }
        if lower.contains("protein bar") || lower.contains("protein") { return "🍫" }
        if lower.contains("cereal") || lower.contains("breakfast") { return "🥣" }
        if lower.contains("snack") || lower.contains("chips") || lower.contains("crisps") { return "🥨" }
        if lower.contains("fruit") { return "🍎" }
        if lower.contains("vegetable") { return "🥦" }
        if lower.contains("meat") || lower.contains("chicken") || lower.contains("beef") || lower.contains("pork") { return "🍖" }
        if lower.contains("fish") || lower.contains("tuna") || lower.contains("salmon") { return "🐟" }
        if lower.contains("pasta") || lower.contains("noodle") { return "🍝" }
        if lower.contains("rice") { return "🍚" }
        if lower.contains("sauce") || lower.contains("dressing") { return "🧴" }
        if lower.contains("nut") || lower.contains("almond") || lower.contains("peanut") { return "🥜" }
        if lower.contains("egg") { return "🥚" }
        if lower.contains("spread") || lower.contains("butter") || lower.contains("jam") { return "🫙" }
        return "📦"
    }
}
