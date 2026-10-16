import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject private var auth: AuthenticationStore
    @State private var isRegistering = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmation = ""
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case email, password, confirmation }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: LeagueTheme.Space.lg) {
                    introduction
                    VStack(alignment: .leading, spacing: LeagueTheme.Space.md) {
                        Picker("Accès au compte", selection: $isRegistering) {
                            Text("Connexion").tag(false)
                            Text("Inscription").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .disabled(auth.isBusy)

                        VStack(alignment: .leading, spacing: LeagueTheme.Space.sm) {
                            Text("Adresse e-mail").font(.subheadline.weight(.semibold))
                            TextField("vous@exemple.fr", text: $email)
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .email)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .password }
                                .accessibilityLabel("Adresse e-mail")
                                .authenticationField()
                        }
                        VStack(alignment: .leading, spacing: LeagueTheme.Space.sm) {
                            Text("Mot de passe").font(.subheadline.weight(.semibold))
                            SecureField("Mot de passe", text: $password)
                                .textContentType(isRegistering ? .newPassword : .password)
                                .focused($focusedField, equals: .password)
                                .submitLabel(isRegistering ? .next : .go)
                                .onSubmit {
                                    if isRegistering { focusedField = .confirmation }
                                    else { submit() }
                                }
                                .authenticationField()
                            if isRegistering {
                                Text("Au moins 6 caractères.")
                                    .font(.footnote)
                                    .foregroundStyle(LeagueTheme.muted)
                            }
                        }
                        if isRegistering {
                            VStack(alignment: .leading, spacing: LeagueTheme.Space.sm) {
                                Text("Confirmer le mot de passe").font(.subheadline.weight(.semibold))
                                SecureField("Confirmer le mot de passe", text: $confirmation)
                                    .textContentType(.newPassword)
                                    .focused($focusedField, equals: .confirmation)
                                    .submitLabel(.go)
                                    .onSubmit(submit)
                                    .authenticationField()
                            }
                        }

                        AuthenticationMessages()

                        Button(action: submit) {
                            HStack(spacing: LeagueTheme.Space.sm) {
                                if auth.isBusy { ProgressView().tint(LeagueTheme.background) }
                                Text(auth.isBusy ? "Veuillez patienter…" : (isRegistering ? "Créer mon compte" : "Se connecter"))
                            }
                        }
                        .buttonStyle(LeagueActionButtonStyle())
                        .disabled(auth.isBusy || !canSubmit)
                        .accessibilityHint(isRegistering ? "Crée votre compte LeagueDex" : "Ouvre votre session LeagueDex")

                        if !isRegistering {
                            Button("Mot de passe oublié ?") {
                                focusedField = nil
                                Task { await auth.resetPassword(email: email) }
                            }
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .foregroundStyle(LeagueTheme.gold)
                            .disabled(auth.isBusy)
                        }
                    }
                    .padding(LeagueTheme.Space.lg)
                    .leagueSurface(radius: LeagueTheme.Corner.panel)
                    .disabled(auth.isBusy)

                    Text("Retrouvez vos champions favoris avec votre compte Firebase.")
                        .font(.footnote)
                        .foregroundStyle(LeagueTheme.muted)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: 520)
                .padding(LeagueTheme.Space.lg)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(LeagueTheme.background)
            .foregroundStyle(LeagueTheme.text)
            .navigationTitle(isRegistering ? "Créer un compte" : "Bienvenue")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: isRegistering) { _, _ in
                password = ""
                confirmation = ""
                auth.clearMessages()
                focusedField = nil
            }
        }
        .tint(LeagueTheme.gold)
        .preferredColorScheme(.dark)
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: LeagueTheme.Space.sm) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 38))
                .foregroundStyle(LeagueTheme.gold)
                .accessibilityHidden(true)
            Text("LeagueDex")
                .font(.largeTitle.weight(.bold))
            Text(isRegistering ? "Un compte pour préparer vos prochaines parties." : "Connectez-vous pour retrouver votre collection.")
                .font(.subheadline)
                .foregroundStyle(LeagueTheme.muted)
        }
        .padding(.top, LeagueTheme.Space.lg)
    }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty &&
        (!isRegistering || !confirmation.isEmpty)
    }

    private func submit() {
        guard canSubmit, !auth.isBusy else { return }
        focusedField = nil
        Task {
            if isRegistering {
                await auth.register(email: email, password: password, confirmation: confirmation)
            } else {
                await auth.signIn(email: email, password: password)
            }
        }
    }
}

/// Shared feedback for authentication and account actions; always includes text.
struct AuthenticationMessages: View {
    @EnvironmentObject private var auth: AuthenticationStore

    var body: some View {
        if let message = auth.errorMessage {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(LeagueTheme.danger)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .combine)
        }
        if let message = auth.noticeMessage {
            Label(message, systemImage: "envelope.fill")
                .font(.subheadline)
                .foregroundStyle(LeagueTheme.cyan)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .combine)
        }
    }
}

private extension View {
    func authenticationField() -> some View {
        padding(LeagueTheme.Space.md)
            .frame(minHeight: 48)
            .background(LeagueTheme.background, in: RoundedRectangle(cornerRadius: LeagueTheme.Corner.medium))
            .overlay {
                RoundedRectangle(cornerRadius: LeagueTheme.Corner.medium)
                    .strokeBorder(LeagueTheme.border, lineWidth: 1)
            }
    }
}
