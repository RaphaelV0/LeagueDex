import Foundation
import Testing
@testable import CompanionCore

@Suite("Real-data quiz generation and deterministic UTC days")
struct QuizEngineTests {
    private var champions: [QuizChampionSnapshot] {
        let roles = ["Mage", "Assassin", "Fighter", "Tank", "Marksman", "Support"]
        return (0..<16).map { index in
            QuizChampionSnapshot(id: "Fixture\(index)", name: "Champion \(index)", title: "Titre \(index)",
                description: "Champion \(index) est un personnage de la description de test.",
                roles: [roles[index % roles.count], roles[(index + 1) % roles.count]],
                spells: [QuizSpellSnapshot(id: "spell\(index)", name: "Compétence \(index)", description: "Champion \(index) utilise cette compétence.")],
                health: Double(500 + index * 20), armor: Double(20 + index), attackDamage: Double(40 + index))
        }
    }
    private var items: [QuizItemSnapshot] {
        (0..<16).map { QuizItemSnapshot(id: "item\($0)", name: "Objet \($0)", description: "Objet \($0) possède cette description de test.") }
    }

    @Test("FNV-1a uses stable published vectors instead of Swift Hasher")
    func hashVectors() {
        #expect(DailySelection.hash("") == 0xcbf29ce484222325)
        #expect(DailySelection.hash("hello") == 0xa430d84680aabd0b)
    }

    @Test("The day changes at UTC midnight and remains fixed on either side")
    func utcBoundary() throws {
        let formatter = ISO8601DateFormatter()
        let before = try #require(formatter.date(from: "2026-10-15T23:59:59Z"))
        let after = try #require(formatter.date(from: "2026-10-16T00:00:00Z"))
        #expect(DailySelection.dayKey(for: before) == "2026-10-15")
        #expect(DailySelection.dayKey(for: after) == "2026-10-16")
        #expect(DailySelection.dayKey(for: before.addingTimeInterval(-20_000)) == "2026-10-15")
    }

    @Test("Daily champion selection ignores snapshot order and repeated IDs")
    func stableRoster() {
        let ids = champions.map(\.id)
        let selected = DailySelection.championID(in: ids, dayKey: "2026-10-15")
        #expect(selected == DailySelection.championID(in: Array(ids.reversed()) + ids, dayKey: "2026-10-15"))
        #expect(selected != nil)
        #expect(DailySelection.championID(in: [], dayKey: "2026-10-15") == nil)
    }

    @Test("Every category creates ten unique questions when genuine data suffices", arguments: QuizCategory.allCases)
    func allCategories(category: QuizCategory) {
        let questions = QuizEngine.questions(category: category, difficulty: .standard,
            champions: champions, items: items, seed: 42)
        #expect(questions.count == 10)
        #expect(Set(questions.map(\.id)).count == 10)
        for question in questions {
            #expect(question.options.count == 4)
            #expect(Set(question.options.map(\.id)).count == 4)
            #expect(Set(question.options.map(\.label)).count == 4)
            #expect(question.options.filter { $0.id == question.correctOptionID }.count == 1)
        }
    }

