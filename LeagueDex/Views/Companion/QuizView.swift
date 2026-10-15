import SwiftUI

struct QuizView: View {
    @EnvironmentObject private var quiz: QuizViewModel
    @EnvironmentObject private var daily: DailyChampionStore
    @EnvironmentObject private var catalog: ChampionViewModel
    @EnvironmentObject private var armory: ItemViewModel
    @EnvironmentObject private var userData: UserDataStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @State private var confirmsAbandon = false
    @State private var preloadTask: Task<Void, Never>?
    var dailyChallenge = false

    private var displaysSession: Bool { quiz.hasSession && quiz.isDaily == dailyChallenge }
    private var dailyRun: QuizRun? {
        userData.quizRuns.first { $0.dayKey == daily.dayKey } ?? quiz.submittedDailyResults[daily.dayKey]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LeagueTheme.Space.lg) {
                if dailyChallenge, let dailyRun, !(displaysSession && quiz.isComplete) {
                    dailyParticipation(dailyRun)
                } else if displaysSession {
                    if let result = quiz.result { resultCard(result) }
                    else if let question = quiz.current { questionCard(question) }
                } else if dailyChallenge {
                    dailySetup
                } else {
                    practiceSetup
                }
                if let error = quiz.errorMessage ?? userData.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.footnote).foregroundStyle(LeagueTheme.danger)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !dailyChallenge { history }
            }
            .padding(LeagueTheme.Space.md)
            .padding(.bottom, LeagueTheme.Space.lg)
        }
        .background(LeagueTheme.background)
        .foregroundStyle(LeagueTheme.text)
        .navigationTitle(dailyChallenge ? "Défi quotidien" : "Quiz LeagueDex")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if displaysSession && !quiz.isComplete {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Quitter") { confirmsAbandon = true }
                }
            }
        }
        .confirmationDialog("Quitter cette partie ?", isPresented: $confirmsAbandon, titleVisibility: .visible) {
            Button("Abandonner la partie", role: .destructive) { quiz.closeSession() }
            Button("Continuer", role: .cancel) {}
        } message: {
            Text("Seules les parties terminées sont ajoutées à votre historique.")
        }
        .onReceive(catalog.$champions) { quiz.updateCatalog(champions: $0, items: armory.items) }
        .onReceive(armory.$items) { quiz.updateCatalog(champions: catalog.champions, items: $0) }
        .task { if dailyChallenge { await daily.refresh() } }
        .onDisappear { preloadTask?.cancel(); preloadTask = nil }
        .tint(LeagueTheme.gold)
    }

    private var practiceSetup: some View {
        VStack(alignment: .leading, spacing: LeagueTheme.Space.md) {
            LeagueSectionHeader(title: "Testez vos connaissances", subtitle: "10 questions · 100 points par bonne réponse")
            Picker("Catégorie", selection: $quiz.category) {
                ForEach(QuizCategory.allCases) { category in
                    Label(category.title, systemImage: category.icon).tag(category)
                }
            }
            .pickerStyle(.menu)
            Picker("Difficulté", selection: $quiz.difficulty) {
                ForEach(QuizDifficulty.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.menu)
            Text("Pour jouer sans images, choisissez Descriptions, Compétences, Rôles ou Statistiques.")
                .font(.footnote).foregroundStyle(LeagueTheme.muted)
            if quiz.availablePracticeCount < 10 {
                Text("\(quiz.availablePracticeCount) question(s) disponible(s) sur 10. Il faut des données suffisantes et des réponses distinctes pour commencer.")
                    .font(.subheadline).foregroundStyle(LeagueTheme.muted)
                if quiz.category == .spell {
                    Button {
                        preloadTask = Task { await quiz.preloadSpells(catalog: catalog) }
                    } label: {
                        HStack(spacing: LeagueTheme.Space.sm) {
                            if quiz.isPreloadingSpells { ProgressView().tint(LeagueTheme.gold) }
                            Text(quiz.isPreloadingSpells ? "Fiches téléchargées : \(quiz.preloadedCount) / 8" : "Télécharger jusqu’à 8 fiches champions")
                        }
                    }
                    .buttonStyle(LeagueActionButtonStyle(prominent: false))
                    .disabled(quiz.isPreloadingSpells || catalog.champions.isEmpty)
                    Text("Seules les compétences réellement téléchargées sont utilisées. Les fiches restent consultables hors ligne.")
                        .font(.footnote).foregroundStyle(LeagueTheme.muted)
                }
                if catalog.champions.isEmpty || (quiz.category == .item && armory.items.isEmpty) {
                    Button("Recharger les catalogues") {
                        catalog.fetchChampionsFromFirebase()
                        armory.fetchItemsFromFirebase()
                    }
                    .buttonStyle(LeagueActionButtonStyle(prominent: false))
                }
            }
            Button("Commencer la partie") { quiz.startPractice() }
                .buttonStyle(LeagueActionButtonStyle())
                .disabled(quiz.availablePracticeCount < 10 || quiz.isPreloadingSpells)
        }
        .padding(LeagueTheme.Space.md).leagueSurface()
        .disabled(quiz.isPreloadingSpells)
    }

    private var dailySetup: some View {
        VStack(alignment: .leading, spacing: LeagueTheme.Space.md) {
            LeagueSectionHeader(title: "La question du jour", subtitle: "\(daily.dayKey) · UTC")
            Text("Une question sur le champion du jour, commune à tous. Une participation enregistrée par compte et par jour UTC.")
                .font(.subheadline).foregroundStyle(LeagueTheme.muted)
            if let question = daily.question {
                Button("Relever le défi") { quiz.startDaily(question: question, dayKey: daily.dayKey) }
                    .buttonStyle(LeagueActionButtonStyle())
            } else if daily.isLoading {
                LeagueLoadingState(message: "Préparation du défi…")
            } else {
                Text(daily.errorMessage ?? "Le défi sera disponible après le téléchargement du catalogue Riot.")
                    .font(.subheadline).foregroundStyle(LeagueTheme.muted)
                Button("Réessayer") { Task { await daily.refresh(force: true) } }
                    .buttonStyle(LeagueActionButtonStyle(prominent: false))
            }
        }
        .padding(LeagueTheme.Space.md).leagueSurface()
    }

    private func questionCard(_ question: QuizQuestion) -> some View {
        VStack(alignment: .leading, spacing: LeagueTheme.Space.md) {
            HStack {
                Text("Question \(quiz.questionIndex + 1) / \(quiz.questions.count)")
                Spacer()
                Text("\(quiz.correctCount * 100) points").foregroundStyle(LeagueTheme.gold)
            }
            .font(.subheadline.weight(.semibold))
            ProgressView(value: Double(quiz.questionIndex + (quiz.selectedOptionID == nil ? 0 : 1)), total: Double(quiz.questions.count))
                .tint(LeagueTheme.gold)
                .accessibilityLabel("Progression de la partie")
            Text(question.prompt).font(.title2.weight(.bold)).fixedSize(horizontal: false, vertical: true)
            if let image = question.image { questionImage(image) }
            if let clue = question.clue, !clue.isEmpty {
                Text(clue).font(.body).foregroundStyle(LeagueTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(question.options) { option in
                answerButton(option, question: question)
            }
            if quiz.selectedOptionID != nil {
                VStack(alignment: .leading, spacing: LeagueTheme.Space.sm) {
                    Label(quiz.isCorrect ? "Bonne réponse !" : "La bonne réponse : \(question.answerLabel)",
                          systemImage: quiz.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.headline).foregroundStyle(quiz.isCorrect ? LeagueTheme.cyan : LeagueTheme.danger)
                    Text(question.explanation).font(.subheadline).foregroundStyle(LeagueTheme.muted)
                }
                .accessibilityElement(children: .combine)
                .transition(.opacity)
                Button(quiz.questionIndex + 1 == quiz.questions.count ? "Voir mon résultat" : "Question suivante") {
                    if let run = quiz.advance() { userData.saveQuizRun(run) }
                }
                .buttonStyle(LeagueActionButtonStyle())
            }
        }
        .padding(LeagueTheme.Space.md).leagueSurface()
    }

    private func answerButton(_ option: QuizOption, question: QuizQuestion) -> some View {
        let answered = quiz.selectedOptionID != nil
        let isSelected = quiz.selectedOptionID == option.id
        let correct = option.id == question.correctOptionID
        let color = answered && correct ? LeagueTheme.cyan : (isSelected ? LeagueTheme.danger : LeagueTheme.border)
        return Button {
            withAnimation(reduceMotion ? nil : LeagueMotion.quick) { quiz.answer(option.id) }
        } label: {
            HStack(spacing: LeagueTheme.Space.sm) {
                Text(option.label).font(.headline).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: LeagueTheme.Space.sm)
                if answered && (correct || isSelected) {
                    Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(color).accessibilityHidden(true)
                }
            }
            .foregroundStyle(LeagueTheme.text)
            .padding(LeagueTheme.Space.md)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(LeagueTheme.elevated, in: RoundedRectangle(cornerRadius: LeagueTheme.Corner.medium))
            .overlay { RoundedRectangle(cornerRadius: LeagueTheme.Corner.medium).strokeBorder(color, lineWidth: isSelected ? 2 : 1) }
        }
        .buttonStyle(.plain)
        .disabled(answered)
        .accessibilityLabel(option.label)
        .accessibilityValue(answered ? (correct ? "Bonne réponse" : (isSelected ? "Votre réponse, incorrecte" : "")) : "")
        .accessibilityHint(answered ? "" : "Valider cette réponse")
    }

    private func questionImage(_ image: QuizImage) -> some View {
        let url: URL?
        let height: CGFloat
        let label: String
        switch image {
        case .champion(let id):
            url = URL(string: "\(DataDragon.baseURL)/cdn/img/champion/splash/\(id)_0.jpg")
            height = 200
            label = "Illustration du champion à identifier"
        case .item(let id):
            url = DataDragon.imageURL("item/\(id).png")
            height = 120
            label = "Icône de l’objet à identifier"
        }
        return CachedAsyncImage(url: url) { image in
            image.resizable().scaledToFit()
        } placeholder: {
            VStack(spacing: LeagueTheme.Space.sm) {
                Image(systemName: "photo").font(.largeTitle)
                Text("Illustration indisponible ou en cours de chargement.").font(.footnote)
            }
            .foregroundStyle(LeagueTheme.muted)
        }
        .imageDimension(400)
        .frame(maxWidth: .infinity).frame(height: height)
        .background(LeagueTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: LeagueTheme.Corner.medium))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    private func resultCard(_ run: QuizRun) -> some View {
        VStack(alignment: .leading, spacing: LeagueTheme.Space.md) {
            Label("Partie terminée", systemImage: "checkmark.seal.fill")
                .font(.title2.weight(.bold)).foregroundStyle(LeagueTheme.gold)
            Text("\(run.score) points").font(.largeTitle.bold().monospacedDigit())
            Text("\(run.correct) bonne(s) réponse(s) sur \(run.total)").font(.headline)
            Text("100 points par bonne réponse.").font(.footnote).foregroundStyle(LeagueTheme.muted)
            if dailyChallenge { dailyParticipation(run) }
            else {
                Text(userData.hasPendingWrites ? "Résultat en attente de synchronisation." : "Retrouvez votre résultat dans l’historique de votre compte.")
                    .font(.subheadline).foregroundStyle(LeagueTheme.muted)
                Button("Préparer une nouvelle partie") { quiz.closeSession() }
                    .buttonStyle(LeagueActionButtonStyle())
            }
        }
        .padding(LeagueTheme.Space.md).leagueSurface()
    }

    private func dailyParticipation(_ run: QuizRun) -> some View {
        let synchronized = userData.quizRuns.contains { $0.dayKey == run.dayKey } && !userData.hasPendingWrites && !userData.isFromCache
        return VStack(alignment: .leading, spacing: LeagueTheme.Space.md) {
            Label("Participation du \(run.dayKey)", systemImage: "calendar.badge.checkmark")
                .font(.headline).foregroundStyle(LeagueTheme.gold)
            Text("\(run.score) points · \(run.correct) / \(run.total) bonne(s) réponse(s)")
            Text(synchronized ? "Participation synchronisée. Prochain défi à 00:00 UTC." : "Participation conservée sur cet appareil. Synchronisation en attente ou confirmation serveur nécessaire.")
                .font(.subheadline).foregroundStyle(LeagueTheme.muted)
            Button("Revenir à l’accueil") { dismiss() }
                .buttonStyle(LeagueActionButtonStyle(prominent: false))
        }
        .padding(LeagueTheme.Space.md).leagueSurface()
    }

    private var history: some View {
        let runs = userData.quizRuns
        let total = runs.reduce(0) { $0 + $1.total }
        let correct = runs.reduce(0) { $0 + $1.correct }
        return VStack(alignment: .leading, spacing: LeagueTheme.Space.md) {
            LeagueSectionHeader(title: "Votre progression", subtitle: "Historique synchronisé avec votre compte")
            Text("\(runs.count) partie(s) · \(runs.reduce(0) { $0 + $1.score }) points")
                .font(.headline).foregroundStyle(LeagueTheme.gold)
            if total > 0 {
                Text("\(correct) bonnes réponses sur \(total) · \(Int(Double(correct) / Double(total) * 100)) % de réussite")
                    .font(.subheadline).foregroundStyle(LeagueTheme.muted)
            } else {
                Text("Terminez une première partie pour démarrer votre historique.")
                    .font(.subheadline).foregroundStyle(LeagueTheme.muted)
            }
            ForEach(Array(runs.prefix(20))) { run in
                VStack(alignment: .leading, spacing: LeagueTheme.Space.xs) {
                    Text(run.dayKey.isEmpty ? (QuizCategory(rawValue: run.category)?.title ?? run.category) : "Défi quotidien · \(run.dayKey)")
                        .font(.headline)
                    Text("\(run.score) points · \(run.correct) / \(run.total)")
                        .font(.subheadline).foregroundStyle(LeagueTheme.gold)
                    Text(run.completedAt, format: .dateTime.day().month().year().hour().minute())
                        .font(.caption).foregroundStyle(LeagueTheme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(LeagueTheme.Space.md).leagueSurface()
            }
        }
    }
}
