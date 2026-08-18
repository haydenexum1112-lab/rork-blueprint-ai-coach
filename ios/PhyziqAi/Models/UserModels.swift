import Foundation

nonisolated enum Sex: String, Codable, CaseIterable, Identifiable {
    case male
    case female
    case other

    var id: String { rawValue }

    var display: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .other: return "Other"
        }
    }
}

nonisolated enum Experience: String, Codable, CaseIterable, Identifiable {
    case beginner
    case intermediate
    case advanced

    var id: String { rawValue }

    var display: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        }
    }

    var subtitle: String {
        switch self {
        case .beginner: return "Under 1 year of consistent training"
        case .intermediate: return "1–3 years of consistent training"
        case .advanced: return "3+ years of consistent training"
        }
    }
}

nonisolated enum Equipment: String, Codable, CaseIterable, Identifiable {
    case fullGym
    case homeBasics
    case bodyweight

    var id: String { rawValue }

    var display: String {
        switch self {
        case .fullGym: return "Full gym"
        case .homeBasics: return "Home basics"
        case .bodyweight: return "Bodyweight only"
        }
    }

    var subtitle: String {
        switch self {
        case .fullGym: return "Barbells, machines, cables, dumbbells"
        case .homeBasics: return "Dumbbells, bands, a bench"
        case .bodyweight: return "No equipment needed"
        }
    }

    var icon: String {
        switch self {
        case .fullGym: return "dumbbell.fill"
        case .homeBasics: return "house.fill"
        case .bodyweight: return "figure.strengthtraining.functional"
        }
    }
}

nonisolated enum GoalTag: String, Codable, CaseIterable, Identifiable {
    case muscleSize
    case definition
    case athletic
    case recomposition

    var id: String { rawValue }

    var display: String {
        switch self {
        case .muscleSize: return "Muscle size"
        case .definition: return "Definition / leanness"
        case .athletic: return "Athletic / functional"
        case .recomposition: return "Overall recomposition"
        }
    }
}

// MARK: - Subscription

/// Which feature set a subscription tier unlocks.
nonisolated enum SubscriptionTier: String, Codable, Hashable, CaseIterable {
    case workouts
    case nutrition
    case everything

    var display: String {
        switch self {
        case .workouts: return "Workouts"
        case .nutrition: return "Nutrition"
        case .everything: return "Everything"
        }
    }

    var subtitle: String {
        switch self {
        case .workouts: return "All training days, re-scans & progress"
        case .nutrition: return "Meal plans, food scanning & macros"
        case .everything: return "Workouts + Nutrition — best value"
        }
    }
}

/// Unified subscription state — replaces the old SubscriptionStatus and NutritionSubscriptionStatus.
nonisolated enum SubscriptionState: Codable, Hashable {
    case free
    case trial(tier: SubscriptionTier, expires: Date)
    case subscribed(tier: SubscriptionTier)

    var display: String {
        switch self {
        case .free: return "Free"
        case .trial(let tier, let expires):
            return "\(tier.display) Trial · ends \(expires.formatted(date: .abbreviated, time: .omitted))"
        case .subscribed(let tier):
            return tier.display
        }
    }

    var currentTier: SubscriptionTier? {
        switch self {
        case .free: return nil
        case .trial(let tier, _): return tier
        case .subscribed(let tier): return tier
        }
    }

    var isActive: Bool {
        switch self {
        case .free: return false
        case .trial(_, let expires): return expires > Date()
        case .subscribed: return true
        }
    }

    func hasAccess(to tier: SubscriptionTier) -> Bool {
        guard isActive else { return false }
        guard let myTier = currentTier else { return false }
        if myTier == .everything { return true }
        return myTier == tier
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // Try new keyed format first
        if let keyed = try? decoder.container(keyedBy: SubKeys.self),
           let state = try? keyed.decode(String.self, forKey: .state) {
            switch state {
            case "free":
                self = .free; return
            case "subscribed":
                if let tier = try? keyed.decode(SubscriptionTier.self, forKey: .tier) {
                    self = .subscribed(tier: tier); return
                }
            case "trial":
                if let tier = try? keyed.decode(SubscriptionTier.self, forKey: .tier),
                   let expires = try? keyed.decode(Date.self, forKey: .expires) {
                    self = .trial(tier: tier, expires: expires); return
                }
            default: break
            }
        }
        // Try old string format
        if let str = try? container.decode(String.self) {
            switch str {
            case "pro": self = .subscribed(tier: .everything)
            default: self = .free
            }
            return
        }
        // Try old array enum format
        if let array = try? container.decode([SubValue].self) {
            if let first = array.first {
                switch first.stringValue {
                case "free": self = .free; return
                case "pro": self = .subscribed(tier: .everything); return
                default: break
                }
            }
        }
        self = .free
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: SubKeys.self)
        switch self {
        case .free:
            try container.encode("free", forKey: .state)
        case .trial(let tier, let expires):
            try container.encode("trial", forKey: .state)
            try container.encode(tier, forKey: .tier)
            try container.encode(expires, forKey: .expires)
        case .subscribed(let tier):
            try container.encode("subscribed", forKey: .state)
            try container.encode(tier, forKey: .tier)
        }
    }
}

private enum SubKeys: CodingKey {
    case state, tier, expires
}

/// Lenient value for backward-compat decoding of old enum format.
private struct SubValue: Decodable {
    let stringValue: String
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        stringValue = (try? c.decode(String.self)) ?? ""
    }
}

// MARK: - User profile

nonisolated struct UserProfile: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var age: Int
    var sex: Sex
    /// Canonical height in centimeters.
    var heightCm: Double
    /// Canonical weight in kilograms.
    var weightKg: Double
    var usesMetric: Bool
    var experience: Experience
    var daysPerWeek: Int
    var equipment: Equipment
    var goalTags: [GoalTag]
    var subscriptionStatus: SubscriptionState = .free

    var heightDisplay: String {
        if usesMetric {
            return "\(Int(heightCm)) cm"
        }
        let totalInches = heightCm / 2.54
        let feet = Int(totalInches / 12)
        let inches = Int(totalInches.rounded()) % 12
        return "\(feet)′\(inches)″"
    }

    var weightDisplay: String {
        if usesMetric {
            return "\(Int(weightKg.rounded())) kg"
        }
        return "\(Int((weightKg * 2.20462).rounded())) lb"
    }
}
