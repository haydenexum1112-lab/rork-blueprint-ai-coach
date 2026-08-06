import Foundation

/// Error thrown by the food scan service.
nonisolated enum FoodScanError: LocalizedError, CustomStringConvertible {
    case missingConfig
    case imageTooLarge
    case network(String)
    case badStatus(Int)
    case serviceUnavailable
    case emptyResponse
    case parsing(String)
    case noFoodDetected

    var errorDescription: String? {
        switch self {
        case .missingConfig:
            return "Food scanning isn't configured yet. Please try again later."
        case .imageTooLarge:
            return "That photo couldn't be compressed enough. Try retaking it."
        case .network(let message):
            return "Network issue: \(message). Check your connection and try again."
        case .badStatus(let code):
            return "The scan service returned an error (\(code)). Please try again."
        case .serviceUnavailable:
            return "The food scan service is temporarily unavailable. This is usually a billing or quota issue on the backend. Please try again later, or log the food manually."
        case .emptyResponse:
            return "The scan came back empty. Please try again."
        case .parsing:
            return "We couldn't read the scan result. Please try again."
        case .noFoodDetected:
            return "I couldn't identify any food in that photo. Try a clearer shot of your meal."
        }
    }

    var diagnostic: String? {
        switch self {
        case .parsing(let detail): return detail
        default: return nil
        }
    }

    var description: String { errorDescription ?? "Unknown food scan error" }
}

/// One item identified in a food photo, with estimated macros.
nonisolated struct ScannedFoodItem: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var emoji: String
    var calories: Int
    var proteinGrams: Int
    var carbsGrams: Int
    var fatGrams: Int
    var servings: Double
    /// Human-readable portion description, e.g. "1 cup" or "2 slices".
    var portion: String
    /// Short confidence note from the model, e.g. "confident" or "estimate".
    var confidence: String
}

/// Full result of a food scan: one or more items plus a total.
nonisolated struct FoodScanResult: Codable, Hashable {
    var items: [ScannedFoodItem]
    var totalCalories: Int
    var totalProtein: Int
    var totalCarbs: Int
    var totalFat: Int
    /// Suggested meal slot based on time of day, e.g. "breakfast".
    var suggestedSlot: String
    /// Overall description of what was detected, e.g. "Grilled chicken bowl with rice and broccoli".
    var description: String
}