    @Test("Discovery uses two choices and four-choice mode is unavailable with only two champions")
    func dataAvailability() {
        let available = Array(champions.prefix(2))
        #expect(QuizEngine.questions(category: .illustration, difficulty: .discovery,
            champions: available, items: [], seed: 4).allSatisfy { $0.options.count == 2 })
        #expect(QuizEngine.questions(category: .illustration, difficulty: .standard,
            champions: available, items: [], seed: 4).isEmpty)
    }

    @Test("Missing detail data never fabricates a spell question")
    func missingSpells() {
        let bare = champions.map {
            QuizChampionSnapshot(id: $0.id, name: $0.name, title: $0.title, description: $0.description,
                roles: $0.roles, spells: [], health: $0.health, armor: $0.armor, attackDamage: $0.attackDamage)
        }
        #expect(QuizEngine.questions(category: .spell, difficulty: .standard, champions: bare, items: [], seed: 1).isEmpty)
    }

    @Test("Identical masked ability clues shared by different champions are skipped")
    func ambiguousSpells() {
        let shared = champions.map {
            QuizChampionSnapshot(id: $0.id, name: $0.name, title: $0.title, description: $0.description,
                roles: $0.roles, spells: [QuizSpellSnapshot(id: "shared", name: "Même compétence", description: "Même description")],
                health: $0.health, armor: $0.armor, attackDamage: $0.attackDamage)
        }
        #expect(QuizEngine.questions(category: .spell, difficulty: .standard,
            champions: shared, items: [], seed: 1).isEmpty)
    }

    @Test("Descriptions and spell clues mask the answer in visible and VoiceOver text")
    func noAnswerLeak() {
        for category in [QuizCategory.description, .spell, .item] {
            let questions = QuizEngine.questions(category: category, difficulty: .standard,
                champions: champions, items: items, seed: 4)
            for question in questions {
                #expect(!(question.clue ?? "").localizedCaseInsensitiveContains(question.answerLabel))
            }
        }
        #expect(QuizEngine.masked("<b>Kha’Zix</b> et kha'zix attaquent.", answer: "Kha'Zix") == "[…] et […] attaquent.")
        #expect(QuizEngine.masked("Vi protège la vie.", answer: "Vi") == "[…] protège la vie.")
    }

    @Test("A two-role champion has exactly one correct role among the choices")
    func roleAmbiguity() throws {
        let questions = QuizEngine.questions(category: .roles, difficulty: .standard,
            champions: champions, items: [], seed: 8)
        for question in questions {
            let id = String(question.id.dropFirst("roles:".count))
            let champion = try #require(champions.first { $0.id == id })
            #expect(question.options.filter { champion.roles.contains($0.id) }.count == 1)
        }
    }

    @Test("Identical item display names never appear as ambiguous answer choices")
    func duplicateNames() {
        let duplicates = items + [QuizItemSnapshot(id: "renamed-item", name: items[0].name, description: "Description")]
        let questions = QuizEngine.questions(category: .item, difficulty: .standard,
            champions: [], items: duplicates, count: 30, seed: 5)
        for question in questions { #expect(Set(question.options.map(\.label)).count == 4) }
    }

    @Test("Stat questions use actual input values and a unique maximum")
    func statAnswers() {
        let questions = QuizEngine.questions(category: .stats, difficulty: .standard,
            champions: champions, items: [], seed: 2)
        for question in questions {
            let selected = champions.filter { champion in question.options.contains { $0.id == champion.id } }
            // All fixture stats are strictly increasing together, making the actual winner unambiguous.
            let winner = selected.max { $0.health < $1.health }
            #expect(question.correctOptionID == winner?.id)
        }
    }

    @Test("Tied maxima never become a question with two correct answers")
    func statTies() {
        let equal = champions.map {
            QuizChampionSnapshot(id: $0.id, name: $0.name, title: $0.title, description: $0.description,
                roles: $0.roles, spells: [], health: 500, armor: 30, attackDamage: 50)
        }
        #expect(QuizEngine.questions(category: .stats, difficulty: .standard,
            champions: equal, items: [], seed: 2).isEmpty)
    }

    @Test("Daily question and answer order remain deterministic from canonical data")
    func stableDailyQuestion() throws {
        let first = try #require(QuizEngine.dailyQuestion(champions: champions, dayKey: "2026-10-15"))
        let reordered = QuizEngine.dailyQuestion(champions: Array(champions.reversed()), dayKey: "2026-10-15")
        #expect(first == reordered)
        #expect(first.options.count == 2)
        #expect(first.id == "roles:\(DailySelection.championID(in: champions.map(\.id), dayKey: "2026-10-15") ?? "")")
    }

    @Test("Practice session generation is deterministic for a given seed")
    func stablePractice() {
        let first = QuizEngine.questions(category: .illustration, difficulty: .standard,
            champions: champions, items: items, seed: 999)
        let second = QuizEngine.questions(category: .illustration, difficulty: .standard,
            champions: Array(champions.reversed()), items: Array(items.reversed()), seed: 999)
        #expect(first == second)
    }

    @Test("Pure quiz generation can run away from the main actor")
    func detachedGeneration() async {
        let snapshots = champions
        let questions = await Task.detached {
            QuizEngine.questions(category: .illustration, difficulty: .standard,
                champions: snapshots, items: [], seed: 7)
        }.value
        #expect(questions.count == 10)
    }
}
