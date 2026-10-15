import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var auth: AuthenticationStore
    @State private var confirmsSignOut = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: LeagueTheme.Space.lg) {
                    VStack(alignment: .leading, spacing: LeagueTheme.Space.md) {
                        Label("Compte connecté", systemImage: "person.crop.circle.fill")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(LeagueTheme.gold)
                        if let email = auth.email {
                            Text(email)
                                .font(.body)
                                .textSelection(.enabled)
                        }
                        Text("Vos favoris et vos builds sont associés à ce compte.")
                            .font(.subheadline)
                            .foregroundStyle(LeagueTheme.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(LeagueTheme.Space.lg)
                    .leagueSurface()

                    AuthenticationMessages()

                    Button {
                        if let email = auth.email {
                            Task { await auth.resetPassword(email: email) }
                        }
                    } label: {
                        Label("Réinitialiser le mot de passe", systemImage: "key.fill")
                    }
                    .buttonStyle(LeagueActionButtonStyle(prominent: false))
                    .disabled(auth.isBusy || auth.email == nil)

                    Button(role: .destructive) { confirmsSignOut = true } label: {
                        Label("Se déconnecter", systemImage: "rectangle.portrait.and.arrow.right")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .foregroundStyle(LeagueTheme.danger)
                    .disabled(auth.isBusy)

                    if auth.isBusy {
                        ProgressView("Veuillez patienter…")
                            .frame(maxWidth: .infinity)
                            .tint(LeagueTheme.gold)
                    }
                }
                .frame(maxWidth: 560)
                .padding(LeagueTheme.Space.lg)
                .frame(maxWidth: .infinity)
            }
            .background(LeagueTheme.background)
            .foregroundStyle(LeagueTheme.text)
            .navigationTitle("Mon compte")
            .confirmationDialog("Se déconnecter de LeagueDex ?", isPresented: $confirmsSignOut, titleVisibility: .visible) {
                Button("Se déconnecter", role: .destructive) { auth.signOut() }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Vos données resteront associées à votre compte.")
            }
            .onAppear { auth.clearMessages() }
        }
        .tint(LeagueTheme.gold)
        .preferredColorScheme(.dark)
    }
}
