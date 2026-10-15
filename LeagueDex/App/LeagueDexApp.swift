import SwiftUI
import Combine
import FirebaseCore
import FirebaseAuth

@MainActor
class AppDelegate: NSObject, UIApplicationDelegate, ObservableObject {
    @Published private(set) var authentication: AuthenticationStore?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        authentication = AuthenticationStore(auth: Auth.auth())
        return true
    }
}

@main
struct LeagueDexApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            Group {
                if let authentication = delegate.authentication {
                    AuthenticationGate(auth: authentication)
                } else {
                    SessionRestorationView()
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}

private struct AuthenticationGate: View {
    @ObservedObject var auth: AuthenticationStore

    var body: some View {
        Group {
            if auth.isRestoring {
                SessionRestorationView()
            } else if let uid = auth.uid {
                // The store binds private data before publishing uid. Only this branch
                // constructs catalog views, and each account receives a fresh view tree.
                MainTabView(uid: uid)
                    .environmentObject(auth)
                    .id(uid)
            } else {
                AuthenticationView()
                    .environmentObject(auth)
            }
        }
    }
}

private struct SessionRestorationView: View {
    var body: some View {
        ZStack {
            LeagueTheme.background.ignoresSafeArea()
            LeagueLoadingState(message: "Restauration de votre session…")
        }
    }
}
