import Foundation
import Combine

@MainActor
final class QuizViewModel: ObservableObject {
    @Published var category: QuizCategory = .illustration {
        didSet { refreshAvailability() }
    }
    @Published var difficulty: QuizDifficulty = .discovery {
        didSet { refreshAvailability() }
    }
    @Published private(set) var availablePracticeCount = 0
    @Published private(set) var questions: [QuizQuestion] = []
    @Published private(set) var questionIndex = 0
    @Published private(set) var selectedOptionID: String?
    @Published private(set) var correctCount = 0
    @Published private(set) var result: QuizRun?
    @Published private(set) var isDaily = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var isPreloadingSpells = false
    @Published private(set) var preloadedCount = 0
    @Published private(set) var submittedDailyResults: [String: QuizRun] = [:]

    private var champions: [QuizChampionSnapshot] = []
    private var items: [QuizItemSnapshot] = []
    private var sessionID = UUID().uuidString
    private var sessionCategory = QuizCategory.illustration
    private var sessionDifficulty = QuizDifficulty.discovery
    private var sessionDayKey = ""

    var current: QuizQuestion? { questions.indices.contains(questionIndex) ? questions[questionIndex] : nil }
    var hasSession: Bool { !questions.isEmpty }
    var isComplete: Bool { result != nil }
    var isCorrect: Bool { selectedOptionID != nil && selectedOptionID == current?.correctOptionID }

    func updateCatalog(champions: [DBChampion], items: [DBItem]) {
        let championSnapshots = champions.map { champion in
            var spells = champion.spells.map { QuizSpellSnapshot(id: $0.id, name: $0.name, description: $0.desc) }
            if champion.isDetailLoaded, !champion.passiveName.isEmpty {
                spells.append(QuizSpellSnapshot(id: "passive-\(champion.id)", name: champion.passiveName, description: champion.passiveDesc))
            }
            return QuizChampionSnapshot(id: champion.id, name: champion.name, title: champion.title,
                description: champion.blurb, roles: champion.tags, spells: spells,
                health: champion.hp, armor: champion.armor, attackDamage: champion.attackdamage)
        }
        let itemSnapshots = items.map { QuizItemSnapshot(id: $0.id, name: $0.name, description: $0.plaintext) }
        guard championSnapshots != self.champions || itemSnapshots != self.items else { return }
        self.champions = championSnapshots
        self.items = itemSnapshots
        refreshAvailability()
    }

    func startPractice() {
        let questions = QuizEngine.questions(category: category, difficulty: difficulty, champions: champions, items: items,
            seed: UInt64.random(in: UInt64.min...UInt64.max))
        guard questions.count == 10 else {
            errorMessage = "Il faut suffisamment de données pour dix questions distinctes. Essayez Découverte ou téléchargez davantage de fiches."
            return
        }
        start(questions, category: category, difficulty: difficulty, dayKey: "")
    }

    func startDaily(question: QuizQuestion, dayKey: String) {
        guard dayKey == DailySelection.dayKey(for: Date()) else {
            errorMessage = "Le jour UTC a changé. Actualisez le défi quotidien."
            return
        }
        guard submittedDailyResults[dayKey] == nil else {
            errorMessage = "Votre participation à ce défi est déjà enregistrée sur cet appareil."
            return
        }
        // Reopening the same challenge preserves a submitted or answered session.
        if isDaily, sessionDayKey == dayKey, hasSession { return }
        start([question], category: question.category, difficulty: .discovery, dayKey: dayKey)
    }

    func answer(_ optionID: String) {
        guard selectedOptionID == nil, result == nil, let current,
              current.options.contains(where: { $0.id == optionID }) else { return }
        selectedOptionID = optionID
        if optionID == current.correctOptionID { correctCount += 1 }
    }

    /// The final result is emitted once. The view sends it to the shared uid store.
    func advance() -> QuizRun? {
        guard selectedOptionID != nil, result == nil else { return nil }
        if isDaily && sessionDayKey != DailySelection.dayKey(for: Date()) {
            errorMessage = "Ce défi a expiré à minuit UTC. Revenez à l’accueil pour ouvrir celui d’aujourd’hui."
            return nil
        }
        if questionIndex + 1 < questions.count {
            questionIndex += 1
            selectedOptionID = nil
            return nil
        }
        let run = QuizRun(id: sessionID, category: sessionCategory.rawValue, difficulty: sessionDifficulty.rawValue,
            score: correctCount * 100, correct: correctCount, total: questions.count,
            completedAt: Date(), dayKey: sessionDayKey)
        result = run
        if isDaily { submittedDailyResults[sessionDayKey] = run }
        return run
    }

    func closeSession() {
        questions = []
        questionIndex = 0
        selectedOptionID = nil
        correctCount = 0
        result = nil
        isDaily = false
        errorMessage = nil
    }

    func preloadSpells(catalog: ChampionViewModel) async {
        guard !isPreloadingSpells else { return }
        isPreloadingSpells = true
        preloadedCount = 0
        defer { isPreloadingSpells = false }
        let candidates = catalog.champions.filter { !$0.isDetailLoaded }.sorted { $0.id < $1.id }.prefix(8)
        for champion in candidates {
            guard !Task.isCancelled else { return }
            await catalog.loadDetails(for: champion)
            preloadedCount += 1
            if category == .spell, availablePracticeCount >= 10 { break }
        }
        if availablePracticeCount < 10 {
            errorMessage = "Les compétences téléchargées ne suffisent pas encore. Vérifiez la connexion ou choisissez une autre catégorie."
        } else { errorMessage = nil }
    }

    private func refreshAvailability() {
        availablePracticeCount = QuizEngine.questions(category: category, difficulty: difficulty,
            champions: champions, items: items, seed: 0).count
        errorMessage = nil
    }

    private func start(_ questions: [QuizQuestion], category: QuizCategory, difficulty: QuizDifficulty, dayKey: String) {
        closeSession()
        self.questions = questions
        sessionID = UUID().uuidString
        sessionCategory = category
        sessionDifficulty = difficulty
        sessionDayKey = dayKey
        isDaily = !dayKey.isEmpty
    }
}
