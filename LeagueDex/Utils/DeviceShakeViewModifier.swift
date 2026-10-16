import SwiftUI
import UIKit

/// The selected champion is chosen only from completed, physical UIKit shakes.
struct DeviceShakeEvent: Equatable, Sendable {
    let id: UUID
    let timestamp: TimeInterval
}

extension UIDevice {
    static let deviceDidShakeNotification = Notification.Name("deviceDidShakeNotification")

    /// Both the responder attached to SwiftUI screens and the window fallback
    /// post the exact same type of event, so selection has one code path.
    static func announceShake(_ event: UIEvent?) {
        let shake = DeviceShakeEvent(
            id: UUID(),
            timestamp: event?.timestamp ?? ProcessInfo.processInfo.systemUptime
        )
        #if DEBUG
        print("[LeagueDex ARAM] UIKit shake received")
        #endif
        NotificationCenter.default.post(
            name: UIDevice.deviceDidShakeNotification,
            object: nil,
            userInfo: ["shake": shake]
        )
    }
}

/// SwiftUI's fullScreenCover changes the responder chain. The presenting
/// window is not guaranteed to receive motionEnded after the first shake.
/// Each active screen therefore installs its own UIKit first responder.
struct ShakeEventReceiver: UIViewControllerRepresentable {
    let enabled: Bool
    var reactivation: Int = 0

    func makeUIViewController(context: Context) -> ShakeResponderViewController {
        let controller = ShakeResponderViewController()
        controller.shakesEnabled = enabled
        controller.lastReactivation = reactivation
        return controller
    }

    func updateUIViewController(_ controller: ShakeResponderViewController, context: Context) {
        let wasEnabled = controller.shakesEnabled
        let needsReactivation = controller.lastReactivation != reactivation
        controller.shakesEnabled = enabled
        controller.lastReactivation = reactivation

        if !enabled {
            if controller.isFirstResponder { controller.resignFirstResponder() }
        } else if controller.view.window != nil && (!wasEnabled || needsReactivation) {
            // Re-assert ownership when an ARAM champion replaces the prior
            // detail, not on each ordinary SwiftUI update/keystroke.
            controller.becomeFirstResponder()
        }
    }
}

final class ShakeResponderViewController: UIViewController {
    var shakesEnabled = false
    var lastReactivation = 0

    override var canBecomeFirstResponder: Bool { shakesEnabled }

    override func loadView() {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        self.view = view
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if shakesEnabled { becomeFirstResponder() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        if isFirstResponder { resignFirstResponder() }
        super.viewWillDisappear(animated)
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake && shakesEnabled {
            UIDevice.announceShake(event)
            return // Prevent the same gesture from also reaching UIWindow.
        }
        super.motionEnded(motion, with: event)
    }
}

/// Fallback when another responder receives the shake and forwards it to its
/// window (e.g. while SwiftUI is replacing navigation content).
extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake, windowScene?.activationState == .foregroundActive {
            UIDevice.announceShake(event)
        }
        super.motionEnded(motion, with: event)
    }
}
