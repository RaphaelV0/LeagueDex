import Foundation

/// Calcul des statistiques d'un champion entre les niveaux 1 et 18.
enum StatGrowth {
    static func value(base: Double, growth: Double, level: Int) -> Double {
        let n = Double(min(18, max(1, level)) - 1)
        return base + growth * n * (0.7025 + 0.0175 * n)
    }
}