/// Calls GPT-4o (vision) through the Rork Toolkit proxy to identify food in a photo
/// and estimate macros — same pattern as physique analysis but with a food-focused prompt.
nonisolated enum FoodScanService {
    static let modelId = "openai/gpt-4o"
    private static let imageByteBudget = 420_000

    private static let systemPrompt = """
    You are Blueprint Food Scan, an expert nutritionist AI. You analyze photos of meals and food, identify what's on the plate, and estimate portion sizes and macronutrients (calories, protein, carbs, fat).

    STRICT RULES:
    - Be honest and conservative with estimates. If you can't clearly see the food, say so.
    - Estimate portions based on typical serving sizes visible in the photo.
    - If the photo doesn't contain food (e.g. it's a landscape, a person, a random object), return the no-food response.
    - Respond with ONLY a single valid JSON object. No markdown, no code fences, no commentary.

    OUTPUT SCHEMA (exact keys, no extras):
    {
      "items": [
        {"name": "Grilled chicken breast", "emoji": "🍗", "calories": 220, "proteinGrams": 35, "carbsGrams": 0, "fatGrams": 7, "servings": 1, "portion": "5 oz", "confidence": "confident"}
      ],
      "totalCalories": 560,
      "totalProtein": 45,
      "totalCarbs": 52,
      "totalFat": 18,
      "suggestedSlot": "lunch",
      "description": "Grilled chicken bowl with rice, broccoli, and olive oil dressing"
    }

    - \"items\" should list each distinct food component (e.g. chicken, rice, broccoli separately).
    - \"suggestedSlot\" must be one of: breakfast, lunch, dinner, snack — pick based on what the meal looks like.
    - \"emoji\" should be a single emoji that best represents the food item.
    - \"confidence\" is one of: confident, likely, estimate.
    - Totals must equal the sum of the items' macros.

    NO-FOOD RESPONSE — return this exact JSON if no food is visible:
    {"items": [], "totalCalories": 0, "totalProtein": 0, "totalCarbs": 0, "totalFat": 0, "suggestedSlot": "snack", "description": "No food detected"}
    """

    /// Analyzes a food photo and returns identified items with estimated macros.
    static func scan(_ imageData: Data) async throws -> FoodScanResult {
        let toolkitURL = RuntimeConfig.toolkitURL
        let secret = RuntimeConfig.rorkToolkitSecretKey
        guard !toolkitURL.isEmpty, !secret.isEmpty else {
            print("[FoodScanService] Missing config — toolkitURL empty: \(toolkitURL.isEmpty), secret empty: \(secret.isEmpty)")
            throw FoodScanError.missingConfig
        }
        print("[FoodScanService] Config check: toolkitURL has \(toolkitURL.count) chars, secret has \(secret.count) chars")

        guard let resized = ImageResizer.resize(imageData, maxBytes: imageByteBudget) else {
            print("[FoodScanService] Image resize failed — input bytes: \(imageData.count)")
            throw FoodScanError.imageTooLarge
        }
        print("[FoodScanService] Image resized: \(imageData.count) -> \(resized.count) bytes")

        var contentParts: [[String: Any]] = []
        contentParts.append([
            "type": "text",
            "text": "Analyze this food photo. Identify each item, estimate portions and macros. Return JSON per the schema.",
        ])
        contentParts.append(imagePart(resized))

        let body: [String: Any] = [
            "model": modelId,
            "max_tokens": 1500,
            "temperature": 0.4,
            "stream": false,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": contentParts],
            ],
        ]

        guard let url = URL(string: "\(toolkitURL)/v2/vercel/v1/chat/completions") else {
            print("[FoodScanService] Invalid URL: \(toolkitURL)/v2/vercel/v1/chat/completions")
            throw FoodScanError.missingConfig
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 90
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        print("[FoodScanService] Request body size: \(request.httpBody?.count ?? 0) bytes, sending to \(url.absoluteString)")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            print("[FoodScanService] Network error: \(error.localizedDescription)")
            throw FoodScanError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            print("[FoodScanService] Invalid response type")
            throw FoodScanError.network("invalid response")
        }
        print("[FoodScanService] Response status: \(http.statusCode), bytes: \(data.count)")
        guard (200 ..< 300).contains(http.statusCode) else {
            let bodyStr = String(data: data, encoding: .utf8)?.prefix(500) ?? ""
            print("[FoodScanService] Bad status \(http.statusCode): \(bodyStr)")
            if http.statusCode == 402 {
                throw FoodScanError.serviceUnavailable
            }
            throw FoodScanError.badStatus(http.statusCode)
        }

        let rawBody = String(data: data, encoding: .utf8) ?? ""
        print("[FoodScanService] Full response body: \(rawBody)")

        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any]
        else {
            let snippet = rawBody.prefix(600)
            print("[FoodScanService] Failed to parse response JSON: \(snippet)")
            throw FoodScanError.emptyResponse
        }

        // Content can be a plain string (OpenAI format) or an array of blocks (Anthropic format)
        let content: String
        if let str = message["content"] as? String, !str.isEmpty {
            content = str
        } else if let blocks = message["content"] as? [[String: Any]] {
            content = blocks.compactMap { $0["text"] as? String }.joined()
        } else {
            print("[FoodScanService] No usable content in message: \(message)")
            throw FoodScanError.emptyResponse
        }

        guard !content.isEmpty else {
            print("[FoodScanService] Content was empty after extraction")
            throw FoodScanError.emptyResponse
        }
        print("[FoodScanService] AI content received: \(content)")

        let cleaned = extractJSON(from: content)
        guard let cleanedData = cleaned.data(using: .utf8) else {
            print("[FoodScanService] Could not convert cleaned JSON to Data")
            throw FoodScanError.parsing("Could not convert cleaned JSON to Data")
        }

        do {
            let result = try JSONDecoder().decode(FoodScanResult.self, from: cleanedData)
            if result.items.isEmpty {
                print("[FoodScanService] No food items detected in result")
                throw FoodScanError.noFoodDetected
            }
            print("[FoodScanService] Success — \(result.items.count) items detected")
            return result
        } catch let error as FoodScanError {
            throw error
        } catch {
            print("[FoodScanService] Strict JSON decode failed: \(error)")
            print("[FoodScanService] Cleaned JSON: \(cleaned)")
            // Try a tolerant dictionary-based parse before giving up.
            if let fallback = parseFoodScanFallback(from: cleanedData) {
                print("[FoodScanService] Fallback parse succeeded — \(fallback.items.count) items")
                return fallback
            }
            throw FoodScanError.parsing("Cleaned JSON: \(cleaned)\nDecode error: \(error)")
        }
    }

    /// Tolerant parser that normalizes messy AI responses: missing fields, string/double numbers, etc.
    private static func parseFoodScanFallback(from data: Data) -> FoodScanResult? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        func asInt(_ value: Any?) -> Int {
            if let i = value as? Int { return i }
            if let d = value as? Double { return Int(d.rounded()) }
            if let s = value as? String, let i = Int(s) { return i }
            return 0
        }
        func asDouble(_ value: Any?) -> Double {
            if let d = value as? Double { return d }
            if let i = value as? Int { return Double(i) }
            if let s = value as? String, let d = Double(s) { return d }
            return 1.0
        }
        func asString(_ value: Any?) -> String { value as? String ?? "" }

        let itemDicts = root["items"] as? [[String: Any]] ?? []
        let items: [ScannedFoodItem] = itemDicts.compactMap { dict in
            let name = asString(dict["name"])
            guard !name.isEmpty else { return nil }
            return ScannedFoodItem(
                name: name,
                emoji: asString(dict["emoji"]).isEmpty ? "🍽️" : asString(dict["emoji"]),
                calories: asInt(dict["calories"]),
                proteinGrams: asInt(dict["proteinGrams"]),
                carbsGrams: asInt(dict["carbsGrams"]),
                fatGrams: asInt(dict["fatGrams"]),
                servings: asDouble(dict["servings"]),
                portion: asString(dict["portion"]).isEmpty ? "1 serving" : asString(dict["portion"]),
                confidence: asString(dict["confidence"]).isEmpty ? "estimate" : asString(dict["confidence"])
            )
        }.filter { !$0.name.isEmpty }

        guard !items.isEmpty else { return nil }

        let computed = items.reduce((cal: 0, p: 0, c: 0, f: 0)) { acc, item in
            (acc.cal + item.calories, acc.p + item.proteinGrams, acc.c + item.carbsGrams, acc.f + item.fatGrams)
        }

        let suggestedSlot = asString(root["suggestedSlot"]).isEmpty ? "snack" : asString(root["suggestedSlot"])
        let description = asString(root["description"]).isEmpty ? "Food detected from photo" : asString(root["description"])

        return FoodScanResult(
            items: items,
            totalCalories: asInt(root["totalCalories"]) == 0 ? computed.cal : asInt(root["totalCalories"]),
            totalProtein: asInt(root["totalProtein"]) == 0 ? computed.p : asInt(root["totalProtein"]),
            totalCarbs: asInt(root["totalCarbs"]) == 0 ? computed.c : asInt(root["totalCarbs"]),
            totalFat: asInt(root["totalFat"]) == 0 ? computed.f : asInt(root["totalFat"]),
            suggestedSlot: suggestedSlot,
            description: description
        )
    }

    private static func imagePart(_ jpegData: Data) -> [String: Any] {
        [
            "type": "image_url",
            "image_url": ["url": "data:image/jpeg;base64,\(jpegData.base64EncodedString())"],
        ]
    }

    /// Strips markdown fences and grabs the outermost JSON object.
    static func extractJSON(from text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            cleaned = cleaned
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let start = cleaned.firstIndex(of: "{"), let end = cleaned.lastIndex(of: "}") else {
            return cleaned
        }
        return String(cleaned[start ... end])
    }
}
