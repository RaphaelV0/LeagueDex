import SwiftUI

/// User-scoped list. Pending proposals are never treated as published places.
struct VenueProposalsView: View {
    @ObservedObject var viewModel: VenueViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: LeagueTheme.Space.md) {
                    LeagueSectionHeader(
                        title: "Mes propositions",
                        subtitle: "Les nouveaux lieux sont vérifiés avant d'apparaître sur la carte."
                    )
                    if viewModel.proposals.isEmpty {
                        LeagueEmptyState(
                            title: "Aucune proposition",
                            detail: "Propose un lieu depuis le bouton + de la carte.",
                            icon: "mappin.and.ellipse"
                        )
                    } else {
                        ForEach(viewModel.proposals) { proposal in
                            VStack(alignment: .leading, spacing: LeagueTheme.Space.sm) {
                                Text(proposal.name)
                                    .font(.headline)
                                    .foregroundStyle(LeagueTheme.text)
                                Text(proposal.address)
                                    .font(.subheadline)
                                    .foregroundStyle(LeagueTheme.muted)
                                Label(proposal.statusLabel,
                                      systemImage: proposal.status == "approved"
                                        ? "checkmark.seal.fill"
                                        : proposal.status == "rejected"
                                          ? "xmark.circle.fill" : "hourglass")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(proposal.status == "approved"
                                        ? LeagueTheme.cyan : LeagueTheme.gold)
                                if let date = proposal.createdAt {
                                    Text(date, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(LeagueTheme.muted)
                                }
                            }
                            .padding(LeagueTheme.Space.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .leagueSurface()
                        }
                    }
                }
                .padding(LeagueTheme.Space.md)
            }
            .background(LeagueTheme.background)
            .navigationTitle("Mes lieux proposés")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
        .tint(LeagueTheme.gold)
    }
}
