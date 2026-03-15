import CoreMotion
import Foundation
import CoreGraphics
import Combine

@MainActor
final class MotionManager: ObservableObject {
    @Published private(set) var tilt: CGSize = .zero

    private let manager = CMMotionManager()
    private var isRunning = false

    func start() {
        guard !isRunning else { return }
        guard manager.isDeviceMotionAvailable else { return }

        manager.deviceMotionUpdateInterval = 1.0 / 15.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let attitude = motion?.attitude else { return }
            let rawWidth = attitude.roll * 30
            let rawHeight = attitude.pitch * 30
            self.tilt = CGSize(
                width: max(-3, min(3, rawWidth)),
                height: max(-3, min(3, rawHeight))
            )
        }
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        manager.stopDeviceMotionUpdates()
        isRunning = false
        tilt = .zero
    }
}
