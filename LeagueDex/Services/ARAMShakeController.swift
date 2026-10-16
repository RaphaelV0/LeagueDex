import SwiftUI
import Combine
import UIKit

/// The only bridge between UIKit motion events and SwiftUI ARAM presentation.
///
/// A SwiftUI .onReceive attached to a view can stop receiving when that view
/// presents a fullScreenCover. This object subscribes once for its entire
/// lifetime, and the presented view observes its published champion directly.
@MainActor
final class ARAMShakeController: ObservableObject {
    @Published private(set) var currentChampionID: String?
    @Published private(set) var revision = 0
    @Published var isShowingARAM = false

    private var selection = ARAMState()
    private var shakeSubscription: AnyCancellable?
    private var isChampionsTabActive = false
    private var championIDs: [String] = []
    private var galleryPresented = false
    private var pendingShake: DeviceShakeEvent?
    private var isClosing = false

    init() {
        // Unlike .onReceive on a SwiftUI NavigationStack, this subscription
        // survives the entire lifetime of the full-screen champion presentation.
        shakeSubscription = NotificationCenter.default.publisher(
            for: UIDevice.deviceDidShakeNotification
        )
        .compactMap { $0.userInfo?["shake"] as? DeviceShakeEvent }
        .sink { [weak self] shake in
            Task { @MainActor [weak self] in
                self?.receiveShake(shake)
            }
        }
    }

    func setChampions(_ ids: [String]) {
        championIDs = ids
    }

    func setTabActive(_ active: Bool) {
        isChampionsTabActive = active
        if !active { pendingShake = nil }
    }

    private func receiveShake(_ shake: DeviceShakeEvent) {
        #if DEBUG
        print("[LeagueDex ARAM] Event delivered to controller; tabActive=\(isChampionsTabActive), gallery=\(galleryPresented), closing=\(isClosing), champions=\(championIDs.count)")
        #endif

        guard isChampionsTabActive, !isClosing else { return }

        // Do not replace a champion beneath an enlarged skin. Apply the last
        // physical shake as soon as the gallery has fully dismissed.
        if galleryPresented {
            pendingShake = shake
            return
        }

        let result = selection.receiveShake(
            eventID: shake.id,
            timestamp: shake.timestamp,
            candidateIDs: championIDs
        )
        guard result.isAccepted else {
            #if DEBUG
            print("[LeagueDex ARAM] Selection skipped (duplicate, debounce or empty catalog)")
            #endif
            return
        }

        // Published state drives the actual presented page, not a value-type
        // SwiftUI closure captured before the fullScreenCover was opened.
        currentChampionID = selection.currentChampionID
        revision = selection.revision

        #if DEBUG
        print("[LeagueDex ARAM] Champion tiré: \(currentChampionID ?? "aucun"), révision \(revision)")
        #endif

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if !isShowingARAM { isShowingARAM = true }
    }

    func setGalleryPresented(_ presented: Bool) {
        galleryPresented = presented
        guard !presented, let shake = pendingShake else { return }
        pendingShake = nil
        receiveShake(shake)
    }

    func close() {
        guard isShowingARAM else { return }
        isClosing = true
        pendingShake = nil
        isShowingARAM = false
    }

    func didDismiss() {
        selection.reset()
        currentChampionID = nil
        revision = 0
        galleryPresented = false
        pendingShake = nil
        isClosing = false
    }
}
