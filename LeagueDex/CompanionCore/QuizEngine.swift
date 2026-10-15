import Foundation

enum QuizCategory: String, CaseIterable, Identifiable, Sendable {
    case illustration, description, spell, item, roles, stats
    nonisolated var id: String { rawValue }
    nonisolated var title: String {
        switch self {
        case .illustration: "Illustrations"
        case .description: "Descriptions"
        case .spell: "Compétences"
        case .item: "Objets"
        case .roles: "Rôles"
        case .stats: "Statistiques"
        }
    }
    nonisolated var icon: String {
        switch self {
        case .illustration: "photo"
        case .description: "text.book.closed"
        case .spell: "sparkles"
        case .item: "shield.lefthalf.filled"
        case .roles: "person.3"
        case .stats: "chart.bar"
        }
    }
}

enum QuizDifficulty: String, CaseIterable, Identifiable, Sendable {
    case discovery, standard
    nonisolated var id: String { rawValue }
    nonisolated var title: String { self == .discovery ? "Découverte · 2 choix" : "Confirmé · 4 choix" }
    nonisolated var optionCount: Int { self == .discovery ? 2 : 4 }
}

struct QuizSpellSnapshot: Equatable, Sendable {
    let id: String
    let name: String
    let description: String

    nonisolated init(id: String, name: String, description: String) {
        self.id = id; self.name = name; self.description = description
    }
}

/// Snapshots are made from the app's actual DBChampion/DBItem values at the UI boundary.
struct QuizChampionSnapshot: Equatable, Sendable {
    let id: String
    let name: String
    let title: String
    let description: String
    let roles: [String]
    let spells: [QuizSpellSnapshot]
    let health: Double
    let armor: Double
    let attackDamage: Double

    nonisolated init(id: String, name: String, title: String, description: String, roles: [String],
                     spells: [QuizSpellSnapshot], health: Double, armor: Double, attackDamage: Double) {
        self.id = id; self.name = name; self.title = title; self.description = description
        self.roles = roles; self.spells = spells; self.health = health; self.armor = armor; self.attackDamage = attackDamage
    }
}

struct QuizItemSnapshot: Equatable, Sendable {
    let id: String
    let name: String
    let description: String

    nonisolated init(id: String, name: String, description: String) {
        self.id = id; self.name = name; self.description = description
    }
}

struct QuizOption: Identifiable, Equatable, Sendable {
    let id: String
    let label: String

    nonisolated init(id: String, label: String) { self.id = id; self.label = label }
}

enum QuizImage: Equatable, Sendable {
    case champion(String)
    case item(String)
}

struct QuizQuestion: Identifiable, Equatable, Sendable {
    let id: String
    let category: QuizCategory
    let prompt: String
    let clue: String?
    let image: QuizImage?
    let options: [QuizOption]
    let correctOptionID: String
    let explanation: String

    nonisolated init(id: String, category: QuizCategory, prompt: String, clue: String?, image: QuizImage?,
                     options: [QuizOption], correctOptionID: String, explanation: String) {
        self.id = id; self.category = category; self.prompt = prompt; self.clue = clue; self.image = image
        self.options = options; self.correctOptionID = correctOptionID; self.explanation = explanation
    }

    nonisolated var answerLabel: String { options.first { $0.id == correctOptionID }?.label ?? "" }
}

