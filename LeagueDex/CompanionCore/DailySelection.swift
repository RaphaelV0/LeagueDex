import Foundation

/// Daily identity uses UTC, a canonical pinned roster and an explicit hash.
/// Swift's randomized Hasher and the order of Firestore snapshots never enter it.
enum DailySelection: Sendable {
    nonisolated static func dayKey(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    nonisolated static func hash(_ text: String) -> UInt64 {
        var result: UInt64 = 14_695_981_039_346_656_037
        for byte in text.utf8 {
            result ^= UInt64(byte)
            result &*= 1_099_511_628_211
        }
        return result
    }

    nonisolated static func championID(in canonicalIDs: [String], dayKey: String) -> String? {
        let ids = Set(canonicalIDs.filter { !$0.isEmpty }).sorted()
        guard !ids.isEmpty else { return nil }
        return ids[Int(hash("champion:\(dayKey)") % UInt64(ids.count))]
    }
}

/// The algorithm and shuffle are explicit so the same daily seed works across devices.
struct QuizRandomGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    nonisolated init(seed: UInt64) { state = seed }

    nonisolated mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var result = state
        result = (result ^ (result >> 30)) &* 0xBF58476D1CE4E5B9
        result = (result ^ (result >> 27)) &* 0x94D049BB133111EB
        return result ^ (result >> 31)
    }

    nonisolated mutating func shuffled<Value>(_ values: [Value]) -> [Value] {
        guard values.count > 1 else { return values }
        var result = values
        for index in stride(from: result.count - 1, through: 1, by: -1) {
            let other = Int(next() % UInt64(index + 1))
            if index != other { result.swapAt(index, other) }
        }
        return result
    }
}
