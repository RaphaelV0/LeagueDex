import SwiftUI

struct ChampionComparisonView: View {
    @EnvironmentObject private var catalog: ChampionViewModel
    @EnvironmentObject private var userData: UserDataStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicType
    @State private var leftID = ""
    @State private var rightID = ""
    @State private var level = 1.0
    @State private var selection: ComparisonSide?

    private enum ComparisonSide: String, Identifiable {
        case left, right
        var id: String { rawValue }
    }

    private var left: DBChampion? { catalog.champions.first { $0.id == leftID } }
    private var right: DBChampion? { catalog.champions.first { $0.id == rightID } }
    private var saved: Bool {
        userData.comparisons.contains { $0.leftID == leftID && $0.rightID == rightID && $0.level == Int(level) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LeagueTheme.Space.lg) {
                LeagueSectionHeader(title: "Duel de champions", subtitle: "Statistiques du catalogue LeagueDex · patch \(DataDragon.version)")
                HStack(alignment: .top, spacing: LeagueTheme.Space.sm) {
                    selectionCard(champion: left, side: .left)
                    selectionCard(champion: right, side: .right)
                }
                levelControl
                if let left, let right {
                    VStack(spacing: LeagueTheme.Space.md) {
                        ForEach(ComparisonStat.allCases) { stat in
                            statRow(stat, left: stat.value(left, level: Int(level)), right: stat.value(right, level: Int(level)))
                        }
                    }
                    Button {
                        userData.saveComparison(leftID: leftID, rightID: rightID, level: Int(level))
                    } label: {
                        Label(saved ? "Comparaison enregistrée" : "Enregistrer la comparaison", systemImage: saved ? "heart.fill" : "heart")
                    }
                    .buttonStyle(LeagueActionButtonStyle())
                    .disabled(saved)

                    LeagueSectionHeader(title: "Rôles & compétences")
                    if dynamicType.isAccessibilitySize {
                        skillsColumn(left)
                        skillsColumn(right)
                    } else {
                        HStack(alignment: .top, spacing: LeagueTheme.Space.sm) {
                            skillsColumn(left)
                            skillsColumn(right)
                        }
                    }
                } else {
                    LeagueEmptyState(title: "Choisissez deux champions", detail: "Comparez leurs statistiques au même niveau, leurs rôles et leurs compétences.", icon: "arrow.left.arrow.right")
                }
                if let error = userData.errorMessage {
                    Text(error).font(.footnote).foregroundStyle(LeagueTheme.danger)
                }
                savedComparisons
            }
            .padding(LeagueTheme.Space.md)
            .padding(.bottom, LeagueTheme.Space.lg)
        }
        .background(LeagueTheme.background)
        .navigationTitle("Comparateur")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selection) { side in
            ChampionSelectionSheet(selectedID: side == .left ? leftID : rightID,
                                   excludedID: side == .left ? rightID : leftID) { champion in
                if side == .left { leftID = champion.id } else { rightID = champion.id }
            }
        }
        .task(id: left?.id) { if let left { await catalog.loadDetails(for: left) } }
        .task(id: right?.id) { if let right { await catalog.loadDetails(for: right) } }
    }

    private var levelControl: some View {
        VStack(alignment: .leading, spacing: LeagueTheme.Space.sm) {
            Text("Niveau \(Int(level)) / 18")
                .font(.headline.monospacedDigit()).foregroundStyle(LeagueTheme.gold)
            Slider(value: $level, in: 1...18, step: 1)
                .tint(LeagueTheme.gold)
                .accessibilityLabel("Niveau des deux champions")
                .accessibilityValue("\(Int(level)) sur 18")
        }
        .padding(LeagueTheme.Space.md).leagueSurface()
    }

    private func selectionCard(champion: DBChampion?, side: ComparisonSide) -> some View {
        Button { selection = side } label: {
            VStack(spacing: LeagueTheme.Space.sm) {
                CompanionChampionIcon(champion: champion, size: 64)
                Text(champion?.name ?? "Choisir")
                    .font(.headline).foregroundStyle(LeagueTheme.text)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(champion?.tags.joined(separator: " · ") ?? "Champion \(side == .left ? "1" : "2")")
                    .font(.caption).foregroundStyle(LeagueTheme.muted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 128, alignment: .top)
            .padding(LeagueTheme.Space.md).leagueSurface()
        }
        .buttonStyle(LeagueCompactButtonStyle())
        .accessibilityLabel("\(side == .left ? "Premier" : "Second") champion : \(champion?.name ?? "à choisir")")
        .accessibilityHint("Ouvrir la recherche de champions")
    }

    private func statRow(_ stat: ComparisonStat, left: Double, right: Double) -> some View {
        let maximum = max(1, max(left, right))
        let delta = right - left
        return VStack(spacing: LeagueTheme.Space.sm) {
            Text(stat.rawValue).font(.subheadline.weight(.semibold)).foregroundStyle(LeagueTheme.text)
            HStack(alignment: .top) {
                statValue(left, fraction: left / maximum, color: LeagueTheme.gold)
                statValue(right, fraction: right / maximum, color: LeagueTheme.cyan)
            }
            Text("Écart à droite : \(delta > 0 ? "+" : "")\(formatted(delta))")
                .font(.caption.monospacedDigit()).foregroundStyle(LeagueTheme.muted)
            if stat == .attackSpeed {
                Text("Valeur de base du catalogue, indépendante du niveau sélectionné.")
                    .font(.caption).foregroundStyle(LeagueTheme.muted)
            }
        }
        .padding(LeagueTheme.Space.md).leagueSurface()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stat.rawValue). \(self.left?.name ?? "Premier champion") : \(formatted(left)). \(self.right?.name ?? "Second champion") : \(formatted(right)). Écart à droite : \(formatted(delta)).\(stat == .attackSpeed ? " Valeur de base indépendante du niveau sélectionné." : "")")
    }

    private func statValue(_ value: Double, fraction: Double, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(formatted(value)).font(.headline.monospacedDigit()).foregroundStyle(color)
            ProgressView(value: max(0, min(1, fraction))).tint(color)
                .animation(reduceMotion ? nil : LeagueMotion.quick, value: value)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
    }

    private func skillsColumn(_ champion: DBChampion) -> some View {
        VStack(alignment: .leading, spacing: LeagueTheme.Space.sm) {
            Text(champion.name).font(.headline).foregroundStyle(LeagueTheme.gold)
            Text(champion.tags.joined(separator: " · ")).font(.caption).foregroundStyle(LeagueTheme.cyan)
            if champion.isDetailLoaded {
                if !champion.passiveName.isEmpty {
                    DisclosureGroup(champion.passiveName) {
                        Text(champion.passiveDesc.removingHTML()).font(.caption).foregroundStyle(LeagueTheme.muted)
                    }
                }
                ForEach(champion.spells) { spell in
                    DisclosureGroup(spell.name) {
                        Text(spell.desc.removingHTML()).font(.caption).foregroundStyle(LeagueTheme.muted)
                    }
                }
            } else if let error = catalog.detailError(for: champion.id) {
                Text(error).font(.caption).foregroundStyle(LeagueTheme.muted)
                Button("Réessayer") { Task { await catalog.loadDetails(for: champion) } }
                    .frame(minHeight: 44)
            } else {
                ProgressView().tint(LeagueTheme.gold).accessibilityLabel("Chargement des compétences")
            }
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(LeagueTheme.Space.sm).leagueSurface()
    }

    private var savedComparisons: some View {
        VStack(alignment: .leading, spacing: LeagueTheme.Space.md) {
            LeagueSectionHeader(title: "Comparaisons favorites", subtitle: "Synchronisées avec votre compte")
            if userData.comparisons.isEmpty {
                Text("Aucune comparaison enregistrée.").font(.subheadline).foregroundStyle(LeagueTheme.muted)
            }
            ForEach(userData.comparisons) { comparison in
                HStack(spacing: LeagueTheme.Space.sm) {
                    Button {
                        leftID = comparison.leftID
                        rightID = comparison.rightID
                        level = Double(min(18, max(1, comparison.level)))
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(name(for: comparison.leftID)) / \(name(for: comparison.rightID))")
                                .font(.headline).foregroundStyle(LeagueTheme.text)
                            Text("Niveau \(comparison.level)").font(.caption).foregroundStyle(LeagueTheme.muted)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    Button(role: .destructive) { userData.deleteComparison(comparison) } label: {
                        Image(systemName: "trash").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Supprimer la comparaison \(name(for: comparison.leftID)) et \(name(for: comparison.rightID))")
                }
                .padding(LeagueTheme.Space.sm).leagueSurface()
            }
        }
    }

    private func name(for id: String) -> String {
        catalog.champions.first { $0.id == id }?.name ?? "Champion indisponible (\(id))"
    }

    private func formatted(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }
}

private enum ComparisonStat: String, CaseIterable, Identifiable {
    case health = "Points de vie", mana = "Mana / Énergie", damage = "Dégâts d’attaque"
    case armor = "Armure", magicResistance = "Résistance magique", attackSpeed = "Vitesse d’attaque de base"
    case movement = "Vitesse de déplacement", critical = "Critique"
    var id: String { rawValue }

    func value(_ champion: DBChampion, level: Int) -> Double {
        switch self {
        case .health: return champion.statAt(base: champion.hp, growth: champion.hpperlevel, level: level)
        case .mana: return champion.statAt(base: champion.mp, growth: champion.mpperlevel, level: level)
        case .damage: return champion.statAt(base: champion.attackdamage, growth: champion.attackdamageperlevel, level: level)
        case .armor: return champion.statAt(base: champion.armor, growth: champion.armorperlevel, level: level)
        case .magicResistance: return champion.statAt(base: champion.spellblock, growth: champion.spellblockperlevel, level: level)
        case .attackSpeed: return champion.attackspeed
        case .movement: return champion.movespeed
        case .critical: return champion.statAt(base: champion.crit, growth: champion.critperlevel, level: level)
        }
    }
}