enum QuizEngine: Sendable {
    /// Fewer than count questions is an explicit unavailable session, never filled
    /// with invented facts or repeated answers masquerading as distinct choices.
    nonisolated static func questions(
        category: QuizCategory, difficulty: QuizDifficulty,
        champions: [QuizChampionSnapshot], items: [QuizItemSnapshot],
        count: Int = 10, seed: UInt64
    ) -> [QuizQuestion] {
        let champions = uniqueChampions(champions)
        var rng = QuizRandomGenerator(seed: seed)
        let needed = difficulty.optionCount
        var pool: [QuizQuestion] = []
        let championOptions = champions.map { QuizOption(id: $0.id, label: $0.name) }
        var spellOwners: [String: Set<String>] = [:]
        if category == .spell {
            for champion in champions {
                for spell in champion.spells {
                    let clue = normalized(masked("\(spell.name)\n\n\(spell.description)", answer: champion.name))
                    spellOwners[clue, default: []].insert(champion.id)
                }
            }
        }

        switch category {
        case .illustration, .description, .spell:
            for champion in champions {
                guard let options = choices(correct: QuizOption(id: champion.id, label: champion.name),
                                            from: championOptions, count: needed, rng: &rng) else { continue }
                if category == .illustration {
                    pool.append(QuizQuestion(id: "illustration:\(champion.id)", category: category,
                        prompt: "Quel champion se cache derrière cette illustration ?", clue: nil,
                        image: .champion(champion.id), options: options, correctOptionID: champion.id,
                        explanation: "Il s’agit de \(champion.name)."))
                } else if category == .description {
                    let clue = masked(champion.description, answer: champion.name)
                    guard !clue.isEmpty else { continue }
                    pool.append(QuizQuestion(id: "description:\(champion.id)", category: category,
                        prompt: "À quel champion correspond cette description ?", clue: clue,
                        image: nil, options: options, correctOptionID: champion.id,
                        explanation: "Cette description du catalogue présente \(champion.name)."))
                } else {
                    for spell in champion.spells.sorted(by: { $0.id < $1.id }) where !spell.name.isEmpty {
                        let clue = masked("\(spell.name)\n\n\(spell.description)", answer: champion.name)
                        guard spellOwners[normalized(clue)]?.count == 1 else { continue }
                        pool.append(QuizQuestion(id: "spell:\(champion.id):\(spell.id)", category: category,
                            prompt: "À quel champion appartient cette compétence ?", clue: clue,
                            image: nil, options: options, correctOptionID: champion.id,
                            explanation: "\(spell.name) appartient à \(champion.name)."))
                    }
                }
            }
        case .item:
            var seen = Set<String>()
            let items = items.sorted { $0.id < $1.id }.filter { !$0.id.isEmpty && !$0.name.isEmpty && seen.insert($0.id).inserted }
            let itemOptions = items.map { QuizOption(id: $0.id, label: $0.name) }
            for item in items {
                guard let options = choices(correct: QuizOption(id: item.id, label: item.name),
                                            from: itemOptions, count: needed, rng: &rng) else { continue }
                pool.append(QuizQuestion(id: "item:\(item.id)", category: category,
                    prompt: "Quel objet correspond à cette icône ?",
                    clue: masked(item.description, answer: item.name), image: .item(item.id),
                    options: options, correctOptionID: item.id, explanation: "Il s’agit de \(item.name)."))
            }
        case .roles:
            let roles = Set(champions.flatMap(\.roles).filter { !$0.isEmpty }).sorted()
            for champion in champions {
                if let question = roleQuestion(champion, roles: roles, optionCount: needed, rng: &rng) {
                    pool.append(question)
                }
            }
        case .stats:
            let stats: [(String, String, (QuizChampionSnapshot) -> Double)] = [
                ("health", "points de vie", { $0.health }),
                ("armor", "armure", { $0.armor }),
                ("damage", "dégâts d’attaque", { $0.attackDamage })
            ]
            for (key, label, value) in stats {
                let candidates = champions.filter { value($0).isFinite && value($0) >= 0 }
                guard candidates.count >= needed else { continue }
                for anchor in candidates {
                    let others = rng.shuffled(candidates.filter { $0.id != anchor.id })
                    let selected = [anchor] + Array(others.prefix(needed - 1))
                    let ordered = selected.sorted { value($0) > value($1) }
                    guard ordered.count == needed, value(ordered[0]) > value(ordered[1]),
                          Set(selected.map { normalized($0.name) }).count == needed else { continue }
                    let correct = ordered[0]
                    let ids = selected.map(\.id).sorted().joined(separator: ":")
                    pool.append(QuizQuestion(id: "stats:\(key):\(ids)", category: category,
                        prompt: "Qui possède le plus de \(label) de base parmi ces champions ?", clue: "Statistiques au niveau 1, sans objets.",
                        image: nil, options: rng.shuffled(selected.map { QuizOption(id: $0.id, label: $0.name) }),
                        correctOptionID: correct.id,
                        explanation: "\(correct.name) : \(formatted(value(correct))) en \(label) au niveau 1."))
                }
            }
        }
        var seen = Set<String>()
        return Array(rng.shuffled(pool.filter { seen.insert($0.id).inserted }).prefix(max(0, count)))
    }

