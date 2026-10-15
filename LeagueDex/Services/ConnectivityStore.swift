import Foundation
import Network
import Combine

@MainActor
final class ConnectivityStore: ObservableObject {
    static let shared = ConnectivityStore()
    @Published private(set) var isOnline = true
    private let monitor = NWPathMonitor()

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor [weak self] in self?.isOnline = online }
        }
        monitor.start(queue: DispatchQueue(label: "LeagueDex.connectivity"))
    }
}
