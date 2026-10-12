import SwiftUI

struct ChampionDetailView: View {
    let championId: String
    @ObservedObject var viewModel: ChampionViewModel
    
    // Récupère en temps réel la version la plus à jour depuis le ViewModel (synchronisée avec Firebase)
    var champion: DBChampion {
        viewModel.champions.first(where: { $0.id == championId }) ?? initialFallback
    }
    private let initialFallback: DBChampion
    
    init(champion: DBChampion, viewModel: ChampionViewModel) {
        self.initialFallback = champion
        self.championId = champion.id
        self.viewModel = viewModel
    }
    
    @State private var selectedLevel: Int = 1
    @State private var selectedSpellTitle: String = ""
    @State private var selectedSpellDesc: String = ""
    
    let hapticFeedback = UIImpactFeedbackGenerator(style: .medium)
    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                GeometryReader { geometry in
                    let minY = geometry.frame(in: .global).minY
                    let isScrollingDown = minY > 0
                    
                    ZStack(alignment: .bottomLeading) {
                        CachedAsyncImage(url: champion.splashArtURL) { image in
                            image.resizable().scaledToFill()
                        } placeholder: { Color.gray.opacity(0.3) }
                        .frame(width: geometry.size.width, height: isScrollingDown ? 350 + minY : 350)
                        .clipped()
                        .offset(y: isScrollingDown ? -minY : 0)
                        
                        LeagueTheme.championGradient
                            .frame(height: isScrollingDown ? 350 + minY : 350)
                            .offset(y: isScrollingDown ? -minY : 0)
                        
                        VStack(alignment: .leading) {
                            Text(champion.name).font(.largeTitle.weight(.heavy)).foregroundStyle(LeagueTheme.text)
                            Text(champion.title.capitalized).font(.title3).foregroundStyle(LeagueTheme.muted)
                        }
                        .padding().offset(y: isScrollingDown ? -minY : 0)
                    }
                }
                .frame(height: 350)
                
                VStack(alignment: .leading, spacing: 28) {
                    HStack {
                        ForEach(champion.tags, id: \.self) { tag in
                            Text(tag).font(.subheadline.weight(.semibold))
                                .foregroundStyle(LeagueTheme.gold)
                                .padding(.horizontal, 16).padding(.vertical, 8)
                                .background(LeagueTheme.elevated, in: Capsule())
                        }
                    }
                    .padding(.top, 16)
                    
                    if champion.isDetailLoaded {
                        VStack(alignment: .leading, spacing: 12) {
                            LeagueSectionHeader(title: "Compétences")
                            HStack(spacing: 15) {
                                SpellIcon(url: URL(string: "https://ddragon.leagueoflegends.com/cdn/\(DataDragon.version)/img/passive/\(champion.passiveImage)"))
                                    .onTapGesture {
                                        hapticFeedback.impactOccurred(intensity: 0.7)
                                        withAnimation {
                                            selectedSpellTitle = "Passif: \(champion.passiveName)"
                                            selectedSpellDesc = champion.passiveDesc.removingHTML()
                                        }
                                    }
                                ForEach(champion.spells) { spell in
                                    SpellIcon(url: spell.url)
                                        .onTapGesture {
                                            hapticFeedback.impactOccurred(intensity: 0.7)
                                            withAnimation {
                                                selectedSpellTitle = spell.name
                                                selectedSpellDesc = spell.desc.removingHTML()
                                            }
                                        }
                                }
                            }
                            if !selectedSpellTitle.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(selectedSpellTitle).font(.headline).foregroundStyle(LeagueTheme.gold)
                                    Text(selectedSpellDesc).font(.subheadline).foregroundStyle(LeagueTheme.muted)
                                }
                                .padding().frame(maxWidth: .infinity, alignment: .leading)
                                .leagueSurface(radius: LeagueTheme.Corner.medium)
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Statistiques").font(.title2).bold().foregroundStyle(LeagueTheme.text)
                            Spacer()
                            HStack {
                                Text("Lvl \(selectedLevel)").foregroundStyle(LeagueTheme.gold).fontWeight(.bold)
                                Stepper("", value: $selectedLevel, in: 1...18).labelsHidden()
                            }
                        }
                        LazyVGrid(columns: columns, spacing: 12) {
                            RealStatCard(title: "Points de Vie", icon: "heart.fill", color: .green, value: champion.statAt(base: champion.hp, growth: champion.hpperlevel, level: selectedLevel))
                            RealStatCard(title: "Mana / Énergie", icon: "drop.fill", color: .blue, value: champion.statAt(base: champion.mp, growth: champion.mpperlevel, level: selectedLevel))
                            RealStatCard(title: "Dégâts", icon: "flame.fill", color: .red, value: champion.statAt(base: champion.attackdamage, growth: champion.attackdamageperlevel, level: selectedLevel))
                            RealStatCard(title: "Vitesse d'Attaque", icon: "bolt.fill", color: .yellow, value: champion.statAt(base: champion.attackspeed, growth: champion.attackspeedperlevel, level: selectedLevel))
                            RealStatCard(title: "Armure", icon: "shield.fill", color: .orange, value: champion.statAt(base: champion.armor, growth: champion.armorperlevel, level: selectedLevel))
                            RealStatCard(title: "Résistance Mag.", icon: "sparkles", color: .purple, value: champion.statAt(base: champion.spellblock, growth: champion.spellblockperlevel, level: selectedLevel))
                            RealStatCard(title: "Vitesse Mvt", icon: "wind", color: .teal, value: champion.movespeed)
                            RealStatCard(title: "Critique", icon: "target", color: .pink, value: champion.statAt(base: champion.crit, growth: champion.critperlevel, level: selectedLevel))
                        }
                    }
                    .padding().leagueSurface(radius: LeagueTheme.Corner.large)
                    