    nonisolated static func dailyQuestion(champions: [QuizChampionSnapshot], dayKey: String) -> QuizQuestion? {
        let champions = uniqueChampions(champions)
        guard let id = DailySelection.championID(in: champions.map(\.id), dayKey: dayKey),
              let champion = champions.first(where: { $0.id == id }) else { return nil }
        var rng = QuizRandomGenerator(seed: DailySelection.hash("daily-quiz:\(dayKey)"))
        let roles = Set(champions.flatMap(\.roles).filter { !$0.isEmpty }).sorted()
        return roleQuestion(champion, roles: roles, optionCount: 2, rng: &rng)
    }

    nonisolated static func plainText(_ text: String) -> String {
        text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated static func masked(_ text: String, answer: String) -> String {
        let text = plainText(text)
        let letters = answer.filter { $0.isLetter || $0.isNumber }
        guard !letters.isEmpty else { return text }
        let pattern = "(?<![\\p{L}\\p{N}])" + letters.map { NSRegularExpression.escapedPattern(for: String($0)) }
            .joined(separator: "[\\s’'._-]*") + "(?![\\p{L}\\p{N}])"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return text }
        return regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "[…]")
    }

    private nonisolated static func uniqueChampions(_ champions: [QuizChampionSnapshot]) -> [QuizChampionSnapshot] {
        var seen = Set<String>()
        return champions.sorted { $0.id < $1.id }.filter { !$0.id.isEmpty && !$0.name.isEmpty && seen.insert($0.id).inserted }
    }

    private nonisolated static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private nonisolated static func choices(correct: QuizOption, from all: [QuizOption], count: Int,
                                             rng: inout QuizRandomGenerator) -> [QuizOption]? {
        var labels: Set<String> = [normalized(correct.label)]
        let alternatives = rng.shuffled(all.filter { $0.id != correct.id }).filter { labels.insert(normalized($0.label)).inserted }
        guard alternatives.count >= count - 1 else { return nil }
        return rng.shuffled([correct] + Array(alternatives.prefix(count - 1)))
    }

    private nonisolated static func roleQuestion(_ champion: QuizChampionSnapshot, roles: [String], optionCount: Int,
                                                 rng: inout QuizRandomGenerator) -> QuizQuestion? {
        let actual = Set(champion.roles.filter { !$0.isEmpty })
        guard let correct = rng.shuffled(actual.sorted()).first else { return nil }
        let alternatives = roles.filter { !actual.contains($0) }.map { QuizOption(id: $0, label: $0) }
        guard let options = choices(correct: QuizOption(id: correct, label: correct), from: alternatives,
                                    count: optionCount, rng: &rng) else { return nil }
        return QuizQuestion(id: "roles:\(champion.id)", category: .roles,
            prompt: "Quel rôle figure dans le catalogue pour \(champion.name) ?", clue: nil,
            image: .champion(champion.id), options: options, correctOptionID: correct,
            explanation: "Rôles du catalogue pour \(champion.name) : \(actual.sorted().joined(separator: ", ")).")
    }

    private nonisolated static func formatted(_ value: Double) -> String {
        String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}
