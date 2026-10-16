import UIKit

/// One event per completed UIKit shake, preserved through modal transitions.
struct DeviceShakeEvent: Equatable {
    let id: UUID
    let timestamp: TimeInterval
}

extension UIDevice {
    static let deviceDidShakeNotification = Notification.Name("deviceDidShakeNotification")
}

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake, windowScene?.activationState == .foregroundActive {
            // Do not require isKeyWindow: a full-screen SwiftUI cover can move
            // first-responder/key-window ownership during its transition.
            let shake = DeviceShakeEvent(
                id: UUID(),
                timestamp: event?.timestamp ?? ProcessInfo.processInfo.systemUptime
            )
            NotificationCenter.default.post(
                name: UIDevice.deviceDidShakeNotification,
                object: self,
                userInfo: ["shake": shake]
            )
        }
        super.motionEnded(motion, with: event)
    }
}
