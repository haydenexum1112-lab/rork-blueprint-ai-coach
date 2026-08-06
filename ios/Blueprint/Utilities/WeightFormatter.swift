import Foundation

/// Converts between kg (canonical storage) and the user's display unit (kg or lb).
enum WeightFormatter {
    /// Full display: "12.5 kg" / "27.6 lb" / "BW"
    static func display(_ kg: Double, usesMetric: Bool) -> String {
        if kg == 0 { return "BW" }
        if usesMetric { return String(format: "%.1f kg", kg) }
        return String(format: "%.1f lb", kg * 2.20462)
    }

    /// Short display (no unit suffix): "12.5" / "27.6"
    static func value(_ kg: Double, usesMetric: Bool) -> String {
        if kg == 0 { return "BW" }
        if usesMetric { return String(format: "%.1f", kg) }
        return String(format: "%.1f", kg * 2.20462)
    }

    /// Volume display: "850 kg" / "1874 lb"
    static func volume(_ kg: Double, usesMetric: Bool) -> String {
        if usesMetric { return String(format: "%.0f kg", kg) }
        return String(format: "%.0f lb", kg * 2.20462)
    }

    /// Unit label for input fields
    static func unitLabel(usesMetric: Bool) -> String {
        usesMetric ? "kg" : "lb"
    }

    /// Convert a value typed in the user's unit → kg for storage
    static func toKg(_ value: Double, usesMetric: Bool) -> Double {
        usesMetric ? value : value / 2.20462
    }

    /// Convert kg → user's unit for display in input fields
    static func fromKg(_ kg: Double, usesMetric: Bool) -> Double {
        usesMetric ? kg : kg * 2.20462
    }
}
