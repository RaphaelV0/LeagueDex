import Foundation

/// The same level curve used by the existing champion detail screen.
/// Keep catalog interpretation in one place so comparison and details agree.
enum StatGrowth {
    static func value(base: Double, growth: Double, level: Int) -> Double {
        let boundedLevel = min(18, max(1, level))
        let n = Double(boundedLevel - 1)
        return base + growth * n * (0.7025 + 0.0175 * n)
    }
}
