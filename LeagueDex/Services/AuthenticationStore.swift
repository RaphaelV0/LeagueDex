import Foundation
import Combine
import FirebaseAuth

/// Firebase owns the persisted credentials. No password or token is written to UserDefaults.
@MainActor
final class AuthenticationStore: ObservableObject {
    @Published private(set) var uid: String?
    @Published private(set) var email: String?
    @Published private(set) var isRestoring = true
    @Published private(set) var isBusy = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var noticeMessage: String?

    private let auth: Auth
    private var listener: AuthStateDidChangeListenerHandle?

    /// Constructed by AppDelegate only after FirebaseApp.configure().
    init(auth: Auth) {
        self.auth = auth
        listener = auth.addStateDidChangeListener { @Sendable [weak self] _, _ in
            Task { @MainActor [weak self] in
                // Read the current state here instead of replaying a possibly stale callback.
                self?.receiveCurrentUser()
            }
        }
    }

    deinit {
        if let listener {
            auth.removeStateDidChangeListener(listener)
        }
    }

    func clearMessages() {
        errorMessage = nil
        noticeMessage = nil
    }

    func signIn(email: String, password: String) async {
        guard beginOperation() else { return }
        defer { isBusy = false }
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Renseignez votre adresse e-mail et votre mot de passe."
            return
        }
        do {
            try await auth.signIn(withEmail: email, password: password)
            receiveCurrentUser()
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    func register(email: String, password: String, confirmation: String) async {
        guard beginOperation() else { return }
        defer { isBusy = false }
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else {
            errorMessage = "Renseignez votre adresse e-mail."
            return
        }
        guard password.count >= 6 else {
            errorMessage = "Choisissez un mot de passe d’au moins 6 caractères."
            return
        }
        guard password == confirmation else {
            errorMessage = "Les mots de passe ne correspondent pas."
            return
        }
        do {
            try await auth.createUser(withEmail: email, password: password)
            receiveCurrentUser()
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    func resetPassword(email: String) async {
        guard beginOperation() else { return }
        defer { isBusy = false }
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else {
            errorMessage = "Renseignez votre adresse e-mail pour réinitialiser le mot de passe."
            return
        }
        do {
            try await auth.sendPasswordReset(withEmail: email)
            noticeMessage = "Si un compte correspond à cette adresse, un e-mail de réinitialisation vous sera envoyé."
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    func signOut() {
        guard beginOperation() else { return }
        defer { isBusy = false }
        do {
            try auth.signOut()
            receiveCurrentUser()
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    private func beginOperation() -> Bool {
        guard !isBusy, !isRestoring else { return false }
        clearMessages()
        isBusy = true
        return true
    }

    private func receiveCurrentUser() {
        let user = auth.currentUser
        // Reset and bind private data before publishing the identity used by the view gate.
        FavoritesStore.shared.bind(uid: user?.uid)
        email = user?.email
        uid = user?.uid
        isRestoring = false
    }

    private static func message(for error: Error) -> String {
        let error = error as NSError
        #if DEBUG
        // These diagnostics help identify SDK, API-key and app-verification errors
        // without printing the email, password, access token or the userInfo payload.
        print("[LeagueDex Auth] Firebase error: domain=\(error.domain) code=\(error.code)")
        #endif
        guard error.domain == AuthErrorDomain,
              let code = AuthErrorCode(rawValue: error.code) else {
            #if DEBUG
            return "Authentification impossible (erreur \(error.code)). Consulte le code d’erreur dans la console Xcode."
            #else
            return "L’opération a échoué. Réessayez dans quelques instants."
            #endif
        }
        switch code {
        case .invalidEmail:
            return "Cette adresse e-mail n’est pas valide."
        case .wrongPassword, .userNotFound, .invalidCredential:
            return "L’adresse e-mail ou le mot de passe est incorrect."
        case .emailAlreadyInUse:
            return "Cette adresse e-mail est déjà utilisée. Connectez-vous ou réinitialisez votre mot de passe."
        case .weakPassword:
            return "Ce mot de passe est trop faible. Utilisez un mot de passe plus long avec des lettres, des chiffres et des symboles."
        case .networkError:
            return "Connexion au service impossible. Vérifiez votre accès à Internet puis réessayez."
        case .tooManyRequests:
            return "Trop de tentatives ont été effectuées. Patientez avant de réessayer."
        case .userDisabled:
            return "Ce compte est désactivé. Contactez l’assistance."
        case .operationNotAllowed:
            return "La connexion e-mail / mot de passe est désactivée. Active-la dans Firebase Console → Authentication → Sign-in method."
        case .invalidAPIKey:
            return "Clé API Firebase invalide. Vérifie que GoogleService-Info.plist provient du bon projet Firebase."
        case .appNotAuthorized:
            return "LeagueDex n’est pas autorisée à utiliser cette clé Firebase. Vérifie le Bundle Identifier et les restrictions de la clé API."
        case .keychainError:
            return "Impossible d’accéder au trousseau sécurisé de l’iPhone. Vérifie la configuration et relance l’application."
        case .internalError:
            return "Erreur interne Firebase Authentication. Consulte le code d’erreur dans la console Xcode."
        case .requiresRecentLogin:
            return "Reconnectez-vous avant de réessayer cette opération."
        default:
            #if DEBUG
            return "Firebase Authentication a refusé l’opération (code \(error.code)). Consulte la console Xcode."
            #else
            return "L’authentification a échoué. Réessayez dans quelques instants."
            #endif
        }
    }
}
