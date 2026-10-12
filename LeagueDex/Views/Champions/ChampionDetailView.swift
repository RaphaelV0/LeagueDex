import SwiftUI

struct ChampionDetailView: View {
    let championId: String
    @ObservedObject var viewModel: ChampionViewModel
    private let initialFallback: DBChampion

    var champion: DBChampion {
        viewModel.champions.first(where: { $0.id == championId }) ?? initialFallback
    }

    init(champion: DBChampion, viewModel: ChampionViewModel) {
        self.initialFallback = champion
        self.championId = champion.id
        self.viewModel = viewModel
    }

    @ScaledMetric(relativeTo: .largeTitle) private var scalableHeroHeight: CGFloat = 320
    @State private var selectedLevel: Double = 1
    @State private var selectedSpellTitle = ""
    @State private var selectedSpellDesc = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let hapticFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let statColumns = [GridItem(.adaptive(minimum: 136), spacing: 12)]

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    hero
                        .leagueReveal()

                    VStack(alignment: .leading, spacing: LeagueTheme.Space.lg) {
                        identity
                        sectionShortcuts(proxy: scrollProxy)
                            .leagueReveal()

                        if champion.isDetailLoaded {
                            skillsSection
                                .id("skills")
                                .leagueReveal()
                        }

                        statsSection
                            .id("stats")
                            .leagueReveal()

                        if !champion.allyTips.isEmpty || !champion.enemyTips.isEmpty {
                            tipsSection
                                .id("tips")
                                .leagueReveal()
                        }

                        if !champion.skins.isEmpty {
                            skinsSection
                                .id("skins")
                                .leagueReveal()
                        }

                        if !champion.fullLore.isEmpty {
                            VStack(alignment: .leading, spacing: LeagueTheme.Space.sm) {
                                LeagueSectionHeader(title: "Histoire")
                                Text(champion.fullLore.removingHTML())
                                    .font(.body)
                                    .foregroundStyle(LeagueTheme.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.horizontal, LeagueTheme.Space.md)
                    .padding(.top, LeagueTheme.Space.md)
                    .padding(.bottom, 40)
                }
            }
            .background(LeagueTheme.background)
        }
        .id(champion.id)
        .edgesIgnoringSafeArea(.top)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    hapticFeedback.impactOccurred()
                    viewModel.toggleFavorite(for: champion)
                } label: {
                    Image(systemName: champion.isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(champion.isFavorite ? LeagueTheme.danger : LeagueTheme.gold)
                }
                .accessibilityLabel(champion.isFavorite ? "Retirer des favoris" : "Ajouter aux favoris")
            }
        }
        .task {
            await viewModel.loadDetails(for: champion)
            selectPassiveIfNeeded()
        }
        .onChange(of: champion.isDetailLoaded) { loaded in
            if loaded { selectPassiveIfNeeded() }
        }
    }

    private var hero: some View {
        GeometryReader { geometry in
            let minY = geometry.frame(in: .global).minY
            let stretch = max(0, minY)
            let heroHeight = min(500, max(320, scalableHeroHeight))

            ZStack(alignment: .bottomLeading) {
                CachedAsyncImage(url: champion.splashArtURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    LeagueSkeletonBlock(radius: LeagueTheme.Corner.large)
                }
                    .imageDimension(500)
                    .frame(width: geometry.size.width, height: heroHeight + stretch)
                    .clipped()
                    .offset(y: -stretch)

                LeagueTheme.championGradient
                    .frame(height: heroHeight + stretch)
                    .offset(y: -stretch)

                VStack(alignment: .leading, spacing: LeagueTheme.Space.xs) {
                    Text(champion.name)
                        .font(.largeTitle.weight(.heavy))
                        .foregroundStyle(LeagueTheme.text)
                        .minimumScaleFactor(0.8)
                    Text(champion.title.capitalized)
                        .font(.title3)
                        .foregroundStyle(LeagueTheme.muted)
                }
                .padding(LeagueTheme.Space.md)
                .offset(y: -stretch)
            }
        }
        .frame(height: min(500, max(320, scalableHeroHeight)))
        .accessibilityElement(children: .combine)
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: LeagueTheme.Space.md) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: LeagueTheme.Space.sm) {
                    ForEach(champion.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(LeagueTheme.gold)
                            .padding(.horizontal, LeagueTheme.Space.md)
                            .frame(minHeight: 36)
                            .background(LeagueTheme.elevated, in: Capsule())
                    }
                }
            }
            let overview = champion.blurb.removingHTML()
            if !overview.isEmpty {
                Text(overview)
                    .font(.subheadline)
                    .foregroundStyle(LeagueTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func sectionShortcuts(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: LeagueTheme.Space.sm) {
            Text("Accès rapide")
                .font(.caption.weight(.semibold))
                .foregroundStyle(LeagueTheme.muted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: LeagueTheme.Space.sm) {
                    if champion.isDetailLoaded {
                        shortcut("Compétences", systemImage: "sparkles", target: "skills", proxy: proxy)
                    }
                    shortcut("Stats", systemImage: "chart.bar.fill", target: "stats", proxy: proxy)
                    if !champion.allyTips.isEmpty || !champion.enemyTips.isEmpty {
                        shortcut("Conseils", systemImage: "lightbulb", target: "tips", proxy: proxy)
                    }
                    if !champion.skins.isEmpty {
                        shortcut("Skins", systemImage: "photo.on.rectangle", target: "skins", proxy: proxy)
                    }
                }
            }
        }
    }

    private func shortcut(
        _ label: String,
        systemImage: String,
        target: String,
        proxy: ScrollViewProxy
    ) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                proxy.scrollTo(target, anchor: .top)
            }
        } label: {
            Label(label, systemImage: systemImage)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(LeagueTheme.text)
                .padding(.horizontal, LeagueTheme.Space.md)
                .frame(minHeight: 44)
                .background(LeagueTheme.elevated, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var skillsSection: some View {
        VStack(alignment: .leading, spacing: LeagueTheme.Space.md) {
            LeagueSectionHeader(title: "Compétences", subtitle: "Touchez une compétence pour afficher sa description")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: LeagueTheme.Space.md) {
                    Button {
                        selectSpell(
                            title: "Passif : \(champion.passiveName)",
                            description: champion.passiveDesc
                        )
                    } label: {
                        SpellIcon(url: DataDragon.imageURL("passive/\(champion.passiveImage)"))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Passif : \(champion.passiveName)")

                    ForEach(champion.spells) { spell in
                        Button {
                            selectSpell(title: spell.name, description: spell.desc)
                        } label: {
                            SpellIcon(url: spell.url)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Compétence : \(spell.name)")
                    }
                }
                .padding(.vertical, LeagueTheme.Space.xs)
            }

            if !selectedSpellTitle.isEmpty {
                VStack(alignment: .leading, spacing: LeagueTheme.Space.sm) {
                    Text(selectedSpellTitle)
                        .font(.headline)
                        .foregroundStyle(LeagueTheme.gold)
                        .contentTransition(.opacity)
                        .animation(reduceMotion ? nil : LeagueMotion.quick, value: selectedSpellTitle)
                    Text(selectedSpellDesc)
                        .font(.subheadline)
                        .foregroundStyle(LeagueTheme.muted)
                        .contentTransition(.opacity)
                        .animation(reduceMotion ? nil : LeagueMotion.quick, value: selectedSpellDesc)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(LeagueTheme.Space.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .leagueSurface(radius: LeagueTheme.Corner.medium)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: LeagueTheme.Space.md) {
            HStack {
                LeagueSectionHeader(title: "Statistiques", subtitle: "Évolution du niveau 1 à 18")
                Text("Niv. \(Int(selectedLevel))")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(LeagueTheme.gold)
            }

            ProgressView(value: selectedLevel - 1, total: 17)
                .tint(LeagueTheme.cyan)
                .animation(reduceMotion ? nil : LeagueMotion.quick, value: selectedLevel)
                .accessibilityHidden(true)

            HStack(spacing: LeagueTheme.Space.md) {
                Button("1") { selectedLevel = 1 }
                    .accessibilityLabel("Niveau 1")
                Slider(value: $selectedLevel, in: 1...18, step: 1)
                    .tint(LeagueTheme.gold)
                    .accessibilityLabel("Niveau du champion")
                    .accessibilityValue("\(Int(selectedLevel)) sur 18")
                Button("18") { selectedLevel = 18 }
                    .accessibilityLabel("Niveau 18")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(LeagueTheme.gold)
            .buttonStyle(.bordered)

            LazyVGrid(columns: statColumns, spacing: LeagueTheme.Space.sm) {
                RealStatCard(title: "Points de Vie", icon: "heart.fill", color: .green,
                             value: champion.statAt(base: champion.hp, growth: champion.hpperlevel, level: Int(selectedLevel)))
                RealStatCard(title: "Mana / Énergie", icon: "drop.fill", color: .blue,
                             value: champion.statAt(base: champion.mp, growth: champion.mpperlevel, level: Int(selectedLevel)))
                RealStatCard(title: "Dégâts", icon: "flame.fill", color: .red,
                             value: champion.statAt(base: champion.attackdamage, growth: champion.attackdamageperlevel, level: Int(selectedLevel)))
                RealStatCard(title: "Vitesse d'Attaque", icon: "bolt.fill", color: .yellow,
                             value: champion.statAt(base: champion.attackspeed, growth: champion.attackspeedperlevel, level: Int(selectedLevel)))
                RealStatCard(title: "Armure", icon: "shield.fill", color: .orange,
                             value: champion.statAt(base: champion.armor, growth: champion.armorperlevel, level: Int(selectedLevel)))
                RealStatCard(title: "Résistance Mag.", icon: "sparkles", color: .purple,
                             value: champion.statAt(base: champion.spellblock, growth: champion.spellblockperlevel, level: Int(selectedLevel)))
                RealStatCard(title: "Vitesse Mvt", icon: "wind", color: .teal, value: champion.movespeed)
                RealStatCard(title: "Critique", icon: "target", color: .pink,
                             value: champion.statAt(base: champion.crit, growth: champion.critperlevel, level: Int(selectedLevel)))
            }
        }
        .padding(LeagueTheme.Space.md)
        .leagueSurface()
    }

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: LeagueTheme.Space.md) {
            LeagueSectionHeader(title: "Astuces")
            if !champion.allyTips.isEmpty {
                Text("Pour jouer \(champion.name)")
                    .font(.headline).foregroundStyle(LeagueTheme.cyan)
                ForEach(champion.allyTips, id: \.self) { tip in
                    Text("• \(tip)")
                        .font(.subheadline)
                        .foregroundStyle(LeagueTheme.muted)
                }
            }
            if !champion.enemyTips.isEmpty {
                Text("Contre \(champion.name)")
                    .font(.headline).foregroundStyle(LeagueTheme.danger)
                ForEach(champion.enemyTips, id: \.self) { tip in
                    Text("• \(tip)")
                        .font(.subheadline)
                        .foregroundStyle(LeagueTheme.muted)
                }
            }
        }
    }

    private var skinsSection: some View {
        VStack(alignment: .leading, spacing: LeagueTheme.Space.md) {
            LeagueSectionHeader(title: "Galerie", subtitle: "\(champion.skins.count) apparence(s)")
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: LeagueTheme.Space.md) {
                    ForEach(champion.skins) { skin in
                        ZStack(alignment: .bottomLeading) {
                            CachedAsyncImage(url: skin.url) { image in
                                image.resizable().scaledToFill()
                            } placeholder: { LeagueTheme.elevated }
                            .imageDimension(310)
                            .frame(width: 260, height: 160)
                            .clipped()

                            LinearGradient(colors: [.clear, .black.opacity(0.85)],
                                           startPoint: .center, endPoint: .bottom)
                            Text(skin.name == "default" ? champion.name : skin.name)
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(LeagueTheme.Space.md)
                        }
                        .frame(width: 260, height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: LeagueTheme.Corner.large))
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    private func selectSpell(title: String, description: String) {
        hapticFeedback.impactOccurred(intensity: 0.7)
        withAnimation(reduceMotion ? nil : .easeOut(duration: LeagueTheme.pressDuration)) {
            selectedSpellTitle = title
            selectedSpellDesc = description.removingHTML()
        }
    }

    private func selectPassiveIfNeeded() {
        guard selectedSpellTitle.isEmpty, champion.isDetailLoaded else { return }
        selectedSpellTitle = "Passif : \(champion.passiveName)"
        selectedSpellDesc = champion.passiveDesc.removingHTML()
    }
}