                    if !champion.allyTips.isEmpty || !champion.enemyTips.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            LeagueSectionHeader(title: "Astuces")
                            if !champion.allyTips.isEmpty {
                                Text("Pour jouer \(champion.name) :").font(.headline).foregroundStyle(LeagueTheme.cyan)
                                ForEach(champion.allyTips, id: \.self) { tip in Text("• \(tip)").font(.subheadline).foregroundStyle(LeagueTheme.muted) }
                            }
                            if !champion.enemyTips.isEmpty {
                                Text("Contre \(champion.name) :").font(.headline).foregroundStyle(LeagueTheme.danger).padding(.top, 8)
                                ForEach(champion.enemyTips, id: \.self) { tip in Text("• \(tip)").font(.subheadline).foregroundStyle(LeagueTheme.muted) }
                            }
                        }
                    }
                    
                    if !champion.skins.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            LeagueSectionHeader(title: "Galerie")
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(champion.skins) { skin in
                                        ZStack(alignment: .bottomLeading) {
                                            CachedAsyncImage(url: skin.url) { image in image.resizable().scaledToFill() } placeholder: { Color.gray.opacity(0.3) }
                                            .frame(width: 260, height: 160).clipShape(RoundedRectangle(cornerRadius: 16))
                                            LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .center, endPoint: .bottom).clipShape(RoundedRectangle(cornerRadius: 16))
                                            Text(skin.name == "default" ? champion.name : skin.name).font(.headline).foregroundColor(.white).padding()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal).padding(.bottom, 40)
            }
        }
        .background(LeagueTheme.background)
        .id(champion.id) // Force le rechargement complet de la vue et de l'image si le champion change à la volée (ARAM)
        .edgesIgnoringSafeArea(.top)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    hapticFeedback.impactOccurred()
                    viewModel.toggleFavorite(for: champion)
                }) {
                    Image(systemName: champion.isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(champion.isFavorite ? LeagueTheme.danger : LeagueTheme.gold)
                }
                .accessibilityLabel(champion.isFavorite ? "Retirer des favoris" : "Ajouter aux favoris")
            }
        }
        .task {
            await viewModel.loadDetails(for: champion)
            if selectedSpellTitle.isEmpty && champion.isDetailLoaded {
                selectedSpellTitle = "Passif: \(champion.passiveName)"
                selectedSpellDesc = champion.passiveDesc.removingHTML()
            }
        }
        .onChange(of: champion.isDetailLoaded) { loaded in
            if loaded && selectedSpellTitle.isEmpty {
                selectedSpellTitle = "Passif: \(champion.passiveName)"
                selectedSpellDesc = champion.passiveDesc.removingHTML()
            }
        }
    }
}
