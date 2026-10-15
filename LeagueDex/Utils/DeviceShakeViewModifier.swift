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
        guard motion == .motionShake else {
            super.motionEnded(motion, with: event)
            return
        }
        guard isKeyWindow, windowScene?.activationState == .foregroundActive else { return }
        let shake = DeviceShakeEvent(id: UUID(), timestamp: event?.timestamp ?? ProcessInfo.processInfo.systemUptime)
        NotificationCenter.default.post(name: UIDevice.deviceDidShakeNotification, object: self,
                                        userInfo: ["shake": shake])
    }
}
